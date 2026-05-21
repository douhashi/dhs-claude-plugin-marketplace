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

tmp="$(mktemp /tmp/tts-notify.XXXXXX.json 2>/dev/null)" || exit 0
printf '%s' "$event" > "$tmp"

# Detach into a new session so the worker outlives this hook invocation.
setsid "$ROOT/bin/worker.sh" "$SOURCE" "$tmp" >/dev/null 2>&1 </dev/null &

exit 0
