# shellcheck shell=bash
#
# tts-notify shared config / helpers. Sourced by bin/worker.sh.
#
# Config precedence: existing env > ~/.config/tts-notify/env > defaults.
# The secret (OPENROUTER_API_KEY) lives ONLY in the env file (chmod 600,
# outside any git repo) — never in this plugin.

TTS_NOTIFY_CONFIG="${TTS_NOTIFY_CONFIG:-$HOME/.config/tts-notify/env}"
if [ -f "$TTS_NOTIFY_CONFIG" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$TTS_NOTIFY_CONFIG"
  set +a
fi

# OpenRouter (defaults mirror the reference coordinator).
: "${OPENROUTER_MODEL:=openai/gpt-5-mini}"
: "${OPENROUTER_URL:=https://openrouter.ai/api/v1/chat/completions}"
# OPENROUTER_API_KEY intentionally has no default (empty => graceful degrade).

# Playback via stt-tts-runpod's tts_say.sh. Overridable for other machines.
: "${TTS_NOTIFY_SAY:=$HOME/ghq/github.com/douhashi/stt-tts-runpod/scripts/tts_say.sh}"
: "${TTS_NOTIFY_PRESET:=gena}"
: "${TTS_NOTIFY_VOLUME:=50}"
: "${TTS_NOTIFY_CUE:=default}"

# Bounded poll (sec) for the assistant turn to be flushed to the transcript.
: "${TTS_NOTIFY_TRANSCRIPT_WAIT:=5}"

: "${TTS_NOTIFY_CACHE:=$HOME/.cache/tts-notify}"
mkdir -p "$TTS_NOTIFY_CACHE" 2>/dev/null

log() {
  printf '%s [%s] %s\n' "$(date '+%H:%M:%S')" "${SOURCE:-?}" "$*" \
    >> "$TTS_NOTIFY_CACHE/worker.log" 2>/dev/null
}
