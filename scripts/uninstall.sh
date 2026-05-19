#!/usr/bin/env bash
#
# Uninstall marketplace plugins.
#   scripts/uninstall.sh            # ALL plugins (from marketplace.json)
#   scripts/uninstall.sh tts-notify # only the named plugin(s)
#
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

mp_foreach mp_uninstall "$@"
mp_done
