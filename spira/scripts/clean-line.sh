#!/usr/bin/env bash
#
# 完了せずに終わったライン（Issue N）が残した impl-N を片付ける。
#   ブランチ impl-N（spira:do が作る）:
#     worktree・ローカルブランチ・head impl-N の Open PR・リモートブランチを削除する
#   ブランチ */impl-N（Orca のライン。例: douhashi/impl-N）:
#     Open PR を閉じ、worktree は削除せずに既定ブランチへ戻す（再試行で使い回すため）
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

close_prs() {
  for PR in $1; do
    gh pr close "$PR" --repo "$REPO" --delete-branch >/dev/null
    echo "PR を閉じた: #$PR"
  done
}

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

close_prs "$(gh pr list --repo "$REPO" --head "$B" --state open --json number --jq '.[].number')"

if git -C "$ROOT" ls-remote --exit-code --heads origin "$B" >/dev/null; then
  git -C "$ROOT" push --quiet origin --delete "$B"
  echo "リモートブランチを削除: $B"
fi

# Orca のライン（*/impl-N）
close_prs "$(gh pr list --repo "$REPO" --state open --limit 200 --json number,headRefName \
  --jq ".[] | select(.headRefName | endswith(\"/$B\")) | .number")"

OWS=$(git -C "$ROOT" worktree list --porcelain |
  awk -v s="/$B" '/^worktree /{w=substr($0,10)}
    /^branch refs\/heads\//{b=substr($0,19); if (length(b) > length(s) && substr(b, length(b)-length(s)+1) == s) print w}')
[ -n "$OWS" ] || exit 0
DEF=$(gh repo view "$REPO" --json defaultBranchRef --jq .defaultBranchRef.name)
git -C "$ROOT" fetch --quiet origin
while IFS= read -r OW; do
  if [ "$(git -C "$OW" rev-parse HEAD)" != "$(git -C "$ROOT" rev-parse "origin/$DEF")" ] ||
    [ -n "$(git -C "$OW" status --porcelain --untracked-files=no)" ]; then
    git -C "$OW" reset --hard --quiet "origin/$DEF"
    echo "ワークツリーを origin/$DEF に戻した: $OW"
  fi
done <<<"$OWS"
