# テンプレート: 人の手が必要なときの案内

- **書き手**: autopilot スキル（キックオフで前提条件が欠けたとき）、orchestrator エージェント（ループを `halt` するとき）
- 何が足りないか → どうやって埋めるか → 埋めた後に何を実行するか、の順に書く
- シークレットの値・値の例は書かない
- 該当しない節は出力しない

## Infisical セットアップ

欠けていた項目だけを表に残し、手順も該当するものだけを番号付きで出す。

```markdown
## ⛔ Infisical のセットアップが必要です

| 項目 | 状態 |
|:--|:--|
| Infisical CLI | ❌ 見つかりません |
| プロジェクト紐付け（`.infisical.json`） | ❌ ありません |
| ログイン・環境 `<ENV>` へのアクセス | ❌ 失敗しました |

### 手順

1. CLI を入れる: `mise use -g infisical`（または https://infisical.com/docs/cli/overview ）
2. ログインする: `infisical login`
3. リポジトリのルートでプロジェクトを紐付ける: `infisical init`
4. 環境 `<ENV>` が見えることを確認する: `infisical secrets --env <ENV> --silent >/dev/null && echo OK`

終わったら、もう一度 `/spira:autopilot` を実行してください。
```

## 環境変数の設定

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

## エスカレーション

orchestrator だけが使う。自走を続けられないと判定した escalated Issue ごとに書く。

```markdown
## ⛔ 自走を続けられないエスカレーションがあります

| Issue | 続けられない理由 |
|:--|:--|
| #34 fix(api): #21 の CI 失敗を解消する | デフォルトブランチの依存解決が壊れ、どのラインも CI が通らない |

### 手順

1. Issue の内容を確認し、原因を直す（直した PR をマージする）
2. Issue をクローズする

終わったら、<再開方法>
```

`<再開方法>` は書き手ごとに次の文言にする。

| 書き手 | 再開方法 |
|:--|:--|
| autopilot | もう一度 `/spira:autopilot` を実行してください。 |
| orchestrator | `/clear` してから、キックオフで案内したプロンプトをもう一度実行してください（続きから再開します）。 |
