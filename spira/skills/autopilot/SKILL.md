---
name: autopilot
description: "開発を自走で回す準備をする。前提条件（Infisical・環境変数）を検査し、/clear 後も継続できるループ開発のコンテキストを .tmp に書き出す。autopilot, 自走, ループ開発, 自動で回して"
argument-hint: "[--env <Infisical 環境名>]"
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Grep, Glob, Write, Bash
---

現在のリポジトリで、開発を自走で回すための準備（キックオフ）を行ってください。
このスキル自身は開発を行いません。ループは `/clear` 後に `spira:orchestrator` エージェントが回します。

## Philosophy

- **人の準備物を先に潰す**: 走り出してから止まるより、走る前に止まるほうが安い
- **セッションに記憶を持たせない**: ループに必要な情報はすべて `.tmp/spira-autopilot/` に書き出す
- **開発は既存スキルに任せる**: Issue の選択は `spira:pick`、開発は `spira:do` が担う。autopilot は段取りだけを行う
- **着手順を先に決めておく**: ロードマップに無い Issue は着手順が定まらない。走り出す前にロードマップへ載せる

## Role

あなたは**自走開発の段取りを整えるキックオフ担当**です。

## 禁則事項

- Issue の選択・計画・実装・PR 作成を自分で行うことは禁止
- シークレットの値を出力・ファイル・Issue に書くことは禁止（扱うのは変数名とプレースホルダか否かだけ）
- 既に値が入っている Infisical のシークレットを上書きすることは禁止
- 前提条件が欠けたまま `.tmp/spira-autopilot/context.md` を書き出すことは禁止
- ループのプロンプトを案内する前に、自分でループを開始することは禁止
- ユーザーが載せると決めていない Issue をロードマップに追加することは禁止
- 未記載 Issue の一覧を出す前、またはユーザーの返答を待たずにロードマップの PR を作成・マージすることは禁止
- ロードマップの未完了行どうしを並べ替えること、既存行の文言を書き換えることは禁止（行の追加だけを行う）

## 入力の解析

| 引数 | 既定値 | 用途 |
|:--|:--|:--|
| `--env <名前>` | `.infisical.json` の `defaultEnvironment`、無ければ `dev` | シークレットを検査・作成する Infisical 環境 |

以下の変数を確定させる。

```
ROOT=$(git rev-parse --show-toplevel)
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
DIR="$ROOT/.tmp/spira-autopilot"
```

## 共通オペレーション

### プレースホルダ

人が値を入れるべきシークレットは、値 `__SPIRA_PLACEHOLDER__` で作成する。
値がこの文字列のシークレットは **未設定** とみなす。

### シークレット名の一覧取得

値を出力しないよう、必ず `jq` で名前とプレースホルダ判定だけを取り出す。

```
infisical secrets --env ENV --silent -o json \
  | jq -r '.[] | [(.key // .secretKey), ((.value // .secretValue) == "__SPIRA_PLACEHOLDER__")] | @tsv'
```

### 案内の出力

前提条件が欠けていた場合の案内は [blocker-guide.md](templates/blocker-guide.md) に従う。

## 手順

### Phase 1: 最新化

1. `git status` を確認する。未コミット変更があればユーザーに伝えて終了する（勝手に stash・破棄しない）
2. `git switch BRANCH && git pull` で最新化する

### Phase 2: ロードマップと Open Issue の確認

1. `find docs -name roadmap.md -type f 2>/dev/null | head -1` でロードマップを探し、あれば Read する
2. Open Issue を取得する

   ```
   gh issue list --repo REPO --state open --limit 200 --json number,title,labels,body,url
   ```
3. 次の 3 つを把握する（Phase 4 の整理と Phase 6 の着手見込み表に使う）
   - `spira:pick` の優先順（ロードマップの未完了行 → 番号が若い順）で先頭から並べた Issue。`escalated` Issue は自走の対象外として分けておく
   - 各 Issue の依存（ロードマップの `[dep <ID>]`、本文の `depends on #N` / `blocked by #N` / `#N の完了後`）
   - `escalated` 以外の Open Issue が 0 件なら「対応すべき Issue がありません」と伝えて終了する

### Phase 3: 前提条件の検査

上から順に検査し、**欠けた時点で案内を出して終了する**（以降の検査・書き出しは行わない）。

#### 3-1. ツール

| 検査 | コマンド | 欠けていた場合 |
|:--|:--|:--|
| gh 認証 | `gh auth status` | `gh auth login` を案内して終了 |
| claude CLI | `command -v claude` | インストールを案内して終了 |
| origin | `git remote get-url origin` | リモート設定を案内して終了 |

#### 3-2. Infisical

