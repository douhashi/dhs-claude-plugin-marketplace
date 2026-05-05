---
name: do
description: "GitHub Issue に基づいて計画から PR マージまでを一気通貫で自律実行する。do, やって, 進めて"
argument-hint: "<Issue URL>"
user-invocable: true
---

GitHub Issue $ARGUMENTS について、計画 → 実装 → PR 作成 → CI 監視・マージまでを単一フローで実行してください。
`planned` ラベルが既に付いている場合は計画フェーズをスキップします。

## Philosophy

- **記録の徹底**: 全ての判断と結果を Issue に記録する
- **手順の遵守**: 定められた Phase を順序通り遂行する

## Role

あなたは**開発サイクル全体を制御するオーケストレーター**です。エージェントを起動し、結果を Issue に記録させてください。

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

### Issue へのコメント記録

各 Phase の結果は、起動した **エージェント自身** が `gh issue comment` で記録する。
オーケストレータはエージェントへのプロンプトに以下を必ず含めること。

- `ISSUE_URL`
- そのフェーズで使用する見出し

エージェントが記録した旨の応答を受け取ったら、サマリのみをユーザーに提示する（再度 `gh issue comment` を打つ必要はない）。

ただし以下のオーケストレータ自身が直接 Issue に書き込むコメントは例外として、Bash ツールで `gh issue comment` を使用する。
- `## PR 作成`
- `## CI 修正打ち切り`
- `## 完了報告`

### ワークツリーの作成

実装作業の前に、ワークツリーを作成する。

```
git worktree add ../REPOSITORY-impl-ISSUE_NO -b impl-ISSUE_NO
```

ワークツリーのパスは `git worktree list` で確認できる。
以降の実装フェーズと CI 修正フェーズでは、このワークツリー内で作業を行う。

### planned ラベルの確保

計画完了後にラベル付与で使用する。ラベルが存在しない場合は青色（`0075ca`）で作成すること。

```
gh label list --repo OWNER/REPOSITORY --search planned --json name --jq '.[].name' | grep -x planned || \
  gh label create planned --repo OWNER/REPOSITORY --color 0075ca --description "実装計画が策定済み"
```

### escalated ラベルの確保

CI 修正打ち切り時の Issue 起票で使用する。ラベルが存在しない場合は赤色（`d73a4a`）で作成すること。

```
gh label list --repo OWNER/REPOSITORY --search escalated --json name --jq '.[].name' | grep -x escalated || \
  gh label create escalated --repo OWNER/REPOSITORY --color d73a4a --description "人手による対応が必要"
```

## 手順

### Phase 0: 計画策定済みチェック

Issue のラベルを取得する。

```
gh issue view ISSUE_URL --json labels --jq '.labels[].name'
```

`planned` ラベルが付与されている場合は **Phase 1 と Phase 1.5 をスキップ** し、Phase 2 から開始する。
付与されていない場合は Phase 1 から開始する。

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
- 「検証必須事項」を必ず記述すること（該当がない場合のみ「なし」）
- `ISSUE_URL` と見出し `## 実装計画` を渡し、計画全文を **planner エージェント自身が** `gh issue comment` で記録すること

planner エージェントの結果を受け取ったら:
1. 計画内容のサマリをユーザーに提示する
2. 「設計判断が必要な論点」が「なし」でなければ Phase 1.5 に進む。「なし」であれば Phase 1.9 に進む

### Phase 1.5: 設計判断（PO エージェント・計画フェーズ）

planner が挙げた設計判断の論点を **すべて 1 つのプロンプトに集約** し、**Agent ツールを `subagent_type: "po"` で 1 回だけ起動**して判断を得てください。

```
Agent ツール呼び出し:
  subagent_type: "po"
  description: "設計判断を実施"
  prompt: （以下の内容を含める）
```

プロンプトには以下を含めてください:
- 全論点の内容を番号付きで列挙
- 各論点の選択肢と判断に必要な情報
- Issue の内容（背景として）
- `ISSUE_URL` と見出し `## 設計判断` を渡し、判断全文を **PO エージェント自身が** `gh issue comment` で記録すること

PO エージェントの判断を受け取ったら:
1. 判断結果のサマリをユーザーに提示する
2. 判断結果を反映した実装計画の修正が必要であれば、planner エージェントを再度起動し、見出し `## 実装計画（修正版）` で再記録させる
3. Phase 1.9 に進む

### Phase 1.9: planned ラベル付与

Issue に `planned` ラベルを付与する。

```
gh issue edit ISSUE_URL --add-label planned
```

### Phase 2: 実装（implementer or setup エージェント）

Issue コメントに記録されている実装計画（見出し: `## 実装計画`、修正版があれば `## 実装計画（修正版）`）を取得し、タスクの種類を判定してください。

**判定基準**:
- **環境構築タスク**: ライブラリのインストール、環境マネージャ（mise 等）の設定、フレームワークの初期化、CI の設定など、開発環境のセットアップが主目的の場合 → `setup` エージェントを使用
- **コード実装タスク**: 機能追加、バグ修正、リファクタリングなど、アプリケーションコードの変更が主目的の場合 → `implementer` エージェントを使用

判断に迷う場合（環境構築とコード実装の両方を含む等）は、主目的に応じて選択してください。

#### setup エージェントを使う場合

**Agent ツールを `subagent_type: "setup"` で起動**し、実装計画に基づいて環境を構築させてください。
**ワークツリー `REPOSITORY-impl-ISSUE_NO` 内で作業すること。**

