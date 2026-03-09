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

**Agent ツールを `subagent_type: "planner"` で起動**し、タスクの実装計画を作成させてください。

```
Agent ツール呼び出し:
  subagent_type: "planner"
  description: "実装計画を作成"
  prompt: （以下の内容を含める）
```

プロンプトには以下を含めてください:
- Issue の内容（タイトル・本文・コメント）
- 計画には CLAUDE.md の「コードとドキュメントの同期」方針に従い、ドキュメント更新も含めること

planner エージェントの結果を受け取ったら:
1. 計画内容をユーザーに提示する
2. Issue にコメントとして記録する（見出し: `## 実装計画`）

### Phase 2: 実装（implementer エージェント）

**Agent ツールを `subagent_type: "implementer"` で起動**し、Phase 1 の計画に基づいてコードを実装させてください。
**ワークツリー `impl-$ARGUMENTS` 内で作業すること。**

```
Agent ツール呼び出し:
  subagent_type: "implementer"
  description: "計画に基づいて実装"
  prompt: （以下の内容を含める）
```

プロンプトには以下を含めてください:
- Phase 1 で作成された実装計画の全文
- 計画に忠実に実装すること
- ワークツリーのパス（`gh wt list` で確認）内で作業すること

implementer エージェントの結果を受け取ったら:
1. 変更内容の概要をユーザーに提示する
2. Issue にコメントとして記録する（見出し: `## 実装内容`、変更ファイル一覧と概要）

### Phase 3: レビュー（reviewer エージェント）

**Agent ツールを `subagent_type: "reviewer"` で起動**し、Phase 2 の変更をレビューさせてください。

```
Agent ツール呼び出し:
  subagent_type: "reviewer"
  description: "実装内容をレビュー"
  prompt: （以下の内容を含める）
```

プロンプトには以下を含めてください:
- Issue の内容
- 実装計画の概要
- ワークツリー内で `gh wt -- git diff` を使って変更内容を確認すること

reviewer エージェントの結果を受け取ったら:
1. レビュー結果をユーザーに提示する
2. Issue にコメントとして記録する（見出し: `## レビュー結果`）

### Phase 4: 修正（必要な場合のみ）

reviewer エージェントが「要修正」と判定した場合:
1. 問題点をまとめる
2. **Agent ツールを `subagent_type: "implementer"` で再度起動**し、ワークツリー `impl-$ARGUMENTS` 内で指摘事項を修正させる
3. 修正内容を Issue にコメントとして記録する（見出し: `## 修正内容 (N回目)`）
4. **Agent ツールを `subagent_type: "reviewer"` で再度起動**してレビューする
5. レビュー結果を Issue にコメントとして記録する
6. 「OK」になるまで繰り返す（**最大 5 回まで**）

reviewer が「OK」の場合は Phase 5 に進んでください。

**5 回修正してもレビューが通らない場合**: 修正を打ち切り、Issue にコメント（見出し: `## 修正打ち切り`）で状況を記録し、ユーザーに報告して終了してください。以降の Phase は実行しません。

### Phase 5: PR 作成

レビュー通過後、ワークツリーのブランチから PR を作成してください。

1. ワークツリー内で変更をコミットする（未コミットの変更がある場合）
   ```
   gh wt -- git add -A
   gh wt -- git commit -m "Implement #$ARGUMENTS"
   ```
2. リモートにプッシュする
   ```
   gh wt -- git push -u origin HEAD
   ```
3. PR を作成する
   ```
   gh pr create --head impl-$ARGUMENTS --title "Implement #$ARGUMENTS" --body "$(cat <<'EOF'
   Closes #$ARGUMENTS

   ## 変更内容
   （実装内容の概要をここに記述）

   ## レビュー結果
   内部レビュー通過済み
   EOF
   )"
   ```
4. PR の URL を Issue にコメントとして記録する（見出し: `## PR 作成`）

### Phase 6: QA・CI 修正ループ

以下の手順を **最大 5 回** 繰り返してください。

#### 6a. CI チェック監視（qa エージェント）

**Agent ツールを `subagent_type: "qa"` で起動**し、CI チェックの監視を行わせてください。

```
Agent ツール呼び出し:
  subagent_type: "qa"
  description: "CI監視と自動マージ"
  prompt: （以下の内容を含める）
```

プロンプトには以下を含めてください:
- PR 番号
- CI チェックが全て通過したら squash マージすること

#### 6b. 結果に応じた分岐

**CI 通過・マージ成功の場合**: Phase 7（完了報告）に進む。

**CI 失敗の場合**:
1. qa エージェントから返された失敗内容を Issue にコメントとして記録する（見出し: `## CI 失敗 (N回目)`）
2. **Agent ツールを `subagent_type: "implementer"` で起動**し、ワークツリー `impl-$ARGUMENTS` 内で CI 失敗の原因を修正させる
   - プロンプトには失敗したチェック名・エラー内容を含めること
3. 修正内容を Issue にコメントとして記録する（見出し: `## CI 修正 (N回目)`）
4. ワークツリー内で変更をコミット・プッシュする
   ```
   gh wt -- git add -A
   gh wt -- git commit -m "Fix CI failure for #$ARGUMENTS (attempt N)"
   gh wt -- git push
   ```
5. 6a に戻り、再度 qa エージェントで CI チェックを監視する

**5 回修正しても CI が通らない場合**: 修正を打ち切り、Issue にコメント（見出し: `## CI 修正打ち切り`）で状況を記録し、ユーザーに報告して終了してください。以降の Phase は実行しません。

### Phase 7: 完了報告

以下を Issue にコメントとして記録してください（見出し: `## 完了報告`）:
- 変更したファイルの一覧
- 変更内容の概要
- レビュー結果の要約
- PR URL とマージ結果

最後に、ユーザーへの最終報告としてリポジトリの Issue URL と PR URL を含む簡潔なサマリーを出力してください。
Issue URL は `gh issue view $ARGUMENTS --json url -q .url` で取得してください。
