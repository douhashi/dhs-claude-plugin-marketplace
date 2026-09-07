# shellcheck shell=bash
#
# tts-notify shared config / helpers. Sourced by bin/worker.sh.
#
# Config precedence: existing env > ~/.config/tts-notify/env > defaults.
#
# このプラグインは **秘密を持たない**。要約は hailer broker (POST /announce) の
# 責務なので、OpenRouter の鍵もモデルも口調(persona)もここには無い。
# 残る秘匿値は broker が Cloudflare Access 配下にある場合の service token だけ。
#
# 以前は OPENROUTER_API_KEY をこのファイル経由で各作業機に配っていたが、
# 機種変で env ごと失われて「エラーも出さずに無言になる」事故を起こした。
# 鍵を producer に置かないのはその再発防止でもある。

TTS_NOTIFY_CONFIG="${TTS_NOTIFY_CONFIG:-$HOME/.config/tts-notify/env}"
if [ -f "$TTS_NOTIFY_CONFIG" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$TTS_NOTIFY_CONFIG"
  set +a
fi

# hailer broker。`hail` CLI と同じ変数を使うので 1 つの設定で両方に効く。
#
# Remote broker (behind a Cloudflare tunnel + Access): set HAIL_URL to the tunnel
# hostname and provide a Cloudflare Access *service token*. The hook is a machine
# client, so it cannot do the interactive Access login — without the token pair the
# request is redirected to a login page and nothing is ever spoken.
# CF_ACCESS_CLIENT_ID / CF_ACCESS_CLIENT_SECRET intentionally have no defaults:
# they are only sent when both are present (loopback setups stay header-free).
: "${HAIL_URL:=http://127.0.0.1:8080}"

# 声と口調を同時に決める preset 名（broker の presets/<name>.md と
# tts-synth の presets/<name>.wav に対応）。空なら broker の既定に委ねる。
: "${TTS_NOTIFY_PRESET:=}"
: "${TTS_NOTIFY_CUE:=true}"

# Bounded poll (sec) for the assistant turn to be flushed to the transcript.
: "${TTS_NOTIFY_TRANSCRIPT_WAIT:=5}"

: "${TTS_NOTIFY_CACHE:=$HOME/.cache/tts-notify}"
mkdir -p "$TTS_NOTIFY_CACHE" 2>/dev/null

log() {
  printf '%s [%s] %s\n' "$(date '+%H:%M:%S')" "${SOURCE:-?}" "$*" \
    >> "$TTS_NOTIFY_CACHE/worker.log" 2>/dev/null
}
