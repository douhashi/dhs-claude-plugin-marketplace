# テンプレート: 人手対応待ち

- **書き手**: setup エージェント（環境構築で人の手による設定が必要な値に出会ったとき） / autopilot のライン（`spira:do` の実行中に人の手による設定が必要と判明したとき）
- **共通ルール**: [_rules.md](./_rules.md)
- Infisical の有無で版を選ぶ。どちらの版も 300 字
- 同じ Issue に `## 人手対応待ち` が既にあれば、重ねてコメントしない

## プレースホルダの作成（Infisical がある場合）

変数ごとに存在を確認し、無ければプレースホルダで作る。既存の値は上書きしない。
`ENV` は書き手が解決した Infisical の環境名に置き換える。

```bash
infisical secrets --env ENV --silent -o json \
  | jq -e --arg n NAME 'any(.[]; (.key // .secretKey) == $n)' >/dev/null \
  || infisical secrets set NAME=__SPIRA_PLACEHOLDER__ --env ENV --silent >/dev/null
```

## Infisical がある場合（`## 人手対応待ち`・300 字）

```markdown
## 人手対応待ち

Infisical（環境 `<ENV>`）にプレースホルダを作成しました。値が入るまで本 Issue の作業を止めます。

| 変数 | 用途 |
|:--|:--|
| `NAME` | （何に使うか 1 文） |
```

- 値の入手手順は書かない（ループの停止時にユーザーへ直接案内する）

## Infisical が無い場合（`## 人手対応待ち`・300 字）

```markdown
## 人手対応待ち

次の変数に値が入るまで本 Issue の作業を止めます。

| ファイル | 変数 | 用途 |
|:--|:--|:--|
| `path/to/file` | `NAME` | （何に使うか 1 文） |

1. （人がやる手順を 1 行 1 手順・最大 3 行。最後の手順は `mise run setup` の再実行）
```

- 「ファイル」には値を書き込む先（例: `.env`）を書き、変数名だけを足した雛形（例: `.env.example`）があれば手順で触れる

## 注意

- シークレットの値・値の例は書かない（どちらの版も）
