---
name: implement
description: "GitHub Issue に基づいて実装・レビューを自律的に回す開発サイクル。implement, develop, build, 実装して、開発して"
argument-hint: "<Issue URL>"
disable-model-invocation: true
user-invocable: true
---

GitHub Issue $ARGUMENTS の実装 → レビューの開発サイクルを実行してください。
事前に `spira:plan` で作成された実装計画が Issue コメントに記録されている前提です。

## Philosophy

- **記録の徹底**: 全ての判断と結果を Issue に記録する
- **手順の遵守**: 定められた Phase を順序通り遂行する

## Role

あなたは**実装ワークフローを制御するオーケストレーター**です。エージェントを起動し、結果を記録してください。

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

### ワークツリーの作成

実装作業の前に、ワークツリーを作成する。

```
git worktree add ../impl-ISSUE_NO -b impl-ISSUE_NO
```

ワークツリーのパスは `gh wt list` で確認できる。
以降の Phase 2（実装）および Phase 4（修正）では、このワークツリー内で作業を行う。

## 手順

### Phase 2: 実装（implementer or setup エージェント）

Issue コメントに記録されている実装計画（見出し: `## 実装計画`）を取得し、タスクの種類を判定してください。

**判定基準**:
- **環境構築タスク**: ライブラリのインストール、環境マネージャ（mise 等）の設定、フレームワークの初期化、CI の設定など、開発環境のセットアップが主目的の場合 → `setup` エージェントを使用
- **コード実装タスク**: 機能追加、バグ修正、リファクタリングなど、アプリケーションコードの変更が主目的の場合 → `implementer` エージェントを使用

判断に迷う場合（環境構築とコード実装の両方を含む等）は、主目的に応じて選択してください。

#### setup エージェントを使う場合

**Agent ツールを `subagent_type: "setup"` で起動**し、実装計画に基づいて環境を構築させてください。
**ワークツリー `impl-ISSUE_NO` 内で作業すること。**

```
Agent ツール呼び出し:
  subagent_type: "setup"
  description: "計画に基づいて環境構築"
  prompt: （以下の内容を含める）
```

プロンプトには以下を含めてください:
- Issue コメントから取得した実装計画の全文
- 計画に忠実に環境を構築すること
- ワークツリー内で作業すること

#### implementer エージェントを使う場合

**Agent ツールを `subagent_type: "implementer"` で起動**し、実装計画に基づいてコードを実装させてください。
**ワークツリー `impl-ISSUE_NO` 内で作業すること。**

```
Agent ツール呼び出し:
  subagent_type: "implementer"
  description: "計画に基づいて実装"
  prompt: （以下の内容を含める）
```

プロンプトには以下を含めてください:
- Issue コメントから取得した実装計画の全文
- 計画に忠実に実装すること
- ワークツリー内で作業すること
- 計画の「検証必須事項」のうち implementer 担当項目は、すべて検証を実施し `### 検証実施結果` セクションに証拠とともに報告すること（証拠ファイルは `.tmp/spira-evidence/` 配下に保存）

#### 共通: 結果の記録

エージェントの結果を受け取ったら:
1. 変更内容の概要をユーザーに提示する
2. Issue にコメントとして記録する（見出し: `## 実装内容`、変更ファイル一覧と概要）
3. 「設計判断が必要な論点」が「なし」でなければ Phase 2.5 に進む。「なし」であれば Phase 3 に進む

### Phase 2.5: 設計判断（PO エージェント）

implementer が挙げた設計判断の論点ごとに、**Agent ツールを `subagent_type: "po"` で起動**して判断を得てください。

```
Agent ツール呼び出し:
  subagent_type: "po"
  description: "設計判断を実施"
  prompt: （以下の内容を含める）
```

プロンプトには以下を含めてください:
- 論点の内容（何について判断が必要か、選択肢、暫定実装）
- Issue の内容（背景として）

複数の論点がある場合は、**独立した論点は並行で**、依存関係がある論点は順次起動する。

PO エージェントの判断を受け取ったら:
1. 判断結果をユーザーに提示する
2. Issue にコメントとして記録する（見出し: `## 設計判断`）
3. 暫定実装と判断が異なる場合は、Phase 2 で使用したのと同じエージェントを再度起動し、判断結果に基づいて修正させる。修正内容を Issue にコメントとして記録する（見出し: `## 設計判断に基づく修正`）

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
- ワークツリー内で `git diff` を使って変更内容を確認すること

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
   git add -A
   git commit -m "Implement #ISSUE_NO"
   ```
2. リモートにプッシュする
   ```
   git push -u origin HEAD
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
   git add -A
   git commit -m "Fix CI failure for #ISSUE_NO (attempt N)"
   git push
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
