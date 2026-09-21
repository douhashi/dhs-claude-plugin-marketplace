#!/usr/bin/env bash
#
# 完了せずに終わったライン（Issue N）が残した impl-N を片付ける。
#   worktree・ローカルブランチ・head impl-N の Open PR・リモートブランチ
# 対象が無い操作は何もしない（冪等）。実施した内容を 1 行ずつ出力する。
#
# 使い方: clean-line.sh ROOT REPO N
#   ROOT: リポジトリのルート  REPO: OWNER/NAME  N: Issue 番号
set -euo pipefail

usage() { echo "usage: clean-line.sh ROOT REPO N" >&2; exit 2; }
[ "$#" -eq 3 ] || usage
ROOT=$1 REPO=$2 N=$3
case $N in '' | *[!0-9]*) usage ;; esac
B="impl-$N"

git -C "$ROOT" worktree prune
W=$(git -C "$ROOT" worktree list --porcelain |
  awk -v ref="branch refs/heads/$B" '/^worktree /{w=substr($0,10)} $0==ref{print w}')
if [ -n "$W" ]; then
  git -C "$ROOT" worktree remove --force "$W"
  echo "worktree を削除: $W"
fi

if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$B"; then
  git -C "$ROOT" branch -D "$B" >/dev/null
  echo "ローカルブランチを削除: $B"
fi

PRS=$(gh pr list --repo "$REPO" --head "$B" --state open --json number --jq '.[].number')
for PR in $PRS; do
  gh pr close "$PR" --repo "$REPO" --delete-branch >/dev/null
  echo "PR を閉じた: #$PR"
done

if git -C "$ROOT" ls-remote --exit-code --heads origin "$B" >/dev/null; then
  git -C "$ROOT" push --quiet origin --delete "$B"
  echo "リモートブランチを削除: $B"
fi