| 検査 | コマンド |
|:--|:--|
| CLI | `command -v infisical` |
| プロジェクト紐付け | `test -f "$ROOT/.infisical.json"` |
| ログイン・環境 | `infisical secrets --env ENV --silent -o json >/dev/null` |

1 つでも失敗したら、[blocker-guide.md](templates/blocker-guide.md) の「Infisical セットアップ」節に沿って
セットアップ手順を案内し、**終了する**。

#### 3-3. 人の手による準備物

次の情報源から、開発に必要な環境変数・API キーなどの名前を集める。

- `.env.example` / `.env.sample` / `.env.template` / `.env.*.example`
- `mise.toml` の `[env]`、`docker-compose*.yml` の `environment`
- `README.md` と `docs/` 配下のセットアップ手順
- Phase 2 で着手見込みとした Issue の本文（`UPPER_SNAKE_CASE` の変数名、「API キー」「トークン」「認証情報」の記述）

集めた名前を「シークレット名の一覧取得」の結果と突き合わせる。

- **無い名前**: プレースホルダで作成する

  ```
  infisical secrets set NAME=__SPIRA_PLACEHOLDER__ --env ENV --silent >/dev/null
  ```
- **プレースホルダのままの名前**: 未設定として扱う（作り直さない）

未設定が 1 件でもあれば、[blocker-guide.md](templates/blocker-guide.md) の「環境変数の設定」節に沿って
埋める手順を案内し、**終了する**。コードが既に参照しているのに情報源に書かれていない変数に気付いた場合も同様に扱う。

### Phase 4: ロードマップの整理

ロードマップに載っていない Issue が自走の対象になると、着手順が番号順に落ちてしまう。走り出す前に載せる。

1. Phase 2 で見つけたロードマップが無ければ、この Phase を飛ばす（Phase 6 の報告に「ロードマップが無いため番号順に進む」と書く）
2. **未記載の Issue を洗い出す**: Phase 2 の Open Issue（`escalated` を除く）のうち、ロードマップに `→ #<番号>` の行が無いもの。無ければこの Phase を飛ばす
3. **一覧を出して一緒に決める**: [roadmap-triage.md](templates/roadmap-triage.md) を Read し、
   未記載の Issue を一覧で提示して、どれをロードマップに載せるかをユーザーと決める。
   載せるものは追加位置も併せて決める。**決めるのはユーザー**であり、スキルは案を出して質問に答える
4. **PR を作ってマージする**: `載せる` と決まった Issue を、`${CLAUDE_PLUGIN_ROOT}/templates/roadmap-pr.md` の
   「キックオフ整理」節と「PR の出し方」に従って 1 本の PR にまとめる
   - `載せる` が 0 件なら PR は作らない
   - CI 失敗・マージ不可のときは、PR を開いたまま残し、その旨を Phase 6 の報告に書いて先に進む
5. **対象外を記録する**: `載せない` と決まった Issue は、今回のループの対象外として Phase 5 で `state.md` に理由とともに書く

### Phase 5: コンテキストの書き出し

1. `mkdir -p "$DIR/lines/archive"` を実行する
2. [context.md](templates/context.md) を Read し、`{{...}}` をすべて埋めて `$DIR/context.md` に書き出す
   - `{{PLUGIN_ROOT}}` には `${CLAUDE_PLUGIN_ROOT}` の展開後の絶対パスを入れる
   - `{{CREATED_AT}}` には `date -u +%Y-%m-%dT%H:%M:%SZ` の値を入れる（GitHub の `createdAt` と比較するため UTC）
3. [state.md](templates/state.md) を Read し、`{{...}}` を埋めて `$DIR/state.md` に書き出す
   - `{{TARGET_ROWS}}` には Phase 4 の整理を反映した着手順（escalated と対象外を除く）を、同じ順で 1 行ずつ入れる（状態は `⏳ 待機`、依存が未完了なら `⏸ 依存待ち` とし、メモに依存先を書く）
   - `{{EXCLUDED_ROWS}}` には Phase 4 で `載せない` と決まった Issue を、理由とともに 1 行ずつ入れる（0 件なら空のままにする）
   （既に `$DIR/state.md` がある場合は、前回のループの記録として `$DIR/lines/archive/state-<日時>.md` に退避してから書き出す）
4. `.tmp/` が `.gitignore` 等で無視されているか `git check-ignore -q .tmp/spira-autopilot/context.md` で確認し、
   無視されていなければその旨を報告に含める（`.gitignore` は編集しない）

### Phase 6: 開始方法の案内

[kickoff-report.md](templates/kickoff-report.md) に沿って、前提条件の検査結果・着手見込み・
`/clear` 後に実行するプロンプトを提示して終了する。
