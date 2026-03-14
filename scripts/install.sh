#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKETPLACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MARKETPLACE_NAME="dhs-claude-plugin-marketplace"
PLUGIN_NAME="${1:-spira}"

echo "==> マーケットプレイスを登録: $MARKETPLACE_DIR"
claude plugin marketplace add "$MARKETPLACE_DIR"

echo "==> プラグインをインストール: ${PLUGIN_NAME}@${MARKETPLACE_NAME}"
claude plugin install "${PLUGIN_NAME}@${MARKETPLACE_NAME}"

echo "==> 完了。Claude Code を再起動してください。"
