---
name: implement
description: "GitHub Issue に基づいて設計・実装・レビューを自律的に回す開発サイクル。implement, develop, build, 実装して、開発して"
argument-hint: "<Issue番号>"
disable-model-invocation: true
user-invocable: true
---

GitHub Issue #$ARGUMENTS の設計 → 実装 → レビューの開発サイクルを実行してください。

## Issue の取得

まず Bash ツールで Issue の内容を取得してください。**コマンドは必ず分けて実行すること。**

1. `gh issue view $ARGUMENTS`
2. `gh issue view $ARGUMENTS --comments`

取得した内容をもとに以降の Phase を進めてください。

## Issue コメントへの記録

各 Phase の結果は **Bash ツールで `gh issue comment` を使って Issue にコメントとして記録**してください。
コメント本文は必ずヒアドキュメントで渡してください:

```
gh issue comment $ARGUMENTS --body "$(cat <<'EOF'
コメント内容
EOF
)"
```

## ワークツリーの作成

実装作業の前に、`gh wt` を使ってワークツリーを作成してください。

```
gh wt add impl-$ARGUMENTS
```

以降の Phase 2（実装）および Phase 4（修正）では、このワークツリー内で作業を行ってください。
ワークツリー内でコマンドを実行するには以下の形式を使います:

```
gh wt -- git diff
gh wt -- npm test
```

## 手順

### Phase 1: 設計（planner エージェント）

Agent ツールで `planner` サブエージェントを起動し、タスクの実装計画を作成させてください。

プロンプトには以下を含めてください:
- Issue の内容（タイトル・本文・コメント）
- 計画には CLAUDE.md の「コードとドキュメントの同期」方針に従い、ドキュメント更新も含めること

planner の結果を受け取ったら:
1. 計画内容をユーザーに提示する
2. Issue にコメントとして記録する（見出し: `## 実装計画`）

### Phase 2: 実装（implementer エージェント）

Agent ツールで `implementer` サブエージェントを起動し、Phase 1 の計画に基づいてコードを実装させてください。
**ワークツリー `impl-$ARGUMENTS` 内で作業すること。**

プロンプトには以下を含めてください:
- Phase 1 で作成された実装計画の全文
- 計画に忠実に実装すること
- ワークツリーのパス（`gh wt list` で確認）内で作業すること

implementer の結果を受け取ったら:
1. 変更内容の概要をユーザーに提示する
2. Issue にコメントとして記録する（見出し: `## 実装内容`、変更ファイル一覧と概要）

### Phase 3: レビュー（reviewer エージェント）

Agent ツールで `reviewer` サブエージェントを起動し、Phase 2 の変更をレビューさせてください。

プロンプトには以下を含めてください:
- Issue の内容
- 実装計画の概要
- ワークツリー内で `gh wt -- git diff` を使って変更内容を確認すること

reviewer の結果を受け取ったら:
1. レビュー結果をユーザーに提示する
2. Issue にコメントとして記録する（見出し: `## レビュー結果`）

### Phase 4: 修正（必要な場合のみ）

reviewer が「要修正」と判定した場合:
1. 問題点をまとめる
2. `implementer` サブエージェントを再度起動し、ワークツリー `impl-$ARGUMENTS` 内で指摘事項を修正させる
3. 修正内容を Issue にコメントとして記録する（見出し: `## 修正内容`）
4. 再度 `reviewer` サブエージェントでレビューする
5. レビュー結果を Issue にコメントとして記録する
6. 「OK」になるまで繰り返す（最大 2 回まで）

reviewer が「OK」の場合はそのまま完了報告に進んでください。

### Phase 5: 完了報告

以下を Issue にコメントとして記録してください（見出し: `## 完了報告`）:
- 変更したファイルの一覧
- 変更内容の概要
- レビュー結果の要約

最後に、ユーザーへの最終報告としてリポジトリの Issue URL を含む簡潔なサマリーを出力してください。
Issue URL は `gh issue view $ARGUMENTS --json url -q .url` で取得してください。