プロンプトには以下を含めてください:
- Issue コメントから取得した実装計画の全文
- 計画に忠実に環境を構築すること
- ワークツリー内で作業すること
- `ISSUE_URL` と見出し `## 実装内容` を渡し、結果を **setup エージェント自身が** `gh issue comment` で記録すること

#### implementer エージェントを使う場合

**Agent ツールを `subagent_type: "implementer"` で起動**し、実装計画に基づいてコードを実装させてください。
**ワークツリー `REPOSITORY-impl-ISSUE_NO` 内で作業すること。**

プロンプトには以下を含めてください:
- Issue コメントから取得した実装計画の全文
- 計画に忠実に実装すること
- ワークツリー内で作業すること
- 計画の「検証必須事項」のうち implementer 担当項目は、すべて検証を実施し `### 検証実施結果` セクションに証拠とともに報告すること（証拠ファイルは `.tmp/spira-evidence/` 配下に保存）
- PR 提出前に **自己レビュー** を実施し、`### 自己レビュー結果` セクションに記載すること
- `ISSUE_URL` と見出し `## 実装内容` を渡し、結果を **implementer エージェント自身が** `gh issue comment` で記録すること

#### 共通: 結果の確認

エージェントの結果を受け取ったら:
1. 変更内容のサマリをユーザーに提示する
2. 「設計判断が必要な論点」が「なし」でなければ Phase 2.5 に進む。「なし」であれば Phase 3 に進む

### Phase 2.5: 設計判断（PO エージェント・実装フェーズ）

implementer が挙げた設計判断の論点を **すべて 1 つのプロンプトに集約** し、**Agent ツールを `subagent_type: "po"` で 1 回だけ起動**して判断を得てください。

プロンプトには以下を含めてください:
- 全論点の内容を番号付きで列挙
- 各論点の選択肢と暫定実装
- Issue の内容（背景として）
- `ISSUE_URL` と見出し `## 設計判断` を渡し、判断全文を **PO エージェント自身が** `gh issue comment` で記録すること

PO エージェントの判断を受け取ったら:
1. 判断結果のサマリをユーザーに提示する
2. 暫定実装と判断が異なる論点があれば、Phase 2 で使用したのと同じエージェントを再度起動し、判断結果に基づいて修正させる。見出し `## 設計判断に基づく修正` で再記録させる

### Phase 3: PR 作成

実装完了後、ワークツリーのブランチから PR を作成してください。

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
   EOF
   )"
   ```
4. PR の URL を Issue にコメントとして記録する（見出し: `## PR 作成`）。これはオーケストレータが直接記録する。
   ```
   gh issue comment ISSUE_URL --body "$(cat <<'EOF'
   ## PR 作成

   PR URL: <作成された PR の URL>
   EOF
   )"
   ```

### Phase 4: QA・CI 修正ループ

以下の手順を **最大 2 回** 繰り返してください。

#### 4a. CI チェック監視（qa エージェント）

**Agent ツールを `subagent_type: "qa"` で起動**し、CI チェックの監視を行わせてください。

プロンプトには以下を含めてください:
- PR 番号
- CI チェックが全て通過したら squash マージすること
- `ISSUE_URL` と見出し（CI 通過時は `## QA 結果`、CI 失敗時は `## CI 失敗 (N回目)` ※N はループ回数）を渡し、結果を **qa エージェント自身が** `gh issue comment` で記録すること

#### 4b. 結果に応じた分岐

**CI 通過・マージ成功の場合**: Phase 5（完了報告）に進む。

**CI 失敗の場合**:
1. **Phase 2 で使用したのと同じエージェント（`setup` または `implementer`）を起動**し、ワークツリー `REPOSITORY-impl-ISSUE_NO` 内で CI 失敗の原因を修正させる
   - プロンプトには失敗したチェック名・エラー内容を含めること
   - `ISSUE_URL` と見出し `## CI 修正 (N回目)` を渡し、修正内容を **エージェント自身が** `gh issue comment` で記録させること
2. ワークツリー内で変更をコミット・プッシュする
   ```
   git add -A
   git commit -m "Fix CI failure for #ISSUE_NO (attempt N)"
   git push
   ```
3. 4a に戻り、再度 qa エージェントで CI チェックを監視する

**2 回修正しても CI が通らない場合**: 修正を打ち切り、以下を実行して終了する。

1. 元 Issue に打ち切りコメントを記録（オーケストレータが直接記録）
   ```
   gh issue comment ISSUE_URL --body "$(cat <<'EOF'
   ## CI 修正打ち切り

   2 回の修正試行で CI を通すことができませんでした。フォローアップ Issue を起票しました: <新規 Issue URL>
   EOF
   )"
   ```
2. `escalated` ラベル付きのフォローアップ Issue を起票する。
   ```
   gh issue create --repo OWNER/REPOSITORY \
     --title "[escalated] CI failure follow-up for #ISSUE_NO" \
     --label escalated \
     --body "$(cat <<'EOF'
   元 Issue: ISSUE_URL
   元 PR: <PR URL>

   ## 試行サマリ
   （試行 1 と 2 の修正内容と失敗内容を要約）

   ## 最終失敗内容
   （最後の CI 失敗のエラー内容）
   EOF
   )"
   ```
3. ユーザーに状況を報告して終了する（Phase 5 は実行しない）。元 Issue はオープンのままとする。

### Phase 5: 完了報告

以下を Issue にコメントとして記録してください（見出し: `## 完了報告`）。これはオーケストレータが直接記録する。
- 変更したファイルの一覧
- 変更内容の概要
- PR URL とマージ結果

最後に、ユーザーへの最終報告として Issue URL と PR URL を含む簡潔なサマリーを出力してください。
