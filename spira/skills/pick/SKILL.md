---
name: pick
description: "対応すべき GitHub Issue を 1 件抽出する。escalated ラベル付きを優先する。pick, 次のIssue, 次のタスク"
user-invocable: true
allowed-tools: Bash
---

現在のリポジトリで、次に対応すべき Open な GitHub Issue を 1 件抽出してください。

## Philosophy

- **副作用なし**: 抽出のみ。Issue やラベルへの書き込みは行わない
- **シンプルな優先度**: escalated を最優先、それ以外は同列で番号が若いものを選ぶ

## Role

あなたは**次に対応すべき Issue を 1 件選び出すピッカー**です。

## 禁則事項

- Issue・ラベル・コメントへの書き込みは禁止
- 抽出条件を独自に拡張することは禁止（assignee 等の追加フィルタを掛けない）

## 入力の解析

引数は受け取りません。実行されたディレクトリの Git リポジトリから `OWNER/REPOSITORY` を取得します。

```
gh repo view --json nameWithOwner --jq .nameWithOwner
```

取得した値を `REPO` に格納します（例: `octocat/hello-world`）。

## 共通オペレーション

### Issue 抽出コマンド

`gh search issues` を使い、以下の条件で 1 件取得します。

| 優先度 | フィルタ | ソート |
|---|---|---|
| 1 | `is:issue is:open repo:REPO label:escalated` | `sort:created-asc`（番号が若い順） |
| 2 | `is:issue is:open repo:REPO` | `sort:created-asc`（番号が若い順） |

JSON で取得し、`number`・`title`・`url` を抽出します。

```
gh search issues --limit 1 --json number,title,url \
  -- "is:issue is:open repo:REPO label:escalated sort:created-asc"
```

## 手順

1. **リポジトリ識別**: `gh repo view --json nameWithOwner --jq .nameWithOwner` で `REPO` を取得する
2. **escalated 優先抽出**: 以下を実行し、結果が空でなければ「優先度: escalated」として手順 4 に進む
   ```
   gh search issues --limit 1 --json number,title,url \
     -- "is:issue is:open repo:REPO label:escalated sort:created-asc"
   ```
3. **通常抽出**: escalated が 0 件の場合、以下を実行する
   ```
   gh search issues --limit 1 --json number,title,url \
     -- "is:issue is:open repo:REPO sort:created-asc"
   ```
   結果が空でなければ「優先度: normal」として手順 4 に進む。
   結果も空であれば「対応すべき Issue がありません」とユーザーに伝えて終了する。
4. **出力**: 以下のフォーマットで 3 行を出力する。`URL` を最後に置き、後続コマンドへチェインしやすくする。

   ```
   優先度: escalated
   タイトル: <title>
   URL: <url>
   ```

   または

   ```
   優先度: normal
   タイトル: <title>
   URL: <url>
   ```
