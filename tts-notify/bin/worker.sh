#!/usr/bin/env bash
#
# tts-notify detached worker. Launched by hooks/dispatch.sh via setsid so it
# runs AFTER the hook already returned (Claude is never blocked).
#
# Pipeline: parse event -> gather text (transcript for stop, message for
# notification) -> OpenRouter summarize (ported prompts, validated by
# lib/validate.py into NDJSON {say, show}) -> broadcast via hailer's broker
# (POST /hail). Each sentence becomes a segment: `show` -> text (ntfy push body),
# `say` (reading) -> speech (synthesized by TTS). The broker fans out to every
# enabled channel and owns volume; playback happens asynchronously over there.
#
# Notification: idle "waiting for input" messages are dropped; only
# action-required notifications (e.g. tool permission prompts) are spoken.
#
# Concurrency (kept deliberately simple per request): a single non-blocking
# flock held across gather + summarize + the /hail POST. If a worker is already
# in that window, new events are DROPPED — first-wins, no queue, no catch-up.
# (The POST returns immediately; ordering of actual playback is the broker's.)
#
# Args: $1 = source (stop|notification)  $2 = event JSON file
#
set +e

SOURCE="$1"
EVENT_FILE="$2"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "$ROOT/lib/common.sh"

trap 'rm -f "$EVENT_FILE"' EXIT
[ -n "$EVENT_FILE" ] && [ -f "$EVENT_FILE" ] || exit 0
event="$(cat "$EVENT_FILE")"
[ -n "$event" ] || exit 0

# --- single-flight: drop if something is already in flight (先がち) ---------
exec 9>"$TTS_NOTIFY_CACHE/play.lock"
flock -n 9 || { log "busy -> drop"; exit 0; }

# --- gather source text ----------------------------------------------------
if [ "$SOURCE" = "notification" ]; then
  raw="$(printf '%s' "$event" | jq -r '.message // empty' 2>/dev/null)"
  [ -n "$raw" ] || { log "empty notification -> drop"; exit 0; }
  # 入力待ちアイドル通知は読み上げない。許可要求など「ユーザーのアクションが
  # 要る」通知だけ拾う。idle と確証が持てないものは安全側で全て通す。
  case "$raw" in
    *"waiting for your input"*|*"appears to be idle"*|*"入力を待"*)
      log "idle notification -> drop"; exit 0 ;;
  esac
  mode="notification"
  src_text="$raw"
else
  tp="$(printf '%s' "$event" | jq -r '.transcript_path // empty' 2>/dev/null)"
  [ -n "$tp" ] || { log "no transcript_path -> drop"; exit 0; }
  asst="" ctx=""
  for _ in $(seq 1 "$TTS_NOTIFY_TRANSCRIPT_WAIT"); do
    ctx="$(python3 "$ROOT/lib/extract.py" "$tp" 2>/dev/null)"
    asst="$(printf '%s' "$ctx" | jq -r '.assistant // empty' 2>/dev/null)"
    [ -n "$asst" ] && break
    sleep 1
  done
  [ -n "$asst" ] || { log "no assistant text -> drop"; exit 0; }
  user="$(printf '%s' "$ctx" | jq -r '.user // empty' 2>/dev/null)"
  mode="stop"
  if [ -n "$user" ]; then
    src_text="## ユーザの依頼
$user

## アシスタントの応答
$asst"
  else
    src_text="$asst"
  fi
fi

# --- summarize -------------------------------------------------------------
# summary is NDJSON: one {"say": reading, "show": text} object per sentence.
summary="$(printf '%s' "$src_text" | "$ROOT/lib/summarize.sh" "$mode")"

if [ -z "$summary" ]; then
  if [ "$SOURCE" = "notification" ]; then
    # Notifications are already short: speak the raw message (graceful degrade).
    # No separate reading/display here, so say == show == raw.
    summary="$(jq -cn --arg s "$raw" '{say: $s}')"
    log "summarize unavailable -> raw notification"
  else
    # Assistant turns can be huge/noisy; do not read raw. Drop.
    log "summarize unavailable -> drop ($SOURCE)"
    exit 0
  fi
fi

# --- broadcast via hailer broker (POST /hail) ------------------------------
# Map each NDJSON sentence onto a hailer segment: show -> text (display / ntfy
# push body), say -> speech (the reading TTS synthesizes). targets is omitted
# so the broker fans out to every enabled channel; volume is the broker's.
segments="$(printf '%s\n' "$summary" \
  | jq -c 'select(type=="object") | {text: (.show // .say), speech: .say}' \
  | jq -cs 'map(select(.speech != null and .speech != ""))')"
if [ -z "$segments" ] || [ "$segments" = "[]" ]; then
  log "no segments to broadcast -> drop"; exit 0
fi

case "${TTS_NOTIFY_CUE,,}" in true|1|yes|on) cue=true ;; *) cue=false ;; esac
body="$(jq -cn \
  --argjson segs "$segments" \
  --arg preset "$TTS_NOTIFY_PRESET" \
  --argjson cue "$cue" \
  '{segments: $segs, preset: $preset, cue: $cue}')"

# Cloudflare Access の service token（リモート broker のときだけ設定される）。
# 両方揃っているときだけ送る（片方では Access を通れないので、中途半端な送信はしない）。
access_headers=()
if [ -n "${CF_ACCESS_CLIENT_ID:-}" ] && [ -n "${CF_ACCESS_CLIENT_SECRET:-}" ]; then
  access_headers=(-H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID"
                  -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET")
fi

# ステータスと content-type を取る。`-f` は付けない（本文を捨てずに理由を残すため）。
# `-L` も付けない: Access のブロックは 302 -> ログイン画面(200 HTML) なので、追跡すると
# 「成功」に化けて無言で声が出なくなる（HTML を content-type で検知する）。
resp="$(curl -sS -m 30 -X POST "$HAIL_URL/hail" \
     -H "Content-Type: application/json" \
     "${access_headers[@]}" \
     --data-binary "$body" \
     -o /dev/null -w '%{http_code} %{content_type}' 2>/dev/null)" || {
  log "hail post failed (unreachable): $HAIL_URL/hail"; exit 0
}
http_code="${resp%% *}"
content_type="${resp#* }"

case "$content_type" in
  # broker は JSON しか返さない。HTML が返ったら Cloudflare の応答（Access のログイン画面
  # または origin 不達のエラーページ）であり、broker には届いていない。
  *text/html*)
    log "hail blocked by Cloudflare (http=$http_code): CF_ACCESS_CLIENT_ID/SECRET と Access ポリシー(Service Auth)を確認"
    exit 0 ;;
esac
if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
  log "hail post failed (http=$http_code): $HAIL_URL/hail"; exit 0
fi

shown="$(printf '%s\n' "$summary" | jq -r '.show // .say // empty' 2>/dev/null \
  | tr '\n' ' ' | cut -c1-80)"
log "hailed ($SOURCE): $shown"
