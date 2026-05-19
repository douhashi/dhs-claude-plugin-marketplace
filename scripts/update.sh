#!/usr/bin/env bash
#
# Reinstall (uninstall -> re-register -> install) marketplace plugins.
#   scripts/update.sh            # ALL plugins (from marketplace.json)
#   scripts/update.sh tts-notify # only the named plugin(s)
#
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

mp_foreach mp_uninstall "$@"
mp_register
mp_foreach mp_install "$@"
mp_done
