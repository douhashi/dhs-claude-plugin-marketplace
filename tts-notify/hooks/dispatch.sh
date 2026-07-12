#!/usr/bin/env bash
#
# tts-notify thin dispatcher (shared by Stop / Notification).
#
# Claude Code blocks until a hook returns, so this MUST be fast and never do
# real work: it only stashes the event JSON and detaches the worker, then
# returns immediately. All extraction / summarize / playback live in worker.sh.
# Any failure is a silent no-op (exit 0) so the hook chain is never broken.
#
set +e

SOURCE="${1:-stop}"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

event="$(cat)"
[ -n "$event" ] || exit 0

# BSD mktemp (macOS) は **テンプレートの末尾が X** でないと失敗する。`XXXXXX.json` のように
# 拡張子を足す書き方は GNU 拡張で、macOS では tmp が空になり dispatch がここで諦めていた
# （= worker が一度も起動しない。しかも失敗は無言）。両方で通る形にする。
tmp="$(mktemp "${TMPDIR:-/tmp}/tts-notify.XXXXXX" 2>/dev/null)" || exit 0
printf '%s' "$event" > "$tmp"

# Detach into a NEW SESSION so the worker outlives this hook invocation.
#
# A new session is required, not just backgrounding: the caller may kill the whole
# process group when the hook returns, which would take a `nohup ... &` child with it
# (nohup only shields against SIGHUP).
#
# `setsid` is Linux (util-linux) and does NOT exist on macOS. Relying on it meant the
# worker was never spawned there — and since every failure here is a silent no-op, the
# hook still "succeeded": no speech, no log, nothing to debug. python3 is already a
# hard dependency of this plugin (lib/*.py), so use it to call setsid(2) portably.
if command -v setsid >/dev/null 2>&1; then
  setsid "$ROOT/bin/worker.sh" "$SOURCE" "$tmp" >/dev/null 2>&1 </dev/null &
else
  python3 -c 'import os,sys; os.setsid(); os.execv(sys.argv[1], sys.argv[1:])' \
    "$ROOT/bin/worker.sh" "$SOURCE" "$tmp" >/dev/null 2>&1 </dev/null &
fi
spawned=$?

# 失敗を完全に握りつぶすと「鳴らないのに原因が何も残らない」状態になる（実際に踏んだ）。
# フックチェーンは壊さない（exit 0）が、理由だけは残す。
if [ "$spawned" -ne 0 ]; then
  cache="${TTS_NOTIFY_CACHE:-$HOME/.cache/tts-notify}"
  mkdir -p "$cache" 2>/dev/null \
    && printf '%s [%s] dispatch: failed to spawn worker (exit=%s)\n' \
       "$(date '+%H:%M:%S')" "$SOURCE" "$spawned" >> "$cache/worker.log" 2>/dev/null
fi

exit 0
