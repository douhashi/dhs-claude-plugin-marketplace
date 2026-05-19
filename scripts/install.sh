#!/usr/bin/env bash
#
# Install marketplace plugins.
#   scripts/install.sh            # ALL plugins (from marketplace.json)
#   scripts/install.sh tts-notify # only the named plugin(s)
#
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

mp_register
mp_foreach mp_install "$@"
mp_done
