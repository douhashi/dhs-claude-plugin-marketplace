# shellcheck shell=bash
#
# Shared helpers for the marketplace install / uninstall / update scripts.
# Source this from a wrapper:  . "$(dirname "$0")/lib.sh"
#
# Single source of truth for the plugin list is .claude-plugin/marketplace.json
# (`.plugins[].name`), so newly added plugins are picked up automatically with
# no script changes.
set -euo pipefail

MARKETPLACE_NAME="dhs-claude-plugin-marketplace"
# Resolve relative to THIS file (works regardless of the caller's CWD).
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKETPLACE_DIR="$(cd "$_LIB_DIR/.." && pwd)"
MANIFEST="$MARKETPLACE_DIR/.claude-plugin/marketplace.json"

command -v claude >/dev/null 2>&1 || { echo "lib.sh: 'claude' CLI not found" >&2; exit 1; }
command -v jq     >/dev/null 2>&1 || { echo "lib.sh: 'jq' not found" >&2; exit 1; }
[ -f "$MANIFEST" ] || { echo "lib.sh: manifest not found: $MANIFEST" >&2; exit 1; }

# Target plugins: explicit args win; otherwise ALL plugins in the manifest.
mp_targets() {
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$@"
  else
    jq -r '.plugins[].name' "$MANIFEST"
  fi
}

mp_register() {
  echo "==> マーケットプレイスを登録: $MARKETPLACE_DIR"
  claude plugin marketplace add "$MARKETPLACE_DIR"
}

mp_install() {
  echo "==> インストール: ${1}@${MARKETPLACE_NAME}"
  claude plugin install "${1}@${MARKETPLACE_NAME}"
}

# Uninstall is idempotent (a not-installed plugin must not abort a batch).
mp_uninstall() {
  echo "==> アンインストール: ${1}@${MARKETPLACE_NAME}"
  claude plugin uninstall "${1}@${MARKETPLACE_NAME}" || true
}

mp_done() { echo "==> 完了。Claude Code を再起動してください。"; }

# Run $1 (mp_install|mp_uninstall) over the resolved target list.
mp_foreach() {
  local fn="$1"; shift
  local p
  while IFS= read -r p; do
    [ -n "$p" ] && "$fn" "$p"
  done < <(mp_targets "$@")
}
