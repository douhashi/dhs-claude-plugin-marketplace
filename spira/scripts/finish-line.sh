#!/usr/bin/env bash
#
# 完了した Orca のライン（Issue N）が残したワークツリーとブランチを片付ける。
#   ワークツリー: ブランチが */impl-N のもの（git）と、表示名が impl-N のもの（Orca）を
#     Orca の登録ごと削除する（orca が失敗したら git だけで削除する）
#   ブランチ: ローカル・リモートの */impl-N を削除する（スカッシュマージでは Orca が残すため）
# spira:do が作る impl-N（完全一致）は扱わない。対象が無い操作は何もしない（冪等）。
# 実施した内容を 1 行ずつ出力する。
#
# 使い方: finish-line.sh ROOT REPO N
#   ROOT: リポジトリのルート  REPO: OWNER/NAME（clean-line.sh と呼び出しを揃えるため。未使用）  N: Issue 番号
set -euo pipefail

usage() { echo "usage: finish-line.sh ROOT REPO N" >&2; exit 2; }
[ "$#" -eq 3 ] || usage
ROOT=$1 N=$3
case $N in '' | *[!0-9]*) usage ;; esac
B="impl-$N"

# 「ブランチ<TAB>値」の各行のうち、ブランチが */impl-N（末尾が /impl-N で、それより長い）の行の最後の列を出す
pick() {
  awk -F'\t' -v s="/$B" 'length($1) > length(s) && substr($1, length($1)-length(s)+1) == s {print $NF}'
}

git -C "$ROOT" worktree prune
WTS=$(
  {
    git -C "$ROOT" worktree list --porcelain |
      awk '/^worktree /{w=substr($0,10)} /^branch refs\/heads\//{print substr($0,19) "\t" w}' | pick
    if command -v orca >/dev/null; then
      orca worktree list --repo "path:$ROOT" --json 2>/dev/null |
        jq -r --arg n "$B" '.result.worktrees[] | select(.displayName == $n and (.isMainWorktree | not)) | .path' ||
        true
    fi
  } | sort -u
)
in_git() { git -C "$ROOT" worktree list --porcelain | grep -qxF "worktree $1"; }

while IFS= read -r W; do
  [ -n "$W" ] || continue
  if orca worktree rm --worktree "path:$W" --force --json >/dev/null 2>&1; then
    # orca は削除を非同期で仕上げる（removing: true）ため、git から消えるまで最大 10 秒待つ
    for _ in $(seq 20); do
      git -C "$ROOT" worktree prune
      in_git "$W" || break
      sleep 0.5
    done
  elif in_git "$W"; then
    git -C "$ROOT" worktree remove --force "$W"
  fi
  echo "ワークツリーを削除: $W"
done <<<"$WTS"

# orca がワークツリーと一緒にブランチを消すことがあるため、消えていれば失敗とみなさない
for BR in $(git -C "$ROOT" for-each-ref --format='%(refname:short)' refs/heads/ | pick); do
  if git -C "$ROOT" branch -D "$BR" >/dev/null 2>&1; then
    echo "ローカルブランチを削除: $BR"
  elif git -C "$ROOT" show-ref --verify --quiet "refs/heads/$BR"; then
    git -C "$ROOT" branch -D "$BR" >/dev/null
  fi
done

for BR in $(git -C "$ROOT" ls-remote --heads origin | awk '{sub("^refs/heads/", "", $2); print $2}' | pick); do
  git -C "$ROOT" push --quiet origin --delete "$BR"
  echo "リモートブランチを削除: $BR"
done
