# テンプレート: 人の手が必要なときの案内

- **書き手**: autopilot スキル（キックオフで前提条件が欠けたとき）、orchestrator エージェント（ループを `halt` するとき）
- 何が足りないか → どうやって埋めるか → 埋めた後に何を実行するか、の順に書く
- シークレットの値・値の例は書かない
- 該当しない節は出力しない

## 置き場所の提案

キックオフで必要なシークレットが 1 件以上あり、Infisical が使えなかったときに出す。欠けていた項目だけを表に残す。
提案して返答を待つ（この案内で終了しない）。

```markdown
## 🔑 シークレットの置き場所を決めてください

必要なシークレットが 3 件ありますが、Infisical が使えません。

| 項目 | 状態 |
|:--|:--|
| Infisical CLI | ❌ 見つかりません |
| プロジェクト紐付け（`.infisical.json`） | ❌ ありません |
| デフォルトブランチへのコミット（`.infisical.json`） | ❌ コミットされていません |
| ログイン・環境 `<ENV>` へのアクセス | ❌ 失敗しました |

| 案 | 内容 | 向いている場面 |
|:--|:--|:--|
| A. Infisical をセットアップする | 手順を案内して終了します。済んだら再実行してください | チームで値を共有する・本番と同じ管理にしたい |
| B. `.env` で代替する | ルートの `.env`（git に無視されたファイル）にプレースホルダを作って続けます | 手元だけで回す・すぐに始めたい |

A / B のどちらにしますか？ B で `.env` 以外のファイル（例: `.env.local`）を使う場合はファイル名も教えてください。
```

## `.env` の無視設定

```markdown
## ⛔ `<ENV_FILE>` が git に無視されていません

シークレットがコミットに混ざらないよう、`.gitignore` に `<ENV_FILE>` を追加してください。

終わったら、もう一度 `/spira:autopilot` を実行してください。
```

## Infisical セットアップ

欠けていた項目だけを表に残し、手順も該当するものだけを番号付きで出す。

```markdown
## ⛔ Infisical のセットアップが必要です

| 項目 | 状態 |
|:--|:--|
| Infisical CLI | ❌ 見つかりません |
| プロジェクト紐付け（`.infisical.json`） | ❌ ありません |
| デフォルトブランチへのコミット（`.infisical.json`） | ❌ コミットされていません |
| ログイン・環境 `<ENV>` へのアクセス | ❌ 失敗しました |

### 手順

1. CLI を入れる: `mise use -g infisical`（または https://infisical.com/docs/cli/overview ）
2. ログインする: `infisical login`
3. リポジトリのルートでプロジェクトを紐付ける: `infisical init`
4. `.infisical.json` をコミットしてデフォルトブランチへ入れる（中身はプロジェクトの紐付けだけで、シークレットは含まれない）。
   `.gitignore` で無視していれば外してから `git add .infisical.json` する
5. 環境 `<ENV>` が見えることを確認する: `infisical secrets --env <ENV> --silent >/dev/null && echo OK`

終わったら、もう一度 `/spira:autopilot` を実行してください。
```

## 環境変数の設定

置き場所が `infisical` のときの版。`dotenv` のときは下の「`.env` の版」を使う。

```markdown
## ⛔ 人の手で設定する値があります

Infisical（環境 `<ENV>`）にプレースホルダで作成済みです。値を入れてください。

| 変数 | 用途 | 値の入手先 | 必要とする Issue |
|:--|:--|:--|:--|
| `STRIPE_API_KEY` | 決済 API の呼び出し | Stripe ダッシュボード > 開発者 > API キー | #21 |

### 手順

1. 値を入れる（どちらか）
   - Web: Infisical のプロジェクト > 環境 `<ENV>` で各変数の値を編集する
   - CLI: `infisical secrets set STRIPE_API_KEY=<値> --env <ENV>`
2. 入ったことを確認する（値は表示されません）:
   `infisical secrets --env <ENV> --silent -o json | jq -r '.[] | select((.value // .secretValue) == "__SPIRA_PLACEHOLDER__") | (.key // .secretKey)'`
   何も出なければ OK

終わったら、<再開方法>
```

### `.env` の版

```markdown
## ⛔ 人の手で設定する値があります

`<ENV_FILE>` にプレースホルダ（`__SPIRA_PLACEHOLDER__`）で作成済みです。値を入れてください。

| 変数 | 用途 | 値の入手先 | 必要とする Issue |
|:--|:--|:--|:--|
| `STRIPE_API_KEY` | 決済 API の呼び出し | Stripe ダッシュボード > 開発者 > API キー | #21 |

### 手順

1. `<ENV_FILE>` を開き、各変数の `__SPIRA_PLACEHOLDER__` を値に置き換える
2. 入ったことを確認する（値は表示されません）:
   `grep -oE '^(export )?[A-Za-z_][A-Za-z0-9_]*=__SPIRA_PLACEHOLDER__$' <ENV_FILE> | cut -d= -f1`
   何も出なければ OK

終わったら、<再開方法>
```

## エスカレーション

orchestrator だけが使う。自走を続けられないと判定した escalated Issue ごとに書く。
`<ROOT>` はルート、SID は `state.md` の結果表で元 Issue の行の `SID`。

```markdown
## ⛔ 自走を続けられないエスカレーションがあります

| Issue | 続けられない理由 | 元 Issue のライン（SID） |
|:--|:--|:--|
| #34 fix(api): #21 の CI 失敗を解消する | デフォルトブランチの依存解決が壊れ、どのラインも CI が通らない | #21 `3f2c9a1e-7b4d-4e8a-9c0f-1a2b3c4d5e6f` |

### 手順

1. Issue の内容を確認し、原因を直す（直した PR をマージする）。
   元 Issue のラインの会話は、autopilot と同じ `CLAUDE_CONFIG_DIR` で開ける（worktree の再作成は不要）:
   `cd <ROOT> && claude --resume <SID>`
2. Issue をクローズする

終わったら、<再開方法>
```

`<再開方法>` は書き手ごとに次の文言にする。

| 書き手 | 再開方法 |
|:--|:--|
| autopilot | もう一度 `/spira:autopilot` を実行してください。 |
| orchestrator | `/clear` してから、キックオフで案内したプロンプトをもう一度実行してください（続きから再開します）。 |
