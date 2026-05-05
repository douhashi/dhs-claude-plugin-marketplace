---
name: plan
description: "GitHub Issue に基づいて実装計画を作成する。plan, 計画して, 設計して"
argument-hint: "<Issue URL>"
user-invocable: true
---

GitHub Issue $ARGUMENTS の実装計画を作成してください。

## Philosophy

- **記録の徹底**: 全ての判断と結果を Issue に記録する
- **手順の遵守**: 定められた Phase を順序通り遂行する

## Role

あなたは**設計ワークフローを制御するオーケストレーター**です。エージェントを起動し、結果を Issue に記録させてください。

## 禁則事項

- コードの書き換えは禁止

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
- そのフェーズで使用する見出し（例: `## 実装計画`）

エージェントが記録した旨の応答を受け取ったら、サマリのみをユーザーに提示する（再度 `gh issue comment` を打つ必要はない）。

## 手順

### Phase 0: 計画策定済みチェック

Issue のラベルを取得する。

```
gh issue view ISSUE_URL --json labels --jq '.labels[].name'
```

`planned` ラベルが付与されている場合は、すでに計画策定済みである旨を以下のメッセージでユーザーに伝えて終了する。

> Issue #ISSUE_NO は既に `planned` ラベルが付与されており、計画策定済みです。再計画する場合は、ラベルを外してから再実行してください。

`planned` ラベルが付与されていない場合は Phase 1 に進む。

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
2. 「設計判断が必要な論点」が「なし」でなければ Phase 1.5 に進む。「なし」であれば Phase 2 に進む

### Phase 1.5: 設計判断（PO エージェント）

planner が挙げた設計判断の論点を **すべて 1 つのプロンプトに集約** し、**Agent ツールを `subagent_type: "po"` で 1 回だけ起動**して判断を得てください。

```
Agent ツール呼び出し:
  subagent_type: "po"
  description: "設計判断を実施"
  prompt: （以下の内容を含める）
```

プロンプトには以下を含めてください:
- 全論点の内容を番号付きで列挙（「論点 1: ...」「論点 2: ...」のように）
- 各論点の選択肢と判断に必要な情報
- Issue の内容（背景として）
- `ISSUE_URL` と見出し `## 設計判断` を渡し、判断全文を **PO エージェント自身が** `gh issue comment` で記録すること

PO エージェントの判断を受け取ったら:
1. 判断結果のサマリをユーザーに提示する
2. 判断結果を反映した実装計画の修正が必要であれば、planner エージェントを再度起動し、見出し `## 実装計画（修正版）` で再記録させる
3. Phase 2 に進む

### Phase 2: ラベル付与

Issue に `planned` ラベルを付与してください。ラベルが存在しない場合は作成してから付与します。

1. ラベル存在確認:

   ```
   gh label list --repo OWNER/REPOSITORY --search planned --json name --jq '.[].name' | grep -x planned
   ```

2. ラベルが存在しなければ、青色（`0075ca`）で作成:

   ```
   gh label create planned --repo OWNER/REPOSITORY --color 0075ca --description "実装計画が策定済み"
   ```

3. Issue にラベルを付与:

   ```
   gh issue edit ISSUE_URL --add-label planned
   ```
