---
name: pick
description: "対応すべき GitHub Issue を 1 件抽出する。escalated ラベル付きを優先する。pick, 次のIssue, 次のタスク"
argument-hint: "[--exclude <Issue 番号,...>]"
user-invocable: true
allowed-tools: Bash
---

現在のリポジトリで、次に対応すべき Open な GitHub Issue を 1 件抽出してください。

## Philosophy

- **副作用なし**: 抽出のみ。Issue やラベルへの書き込みは行わない
- **着手順はプロジェクトが決める**: ロードマップがあればその並びに従い、無ければ番号が若いものを選ぶ
- **例外は escalated だけ**: 差し戻された Issue は着手順より先に扱う

## Role

あなたは**次に対応すべき Issue を 1 件選び出すピッカー**です。

## 禁則事項

- Issue・ラベル・コメントへの書き込みは禁止
- 抽出条件を独自に拡張することは禁止（assignee 等の追加フィルタを掛けない。`--exclude` 以外で候補を外さない）

## 入力の解析

実行されたディレクトリの Git リポジトリから `OWNER/REPOSITORY` を取得します。

```
gh repo view --json nameWithOwner --jq .nameWithOwner
```

取得した値を `REPO` に格納します（例: `octocat/hello-world`）。

| 引数 | 既定値 | 用途 |
|:--|:--|:--|
| `--exclude <番号,...>` | なし | 候補から外す Issue 番号（カンマ区切り）。`spira:orchestrator` が走行中の Issue を外すために使う |

`--exclude` の番号を `EXCLUDE` に JSON 配列で格納します（例: `[21,24]`、指定なしは `[]`）。
全優先度で `EXCLUDE` に含まれる Issue は無いものとして扱います。

## 共通オペレーション

### Issue 抽出コマンド

`gh search issues` を使い、以下の条件で取得します。JSON で取得し、`EXCLUDE` に含まれない最初の 1 件の `number`・`title`・`url` を抽出します。

| 優先度 | フィルタ | ソート |
|---|---|---|
| 1 | `is:issue is:open repo:REPO label:escalated` | `sort:created-asc`（番号が若い順） |
| 2 | ロードマップの並び（下記） | ロードマップの記載順 |
| 3 | `is:issue is:open repo:REPO` | `sort:created-asc`（番号が若い順） |

```
gh search issues --limit 100 --json number,title,url \
  --jq '[.[] | select(.number as $n | EXCLUDE | index($n) | not)] | first // empty' \
  -- "is:issue is:open repo:REPO label:escalated sort:created-asc"
```

### ロードマップの探索

プロジェクトが着手順を持つ場合、それに従います。`docs/` 配下から `roadmap.md` を 1 件探します。

```
find docs -name roadmap.md -type f 2>/dev/null | head -1
```

見つからなければこの経路は使わず、番号が若い順にフォールバックします。

### ロードマップからの Issue 番号の取り出し

ロードマップの項目行は `- [<状態>] **<ID>** <what>。 → #<課題番号>` の形です。
**未完了（`- [ ]` と `- [~]`）の行だけ**を上から順に読み、`→ #<番号>` の番号を取り出します。

- `- [x]` の行は完了済みなので読み飛ばす
- `→ #<番号>` を持たない行（未起票）は読み飛ばす
- 取り出した番号のうち、`EXCLUDE` に含まれず、**Open な Issue として実在する最初の 1 件**を選ぶ

`[dep <ID>]` は解釈しません。ロードマップは着手順に並んでいるため、上から見れば順序は満たされます。

## 手順

1. **リポジトリ識別**: `gh repo view --json nameWithOwner --jq .nameWithOwner` で `REPO` を取得する
2. **escalated 優先抽出**: 以下を実行し、結果が空でなければ「優先度: escalated」として手順 4 に進む
   ```
   gh search issues --limit 100 --json number,title,url \
     --jq '[.[] | select(.number as $n | EXCLUDE | index($n) | not)] | first // empty' \
     -- "is:issue is:open repo:REPO label:escalated sort:created-asc"
   ```
3. **ロードマップ抽出**: escalated が 0 件の場合、`docs/` 配下の `roadmap.md` を探す。
   見つかった場合、未完了行の `→ #<番号>` を上から順に見て、Open な Issue として実在する
   最初の 1 件を取る。
   ```
   gh issue view <番号> --json number,title,url,state
   ```
   `state` が `OPEN` のものが見つかれば「優先度: roadmap」として手順 5 に進む。
   ロードマップが無い場合、または未完了行に Open な Issue が 1 件も無い場合は手順 4 に進む。
4. **通常抽出**: 以下を実行する
   ```
   gh search issues --limit 100 --json number,title,url \
     --jq '[.[] | select(.number as $n | EXCLUDE | index($n) | not)] | first // empty' \
     -- "is:issue is:open repo:REPO sort:created-asc"
   ```
   結果が空でなければ「優先度: normal」として手順 5 に進む。
   結果も空であれば「対応すべき Issue がありません」とユーザーに伝えて終了する。
5. **出力**: 以下のフォーマットで 3 行を出力する。`URL` を最後に置き、後続コマンドへチェインしやすくする。
   `優先度` は `escalated` / `roadmap` / `normal` のいずれかとする。

   ```
   優先度: roadmap
   タイトル: <title>
   URL: <url>
   ```
