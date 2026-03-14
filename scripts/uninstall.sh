#!/usr/bin/env bash
set -euo pipefail

MARKETPLACE_NAME="dhs-claude-plugin-marketplace"
PLUGIN_NAME="${1:-spira}"

echo "==> プラグインをアンインストール: ${PLUGIN_NAME}@${MARKETPLACE_NAME}"
claude plugin uninstall "${PLUGIN_NAME}@${MARKETPLACE_NAME}"

echo "==> 完了。Claude Code を再起動してください。"
