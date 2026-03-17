---
name: implement
description: "GitHub Issue に基づいて設計・実装・レビューを自律的に回す開発サイクル。implement, develop, build, 実装して、開発して"
argument-hint: "<Issue URL>"
disable-model-invocation: true
user-invocable: true
---

GitHub Issue $ARGUMENTS の設計 → 実装 → レビューの開発サイクルを実行してください。

## Issue URL の解析

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

## Phase 0: 環境準備（setup エージェント）

**Agent ツールを `subagent_type: "setup"` で起動**し、リポジトリのクローンと開発環境のセットアップを行わせてください。

```
Agent ツール呼び出し:
  subagent_type: "setup"
  description: "リポジトリのクローンと環境構築"
  prompt: （以下の内容を含める）
```

プロンプトには以下の手順を **この順序で** 実行するよう指示してください:

1. `gh q get OWNER/REPOSITORY` でリポジトリをクローンする
2. `cd ~/ghq/github.com/OWNER/REPOSITORY` で作業ディレクトリに移動する
3. `.coder/setup.sh` が存在する場合は実行する（`bash .coder/setup.sh`）

**以降のすべての Phase は `~/ghq/github.com/OWNER/REPOSITORY` を作業ディレクトリとして実行してください。**

## Issue の取得

まず Bash ツールで Issue の内容を取得してください。**コマンドは必ず分けて実行すること。**

1. `gh issue view ISSUE_URL`
2. `gh issue view ISSUE_URL --comments`

取得した内容をもとに以降の Phase を進めてください。

## Issue コメントへの記録

各 Phase の結果は **Bash ツールで `gh issue comment` を使って Issue にコメントとして記録**してください。
コメント本文は必ずヒアドキュメントで渡してください:

```
gh issue comment ISSUE_URL --body "$(cat <<'EOF'
コメント内容
EOF
)"
```

## ワークツリーの作成

実装作業の前に、`gh wt` を使ってワークツリーを作成してください。

```
gh wt add impl-ISSUE_NO
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

### Phase 2: 実装（implementer or setup エージェント）

Phase 1 の計画内容から、タスクの種類を判定してください。

**判定基準**:
- **環境構築タスク**: ライブラリのインストール、環境マネージャ（mise 等）の設定、フレームワークの初期化、CI の設定など、開発環境のセットアップが主目的の場合 → `setup` エージェントを使用
- **コード実装タスク**: 機能追加、バグ修正、リファクタリングなど、アプリケーションコードの変更が主目的の場合 → `implementer` エージェントを使用

判断に迷う場合（環境構築とコード実装の両方を含む等）は、主目的に応じて選択してください。

#### setup エージェントを使う場合

**Agent ツールを `subagent_type: "setup"` で起動**し、Phase 1 の計画に基づいて環境を構築させてください。
**ワークツリー `impl-ISSUE_NO` 内で作業すること。**

```
Agent ツール呼び出し:
  subagent_type: "setup"
  description: "計画に基づいて環境構築"
  prompt: （以下の内容を含める）
```

プロンプトには以下を含めてください:
- Phase 1 で作成された実装計画の全文
- 計画に忠実に環境を構築すること
- ワークツリーのパス（`gh wt list` で確認）内で作業すること

#### implementer エージェントを使う場合

**Agent ツールを `subagent_type: "implementer"` で起動**し、Phase 1 の計画に基づいてコードを実装させてください。
**ワークツリー `impl-ISSUE_NO` 内で作業すること。**

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

#### 共通: 結果の記録

エージェントの結果を受け取ったら:
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
2. **Phase 2 で使用したのと同じエージェント（`setup` または `implementer`）を再度起動**し、ワークツリー `impl-ISSUE_NO` 内で指摘事項を修正させる
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
   gh wt -- git commit -m "Implement #ISSUE_NO"
   ```
2. リモートにプッシュする
   ```
   gh wt -- git push -u origin HEAD
   ```
3. PR を作成する
   ```
   gh pr create --head impl-ISSUE_NO --title "Implement #ISSUE_NO" --body "$(cat <<'EOF'
   Closes #ISSUE_NO

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
2. **Phase 2 で使用したのと同じエージェント（`setup` または `implementer`）を起動**し、ワークツリー `impl-ISSUE_NO` 内で CI 失敗の原因を修正させる
   - プロンプトには失敗したチェック名・エラー内容を含めること
3. 修正内容を Issue にコメントとして記録する（見出し: `## CI 修正 (N回目)`）
4. ワークツリー内で変更をコミット・プッシュする
   ```
   gh wt -- git add -A
   gh wt -- git commit -m "Fix CI failure for #ISSUE_NO (attempt N)"
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
Issue URL は ISSUE_URL をそのまま使用してください。
