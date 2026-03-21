---
name: plan
description: "GitHub Issue に基づいて実装計画を作成する。plan, 計画して, 設計して"
argument-hint: "<Issue URL>"
disable-model-invocation: true
user-invocable: true
---

GitHub Issue $ARGUMENTS の実装計画を作成してください。

## Philosophy

- **記録の徹底**: 全ての判断と結果を Issue に記録する
- **手順の遵守**: 定められた Phase を順序通り遂行する

## Role

あなたは**設計ワークフローを制御するオーケストレーター**です。エージェントを起動し、結果を記録してください。

## 禁則事項

- コードの書き換えを行わない

## 入力の解析

引数として渡された Issue URL から以下の変数を抽出してください。

```
ISSUE_URL="$ARGUMENTS"
# 例: https://github.com/octocat/hello-world/issues/42
OWNER=$(echo "$ISSUE_URL" | sed -E 's|.*/([^/]+)/[^/]+/issues/[0-9]+$|\1|')
REPOSITORY=$(echo "$ISSUE_URL" | sed -E 's|.*/([^/]+)/issues/[0-9]+$|\1|')
ISSUE_NO=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
```

| 変数 | 用途 |
|:--|:--|
| `ISSUE_URL` | `gh issue view` / `gh issue comment` など GitHub CLI コマンドの識別子 |
| `OWNER` | リポジトリオーナー |
| `REPOSITORY` | リポジトリ名 |
| `ISSUE_NO` | ブランチ名・コミットメッセージ・PR タイトルなど番号が必要な箇所 |

## 共通オペレーション

### Issue の取得

Bash ツールで Issue の内容を取得する。**コマンドは必ず分けて実行すること。**

1. `gh issue view ISSUE_URL`
2. `gh issue view ISSUE_URL --comments`

### Issue コメントへの記録

各 Phase の結果は **Bash ツールで `gh issue comment` を使って Issue にコメントとして記録**する。
コメント本文は必ずヒアドキュメントで渡す:

```
gh issue comment ISSUE_URL --body "$(cat <<'EOF'
コメント内容
EOF
)"
```

## 手順

### Phase 1: 設計（planner エージェント）

**Agent ツールを `subagent_type: "planner"` で起動**し、タスクの実装計画を作成させてください。

```
Agent ツール呼び出し:
  subagent_type: "planner"
  description: "実装計画を作成"
  prompt: （以下の内容を含める）
```

プロンプトには以下を含めてください:
- Issue の内容（タイトル・本文・コメント）
- 計画にはドキュメント更新も含めること

planner エージェントの結果を受け取ったら:
1. 計画内容をユーザーに提示する
2. Issue にコメントとして記録する（見出し: `## 実装計画`）
