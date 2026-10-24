# Spira

Claude Code プラグインとして、自律的な開発サイクル（計画 → 実装 → PR 作成 → CI 監視・マージ）を支援するツール群を提供します。

## 特徴

- **開発サイクル自動化**: GitHub Issue を入力に、計画・実装・PR 作成・CI 監視・マージまでを一貫して自動実行
- **エージェント分業**: planner / implementer / po / qa / setup / orchestrator の 6 エージェントが役割を分担
- **Issue 駆動**: 全プロセスの結果が GitHub Issue にコメントとして記録される
- **ブレインストーミング**: 論点を洗い出し、1 つずつ対話で決着させ、Issue 化とドキュメント更新まで繋ぐ対話型スキル
- **次タスク抽出**: `escalated` ラベルを優先しつつ、対応すべき Issue を 1 件選び出す
- **自走開発**: `spira:pick` → `spira:do` を最大 5 ライン（`--lines` で変更可）で並列に回し、人の手が必要になったら止まる

## セットアップ

### インストール

マーケットプレイス [dhs-claude-plugin-marketplace](https://github.com/douhashi/dhs-claude-plugin-marketplace)
経由で入れる。マーケットプレイスの登録は初回だけでよい。

Claude Code のセッション内から:

```
/plugin marketplace add douhashi/dhs-claude-plugin-marketplace
/plugin install spira@dhs-claude-plugin-marketplace
```

シェルから:

```bash
claude plugin marketplace add douhashi/dhs-claude-plugin-marketplace
claude plugin install spira@dhs-claude-plugin-marketplace
```

インストール後に Claude Code を再起動すると、`/spira:` がコマンド補完に並ぶ。

`.claude/settings.json` の `enabledPlugins` は、そのプラグインを**有効にするだけ**で、
インストールまではしない（Claude Code v2.1.195 以降）。上のコマンドは省略できない。

なお、このプラグインの開発中にローカルの作業ツリーを読み込ませる手順は
[開発](#開発) の節にある。利用者向けのインストールには使わない。

## 使い方

### `/spira:brainstorming <テーマ>`

与えられたテーマについて論点を洗い出し、1 つずつ対話で決着させていきます。

1. **最新化** — `main` に移動して `git pull`（未コミットの変更があれば `AskUserQuestion` で続けるか終えるかを聞く）
2. **情報収集** — 関連ドキュメント・コード・外部仕様を調べる（調査結果は列挙せず論点に落とす）
3. **質問** — 埋まらなかった不明点を `AskUserQuestion` でユーザーに聞く（最大 3 つ）
4. **論点の洗い出し** — 論点テーブルを出力（重要な順）。言葉にされていない前提も論点に起こし、順序と粒度を `AskUserQuestion` で確認する
5. **議論** — `議論中` の論点を 1 つだけ扱う。1 応答 600 字以内・質問は 1 つ。案には必ずユーザーが言っていない案を混ぜ、ユーザーの提案には弱点を示してから同意する。案の選択と結論の確認は `AskUserQuestion` で、掘り下げの質問は本文で聞く
6. **テーブル更新** — 結論を書き込み全体を再掲し、次の論点へ
7. **Issue 化** — 全論点決着後、`AskUserQuestion` で確認のうえ `spira:create-issue` を呼び出す（候補の提示と承認は create-issue 側で行う）
8. **ドキュメント更新** — 起票した Issue 番号を反映し、`AskUserQuestion` で確認のうえ `spira:update-doc` を呼び出しマージまで行う

論点の状態は `未着手` / `議論中` / `解決` / `保留` の 4 つ。`議論中` は常に 1 つだけ存在します。

Issue 化がドキュメント更新より先なのは、ロードマップなど Issue 番号を参照する記述があり、
起票しないと番号が確定しないためです。結論の提示時点では番号を `#?` と置き、Phase 8 で実際の番号に置き換えます。

```bash
/spira:brainstorming 通知機能の改善
```

出力の書式と分量は `skills/brainstorming/templates/` で定義しています。

| 出力 | テンプレート | 上限 |
|:--|:--|--:|
| 論点テーブル | `discussion-points.md` | — |
| 1 論点の提示・議論 | `dialogue.md` | 600 字／応答 |
| 議論の結論 | `summary.md` | 800 字 |

### `/spira:update-doc <更新対象または指示>`

ドキュメントを更新し、PR を作成してマージします。

1. **対象の特定** — 更新対象ファイルと反映内容を整理
2. **ブランチ作成** — `main` を最新化し `docs/<slug>` を切る
3. **更新** — 既存フォーマットに従って編集し、差分を提示して PR 作成の承認を得る
4. **PR 作成** — コミット・push・`gh pr create`
5. **CI 監視・マージ** — 全チェック通過後に squash マージ（失敗時はマージせず報告）

git リポジトリでない場合やリモート・`gh` 認証が無い場合は、ローカル編集までで終了します。

```bash
/spira:update-doc docs/conventions.md にブランチ命名規則を追記
```

### `/spira:create-issue [owner/repo]`

議論結果や指示に基づいて GitHub Issue を起票します。**承認前に起票しません。**
ロードマップには触れません。起票した Issue を着手順に組み込むには、区切りのよいところで `/spira:sync-roadmap` を実行します。

1. **内容の整理と選別** — 会話の文脈から関心事ごとに分割し、コードベースの状態が変わらない項目を外す
   - **既存の Open Issue との照合** — Open Issue を本文まで読み、依存（`#N`）・逆向きの依存・重複を洗い出す
2. **提示と承認** — 作成予定 Issue を一覧表で提示し、`AskUserQuestion` で承認を求める（`起票する` / `詳細を見る`。修正指示は `Other` に書く）
3. **本文の作成** — `templates/issue-body.md` に沿って本文を書き、`wc -m` で 1,500 字以内を確認
4. **起票** — 承認された表の全行を、表の順に `gh issue create` で作成。依存がある行は `--blocked-by` で GitHub の Blocked by を付ける
5. **報告** — 1 行 1 件で URL を提示（依存を付けた Issue は依存先を添える）

承認段階で提示するのは次の表だけです。本文の全文は、ユーザーが求めた Issue の分だけ提示します。

| # | タイトル | 目的 | 完了条件 | 依存 |
|:--|:--|:--|:--|:--|
| 1 | `feat(spira): 論点テーブルに状態列を追加する` | 議論の進捗が追えない | 状態 4 種が表で判別できる | — |
| 2 | `feat(spira): 論点の状態で表を絞り込む` | 未決着の論点を探しにくい | 状態を指定すると該当行だけ出る | 行 1 |

依存は、同じ表の行を `行 N`、既存の Open Issue を `#N` で書きます。既存の Open Issue はすべて照合します。
既存の Open Issue が新しい Issue を待つ（逆向きの依存）場合は表の下に挙げ、承認後にその Issue へ Blocked by を付けます。本文には書かず、起票後に GitHub の Blocked by として設定します。
autopilot・orchestrator・ロードマップの整合は、この Blocked by を依存として読みます。

タイトルは Conventional Commits スタイル（`<type>(<scope>): <説明>`）で書きます。
`type` は `feat` / `fix` / `refactor` / `docs` / `test` / `chore`、`scope` は対象が特定できる場合に付けます。

承認は表全体に対して行い、承認されたら全行を起票します。粒度・分割・統合などの調整が入った場合は、
一部だけ起票せずに表を作り直して再提示し、改めて承認を得ます。

起票するのは、完了したときにコードベースの状態が変わる Issue だけです。
「〜を考える」「〜を決める」「〜を検討する」のように人間の意思決定そのものが本体の項目は
Issue にせず、「先に決着が必要な論点」として表の下に挙げ、`/spira:brainstorming` を促します。
決めた結果をドキュメントに残す場合は、決着した後に `docs:` の Issue として起票します。

```bash
/spira:create-issue douhashi/dhs-claude-plugin-marketplace
```

### `/spira:sync-roadmap`

ロードマップ（`docs/` 配下の `roadmap.md`）を Issue の現状に合わせます。create-issue で細かく起票した後や、自走開発の前に使います。
**ユーザーが決めていない Issue をロードマップに載せません。**

1. **現状の確認** — ロードマップと全 Issue の状態を取得（ロードマップが無ければ終了）
2. **整合** — チェック状態・完了行の置き場所が Issue の状態とずれていれば、`templates/roadmap-pr.md` の「整合の規則」どおりに直す PR を作ってマージ
3. **未記載 Issue の整理** — ロードマップに載っていない Open Issue を、載せる／載せないの案と追加位置の案を添えて一覧で提示し、Issue ごとに `AskUserQuestion` で聞いて（1 回 4 件まで。位置の修正は `Other`）ユーザーと決める。載せると決まったものを PR にしてマージ
4. **報告** — 整合・整理の PR と、載せなかった Issue を提示

未完了行どうしの並べ替えや、既存行の文言の書き換えはしません。autopilot のキックオフからも呼ばれます。

```bash
/spira:sync-roadmap
```

### `/spira:request <フィードバック内容>`

フィードバックの内容を確認・調査し、必要な Issue を起票します。**調査せずに起票しません。**

1. **最新化** — `main` に移動して `git pull`
2. **内容の確認** — フィードバックを観点ごとに分け、種別（不具合・改善要望・質問・その他）を整理
3. **調査** — コード・ドキュメント・既存 Issue・ロードマップで裏を取り、観点ごとに対応（起票・既存 Issue・対応済み・仕様どおり・判断保留）を決める。`起票` の観点は画面の変更を伴うかも決める
4. **調査結果の提示** — 観点・調査結果・対応・画面の変更の表と根拠（`path:line`・Issue 番号）を提示
5. **モックアップ** — 画面の変更を伴う `起票` の観点があれば `spira:mockup` を呼び出し、アーティファクトでの提案 → 承認 → PR → マージまで行う
6. **起票** — `起票` の観点があれば `spira:create-issue` を呼び出し、承認 → 起票まで行う。モックアップを反映した観点は、Issue 本文からモックアップを参照させる

```bash
/spira:request brainstorming の論点テーブルの表が崩れる
```

### `/spira:architect [追加したい要素]`

同梱のアーキテクチャセット（`skills/architect/sets/`）を叩き台に、プロジェクトの構成と配布先を提案します。
**承認前に文書化・起票をしません。** 対象は新規と構成要素の追加だけで、置き換え（モノリスの分割・DB の乗り換え等）は案内して終了します。

1. **最新化** — `main` に移動して `git pull`（未コミットの変更があれば `AskUserQuestion` で続けるか終えるかを聞く）
2. **モードの判定** — 既存のアーキテクチャのドキュメントと既存コードから新規・追加を決める。追加では両者を正とする（追加する要素が分からなければ `AskUserQuestion` で聞く）
3. **コンセプトの確認** — 目的と機能を記述した文書が無ければ、先に文書にするよう案内して終了
4. **要件の推定** — 機能記述から要件項目を推定して根拠を引用し、推定できない点だけ `AskUserQuestion` で質問する（4 つ以上なら案内して終了）
5. **候補の選定** — セットと配布先の判定（`_deploy.md`）を読み、推奨スタック例を要件と照合する。複数セットにまたがるなら共通レイヤー（認証・DB・API 仕様）を 1 か所で決める
6. **調査** — 提案に載せる要素だけ、メンテ継続・後継の有無・現行メジャー版を出典 URL と確認日付きで確かめ、種類ごとに近年の代替を 1 回検索する（Cloudflare なら Workers 固有 API の現行仕様も）
7. **提案と承認** — 要件の照合・構成・調査結果・代替の比較を提示し、`AskUserQuestion` で承認を求める（`まとめる` / `見送る`。修正指示は `Other` に書く）
8. **文書化** — `spira:update-doc` で承認された構成をドキュメントとしてまとめ、マージまで行う（書き出し先はプロジェクトに任せる）
9. **起票** — `spira:create-issue` で構成の立ち上げ Issue（環境構築と要素ごとの最小の組み込み）を起票する。環境構築の受け入れ基準には `mise install` と `mise run setup` で環境が整うことを含める
10. **セットの更新候補の整理** — 調査で古いと分かったセットの記述をまとめる（セットは書き換えない）
11. **完了報告** — PR・Issue の URL とセットの更新候補を報告

```bash
/spira:architect
/spira:architect 長時間ジョブのワーカー
```

出力の書式は `skills/architect/templates/` で定義しています。

| 出力 | テンプレート |
|:--|:--|
| 構成の提案 | `proposal.md` |
| アーキテクチャのドキュメント | `architecture-doc.md` |
| アーキテクチャセット（同梱セットの書式） | `architecture-set.md` |

### `/spira:mockup [画面名または機能]`

デザインスキル（`ui-ux-pro-max:ui-ux-pro-max` / `design-system` / `ui-styling`）を使って画面ごとのデザインモックアップを作り、アーティファクトで提案します。
**承認前にモックアップ・ドキュメントを書き換えません。** アプリケーションのコードには触れません。
`spira:request` からも、画面の変更を伴う観点を起票する前に呼ばれます。

1. **最新化** — `main` に移動して `git pull`（未コミットの変更があれば `AskUserQuestion` で続けるか終えるかを聞く）
2. **前提の確認** — コンセプトの文書・アーキテクチャのドキュメント・既存のデザインシステム（`docs/development/design-system.md`。無ければコードのトークン）・ビジュアライゼーション（`docs/development/visualization.md`）・既存のモックアップ（`docs/mockups/`）を読む。コンセプトの文書が無い・画面を持たないプロダクトなら案内して終了
3. **画面の特定** — 機能記述から描く画面・要素・状態を決め、読み取れない点（画面・対象デバイス）だけ `AskUserQuestion` で 1 回質問する
4. **デザインの検討** — デザインシステムの出どころを決める（ドキュメントに従う／コードのトークンから起こす／新規に作る）。デザインスキルでレイアウト・動きを決め、UX の指針で確かめる。動きのトークンは常にデザインシステムに含める
5. **方向性の選択** — 新規に作るときだけ、スタイル・配色・書体・動きの性格が異なる 3 案で主の画面を描き、比較ページ（アーティファクト）を示して `AskUserQuestion` で 1 案を選んでもらう
6. **モックアップの作成** — 画面ごとの HTML を書き、それを埋め込んだ提案ページ（画面・現状との比較・要素の根拠・デザインの判断・デザインシステム・動き・反映するファイル）を 1 つのアーティファクトとして公開する
7. **提案** — チャットには提案ページの URL と要約だけを示す
8. **承認** — `AskUserQuestion` で承認を求める（`反映する` / `見送る`）。修正指示（`Other` かページへのコメント）なら同じ URL に公開し直して再提示する
9. **反映** — `spira:update-doc` で `docs/mockups/` と、必要なら `docs/development/` のドキュメントを作成・更新し、マージまで行う
10. **完了報告** — PR URL・反映したファイル・提案ページの URL を報告

```bash
/spira:mockup ログイン画面
/spira:mockup
```

出力の書式は `skills/mockup/templates/` で定義しています。

| 出力 | テンプレート |
|:--|:--|
| 方向性の比較ページ・提案ページ（アーティファクト）とチャットでの提示 | `proposal.md` |
| モックアップの HTML・一覧（`docs/mockups/README.md`） | `mockup.md` |
| デザインシステムのドキュメント | `design-system.md` |
| ビジュアライゼーションのドキュメント | `visualization.md` |

### `/spira:explain <質問>`

自然言語の質問に対して、コードベースを調べ、図解を中心にした解説ページをアーティファクトで提示します。
情報源は現状のコード・テスト・ドキュメントと、実際に動かした結果だけです。**リポジトリのファイルは書き換えません。**

1. **依存スキルの確認** — `diagram-design` と `ui-ux-pro-max` が使えるかを確かめ、使えなければユーザースコープへの導入と再起動を `AskUserQuestion` で提案する（導入せずに続けると `artifact-diagramming` / `artifact-design` で代わりに描く）
2. **意図の読み取り** — 質問を「読み手が知りたいこと」の 1 文に言い直し、答えの形（流れ・構造・状態・データ・比較・原因）と主の図を決める。言い直しが割れるときだけ `AskUserQuestion` で確認する
3. **最新化** — `main` に移動して `git pull`（未コミットの変更があれば `AskUserQuestion` で続けるか終えるかを聞く）
4. **調査** — 入口のコードから答えに要る範囲をたどり、テストコードとドキュメントも読んで、事実と出典を事実メモに控える
5. **実地確認** — 読んでも確定しないことは、テストの実行や使い捨てのスクリプトで確かめる。確かめられないものは「未確認」とする
6. **絞り込み** — 結論 1〜2 文・図・要点 3 つまでに絞る（本文 400 字まで）
7. **作成と公開** — `diagram-design` と `ui-ux-pro-max` でページを作り、アーティファクトとして公開する
8. **見直し** — すべての記述に出典があるか・上限に収まっているかを確かめて直す
9. **提示** — チャットにはページの URL と結論だけを示す

```bash
/spira:explain autopilot のラインはどう起動される？
```

出力の書式は `skills/explain/templates/` で定義しています。

| 出力 | テンプレート |
|:--|:--|
| 解説ページ（アーティファクト）・情報量の上限・チャットでの提示 | `page.md` |
| 事実メモ（作業ファイル） | `facts.md` |
| 依存スキルの確認と導入の提案 | `dependencies.md` |

### `/spira:plan <Issue URL>`

指定した GitHub Issue について実装計画を作成します。`planned` ラベルが付与済みの場合はスキップします。

1. **計画策定済みチェック** — `planned` ラベルがあれば終了
2. **設計** (planner) — 要件分析・実装計画の作成
3. **設計判断** (po) — 論点があれば PO エージェントが集約判断（1 回呼び出し）
4. **ラベル付与** — `planned` ラベルを付与

```bash
/spira:plan https://github.com/owner/repo/issues/42
```

### `/spira:implement <Issue URL>`

`planned` 済みの Issue に対して実装サイクルを実行します。

リポジトリ本体のチェックアウトで起動すると `impl-<Issue 番号>` のワークツリーとブランチを作って作業します。本体以外のワークツリーで起動すると、新しいワークツリーを作らず起動元のワークツリーで作業し、起動元のブランチを PR の head にします（detached HEAD なら `impl-<Issue 番号>` を作ります）。このときワークツリーはマージ後も人手対応待ちで止まったときも削除せずに残します。

1. **実装** (implementer / setup) — 計画に基づくコード変更／環境構築。PR 前に自己レビュー
   - setup が人手の設定で止まった（`## 人手対応待ち`）ときは PR を作らずに終了（本体のチェックアウトで起動したときはワークツリーとブランチを削除する）
2. **設計判断** (po) — 論点があれば PO エージェントが集約判断
3. **PR 作成** — ワークツリーから Pull Request を作成
4. **QA・CI 修正ループ** (qa) — CI 監視・失敗時の自動修正・マージ（最大 3 回）
   - 3 回失敗時は `escalated` ラベル付きでフォローアップ Issue を起票して終了
5. **完了報告** — Issue への最終レポート

```bash
/spira:implement https://github.com/owner/repo/issues/42
```

### `/spira:do <Issue URL>`

計画から PR マージまでを単一フローで実行します。`planned` ラベルがあれば計画フェーズをスキップして実装から開始します。
作業するワークツリーの決め方は `spira:implement` と同じです（本体以外のワークツリーで起動すると、起動元のワークツリーとブランチで作業します）。

```bash
/spira:do https://github.com/owner/repo/issues/42
```

### `/spira:pick`

現在のリポジトリで、次に対応すべき Open な Issue を 1 件抽出します。
副作用なし（Issue・ラベルへの書き込みは行わない）。

`--exclude 21,24` で指定した Issue を候補から外せます（`spira:orchestrator` が走行中の Issue を外すために使います）。

優先順:

1. `escalated` ラベル付きの Open Issue（番号が若い順）
2. `docs/` 配下に `roadmap.md` があれば、その未完了行に書かれた `→ #<番号>` を上から順に見て
   最初に見つかった Open Issue（ロードマップの記載順）
3. それ以外の Open Issue（番号が若い順）

出力（3 行、URL を最終行に置きチェイン可能）:

```
優先度: escalated
タイトル: <title>
URL: <url>
```

### `/spira:autopilot [--lines <ライン数>] [--env <Infisical 環境名>]`

開発を自走で回す準備（キックオフ）をします。自身は開発しません。

1. **最新化** — デフォルトブランチを `git pull`
   - **中断したラインの片付け** — 前回の `state.md` のライン表に残った Issue（Open で、`#N の CI 失敗` の escalated Issue が無いもの）だけ、
     `impl-N` の worktree・ブランチ・未マージ PR を `scripts/clean-line.sh` で片付ける（未マージ PR は閉じてやり直す。計画は残して再利用する。
     Orca のライン（ブランチ `*/impl-N`）はワークツリーを残し、既定ブランチに戻す）
2. **確認** — ロードマップと Open Issue から着手見込みと依存を把握
3. **前提条件の検査** — 欠けていたら案内して終了
   - gh 認証・origin
   - 人の手による準備物（`.env.example`・ドキュメント・Issue 本文から変数名を集める）。
     **0 件なら置き場所の検査を飛ばす**（`.infisical.json` がデフォルトブランチにコミット済みなら Infisical、そうでなければ `.env` をループ中の置き場所にする）
   - シークレットの置き場所。Infisical（CLI・`.infisical.json`・そのデフォルトブランチへのコミット・ログイン）が使えなければ、
     Infisical のセットアップ（案内して終了）と `.env` での代替（git に無視されたファイルで続行）を提案してユーザーが選ぶ。
     欠けたのがコミットだけなら、提案せずにコミットの手順を案内して終了する（ラインの worktree はコミット済みの `.infisical.json` で Infisical に繋ぐ）
   - 置き場所に無い変数は値 `__SPIRA_PLACEHOLDER__` で作成し、未設定があれば埋める手順を案内して終了
4. **ロードマップの整理** — `spira:sync-roadmap` を呼び出し、Issue の状態とずれたチェック状態・完了行の置き場所を直す PR と、
   ユーザーと決めた未記載 Open Issue を載せる PR をマージする。載せないと決まったものは今回のループの対象外として記録する
   （ロードマップが無い場合は整理を飛ばし、着手順は番号順になる）
5. **書き出し** — `.tmp/spira-autopilot/context.md`（ルール・進め方）と `state.md`（状態）。
   「メインセッションの進め方」は `ORCA_PANE_KEY` の有無で、サブエージェント版か Orca 版を書き出す
6. **案内** — ループ前の `bypassPermissions` への切り替えと、`/clear` 後に実行するプロンプトを提示

```bash
/spira:autopilot              # 最大 5 ライン
/spira:autopilot --lines 3    # 最大 3 ライン
# → /clear してから:
# .tmp/spira-autopilot/context.md を読み、「メインセッションの進め方」に従って自走開発の見回りを続けてください。
```

#### ループの仕組み

メインセッションは `spira:orchestrator` を呼んで報告を表示し、報告が指すラインを起動してラインの終了を待つだけを繰り返します。
状態はすべて `.tmp/spira-autopilot/` にあるため、`/clear` しても続きから再開できます。

| 担当 | やること |
|:--|:--|
| メインセッション | orchestrator の起動 → 報告の表示 → `LAUNCH:` 行のラインを起動 → ラインの終了を待って `lines/N.done` に記録（`NEXT: wait / halt / done`） |
| `spira:orchestrator` | 終わったラインの回収 → 見つかった Issue の判定とロードマップ PR → ブロッカーの再確認 → `spira:pick --exclude` で選んで依存を確認 → ラインの起動を `LAUNCH:` 行で依頼 → ループの終わりならロードマップの整合修正 → 進捗を表で報告 |
| ライン | メインセッションが起動するバックグラウンドの `general-purpose` サブエージェント（Orca 管理下では Orca の監督つきワーカー。下の「Orca 管理下のライン」）。context.md の「ライン規約」に従い `spira:do` を最後まで実行 |

- 同時に走るラインは最大 5 本（`--lines <N>` で変更できる。値は `context.md` の最大ライン数に書き出される）。依存が未完了の Issue は見送る
- 進捗レポートは「現在のライン → 今回の出来事 → 次 → ループ対象の全体像」の順
  - 今回の出来事は、対象 Issue を読んで主題と最大 3 行のサマリー（何が、どう変わったか）を書く
  - ループ対象の全体像は、対象 Issue 全件を順番・状態・メモの表で毎回末尾に出す
- ラインはメインセッションの権限モードで走り、人と対話できないため、ループは `bypassPermissions` を前提とする（キックオフの案内で切り替える）
- `bypassPermissions` でも、複数文をまとめた `bash -c` / `sh -c` は許可待ちになりうるため、context.md の「ライン規約」と `spira:implementer` / `spira:setup` の禁則事項がその形を禁じている
- サブエージェントのラインでは、メインセッションがラインの完了通知を受けると、agentId・status・usage（トークン・ツール回数・所要時間）を `.tmp/spira-autopilot/lines/N.done` に書く。
  orchestrator はそれを終了の印として回収し、`state.md` の結果表に agentId・セッション ID・トークン・ツール・所要を残す
- サブエージェントのラインの会話は `<CLAUDE_CONFIG_DIR>/projects/<slug>/<セッション ID>/subagents/agent-<agentId>.jsonl` に記録され、⚠️ / 🆘 の報告にはそのパスが添えられる
- ⚠️（完了せずに終わった）ラインは、再試行の前に `spira:do` が残した `impl-N` の worktree・ブランチ・未マージ PR を `scripts/clean-line.sh` で片付ける
- 走行中のラインが 🧪 CI かどうかは、`## PR 作成` コメントではなく head が `impl-N`（Orca のラインは `/impl-N` で終わるブランチ）の Open PR の有無で判定する
- 並行するラインの Issue コメント・本文は、Issue 番号付きの一時ファイル（`.tmp/spira-comment-<Issue 番号>.md` など）を経て投稿するため衝突しない
- 人の手による設定が必要になったライン（setup が止まった場合を含む）は、シークレットの置き場所（Infisical または `.env`）にプレースホルダを作り Issue に `## 人手対応待ち` を残して止まる。
  orchestrator は新しいラインを起動せず、走行中のラインが終わったら埋める手順を案内してループを終了する
- ループ中に見つかった Issue（ループ開始後に作られた Open Issue）は orchestrator が判定する
  - 取り込むのは**システムを壊す不具合だけ**（ビルド・CI・主要機能・データ・セキュリティを壊す、ラインの完了を妨げる）。拡張と、壊さない不具合は見送る
  - 取り込む Issue はロードマップの未完了行のなるべく上に追加し、ロードマップ PR を作成→CI 通過後にマージする
- ループ中に出すロードマップ PR は取り込み行の追加だけ。前の見回りで未マージの取り込み行も次の追加 PR にまとめる
- ループが終わる見回り（`NEXT: done / halt`）で、ロードマップが現状を表しているか（クローズ済みが `[x]` で完了節にあるか、走行中でない `[~]` が残っていないか、取り込み行があるか）を確かめ、ずれていればチェック状態を直して完了行を完了節へ移す PR を 1 本作成→マージする（未完了行どうしの並べ替えはしない）
- `escalated` Issue は、ループ開始前からあるものも含めて自走では扱わない（`spira:pick --exclude` で外す）
- escalated Issue がループ中に見つかっても、**自走を続けられないときだけ**ループを止める
  - 続けられない: 原因がデフォルトブランチ側にありどのラインでも同じ失敗が起きる／同じ原因の失敗が複数の Issue で起きている／未完了の Issue がすべてそれに依存している
  - 続けられないと判定したら新しいラインを起動せず、走行中のラインが終わってから手順を案内して終了する。escalated Issue がクローズされれば続きから再開できる

#### Orca 管理下のライン

Orca の中（`ORCA_PANE_KEY` があるセッション）で autopilot を実行すると、ラインは `orca orchestration` の監督つきワーカーとして Orca 上で走ります。

- メインセッションは Run を 1 つ作り（`run-create`）、ラインごとに `worker-start --worktree new-top-level --name impl-<N> --agent claude` で起動し、`orca worktree set --issue` で Issue を紐付ける
- 起動したラインの claude は Orca の設定で権限確認なし（`--dangerously-skip-permissions`）で走る前提。Orca の設定で無効にしていると、ラインは許可待ちで止まる
- ラインの終了は `orca orchestration check --wait --types "worker_done,escalation,question"` を `run_in_background` の Bash で待って知る（ポーリングのスクリプトは使わない）
- ラインは Orca が指示の先頭に差し込む前置きのコマンドで `worker_done` を送る。Issue が CLOSED なら `succeeded`、人手対応待ち・CI 修正打ち切り（escalated）・その他は `failed`。前置きの heartbeat は送らない（生存は `projection.liveness` で判定する）。`ask` は使わず、判断は `spira:do` の PO に任せる（`question` が届いたら、メインセッションは「自分で判断して進めよ」と返す）
- `worker_done` を受けたら `lines/N.done` を書き（`agentId`・usage は `—`、`status` は outcome、`dispatch`・`worktree` を記録）、`worker-release` でそのラインのターミナルを閉じる（ワークツリーはここでは残る）
- 印を残さずに止まったラインは、空の待機が 3 回続いたら `worker-list` を見て、`projection.liveness` が `exited` のときだけ ⚠️ として回収する（`unverifiable` は待ち続ける）
- 結果表の `ワークツリー` にラインが走ったワークツリーのパスが残り、⚠️ / 🆘 の報告にはそのパスが添えられる
- ⚠️ の再試行はワークツリーを残して使い回す。`clean-line.sh` は `*/impl-N` の Open PR を閉じ、ワークツリーを既定ブランチに `reset --hard` で戻す。
  メインセッションは表示名 `impl-<N>` のワークツリーがあれば `--worktree name:impl-<N>` で起動する（そのため失敗したラインの作業内容はローカルからも消える）
- ✅ のラインは、orchestrator が回収時に `finish-line.sh` でワークツリー `impl-<N>` を Orca の登録ごと削除し、ローカル・リモートのブランチ `*/impl-<N>` も消す（スカッシュマージでは Orca がブランチを残すため）。
  ループが終わる見回り（`done` / `halt`）では、結果表で ✅ のラインの残りをまとめて片付ける。走行中のラインがある見回りではまとめて削除しない

出力の書式は `skills/autopilot/templates/` で定義しています。

| 出力 | テンプレート |
|:--|:--|
| ループのコンテキスト | `context.md` |
| メインセッションの進め方 | `main-session-subagent.md`（サブエージェント版）／ `main-session-orca.md`（Orca 版） |
| ループの状態 | `state.md` |
| キックオフ報告 | `kickoff-report.md` |
| 進捗レポート | `progress-report.md` |
| 人の手が必要なときの案内 | `blocker-guide.md` |

ロードマップ PR（整合・整理・追加・整合修正）の書式と、ずれの規則（整合の規則）は、sync-roadmap と共有するため `templates/roadmap-pr.md` にあります。

## プロジェクト構成

```
spira/
├── .claude-plugin/
│   └── plugin.json        # プラグインマニフェスト
├── skills/
│   ├── autopilot/         # 自走開発のキックオフ
│   │   ├── SKILL.md
│   │   └── templates/     # コンテキスト・状態・報告・案内のテンプレート
│   ├── architect/         # アーキテクチャの構成決め
│   │   ├── SKILL.md
│   │   ├── sets/          # 判断の材料（5 セットと配布先の判定）
│   │   └── templates/     # アーキテクチャセット・構成の提案・アーキテクチャのドキュメントの書式
│   ├── brainstorming/     # ブレインストーミング
│   │   ├── SKILL.md
│   │   └── templates/     # 論点テーブル・対話・結論のテンプレート
│   ├── create-issue/      # Issue 起票
│   │   ├── SKILL.md
│   │   └── templates/     # 作成予定 Issue 一覧のテンプレート
│   ├── decide/            # 設計判断
│   ├── do/                # 一気通貫サイクル
│   ├── implement/         # 実装サイクル
│   ├── mockup/            # 画面のデザインモックアップ
│   │   ├── SKILL.md
│   │   └── templates/     # 提案・モックアップの HTML・デザインシステム・ビジュアライゼーションの書式
│   ├── pick/              # 次タスク抽出
│   ├── plan/              # 計画策定
│   ├── request/           # フィードバックの調査・起票
│   │   ├── SKILL.md
│   │   └── templates/     # 調査結果のテンプレート
│   ├── sync-roadmap/      # ロードマップを Issue の現状に合わせる
│   │   ├── SKILL.md
│   │   └── templates/     # 未記載 Issue の一覧のテンプレート
│   └── update-doc/        # ドキュメント更新・PR・マージ
├── hooks/
│   └── hooks.json         # PreToolUse(AskUserQuestion) で判断材料の有無を検査する
├── agents/
│   ├── planner.md         # 計画エージェント
│   ├── implementer.md     # 実装エージェント
│   ├── orchestrator.md    # 自走開発のオーケストレータ
│   ├── po.md              # 設計判断エージェント
│   ├── qa.md              # QA・CI 監視エージェント
│   └── setup.md           # 環境構築エージェント
├── templates/             # Issue 本文・コメント・コミット/PR のテンプレート
│   ├── _rules.md          # 共通ルール・字数上限一覧・投稿手順
│   ├── issue-body.md
│   ├── commit-and-pr.md   # コミットメッセージ・PR タイトル・PR 本文
│   ├── implementation-plan.md
│   ├── plan-revision.md
│   ├── design-decision.md
│   ├── implementation-result.md
│   ├── qa-result.md
│   ├── blocked.md         # 人手対応待ち
│   ├── roadmap-pr.md      # ロードマップの行・追加位置・整合の規則・PR（sync-roadmap / orchestrator 共通）
│   ├── ask-user-question.md # 承認・選択を AskUserQuestion で聞くときの共通規則
│   └── completion-report.md
├── scripts/
│   ├── clean-line.sh      # 中断・失敗したラインの impl-N（worktree・ブランチ・未マージ PR）を片付ける。Orca の */impl-N はワークツリーを残して既定ブランチに戻す（autopilot / orchestrator 共通）
│   ├── finish-line.sh     # 完了した Orca のラインのワークツリー impl-N を Orca の登録ごと削除し、ブランチ */impl-N をローカル・リモートとも消す（orchestrator）
│   └── check-ask-material.sh # 判断材料を本文に出さずに AskUserQuestion を呼んだら拒否するフック
└── README.md
```

## Issue の記述量

spira が Issue に書き込む本文・コメントは、`templates/` 配下のテンプレートで書式と字数上限が
定義されています。スキル・エージェントは投稿前に `wc -m` で字数を確認し、上限を超えた内容は投稿しません。

| 書き込み先 | 上限 |
|:--|--:|
| Issue 本文 | 1,500 字 |
| `## 実装計画` | 2,500 字 |
| `## 設計判断` | 800 字／論点 |
| `## 計画の修正` | 500 字 |
| `## 実装内容` | 1,200 字 |
| `## 設計判断に基づく修正` / `## CI 修正 (N回目)` | 500 字 |
| `## QA 結果` / `## CI 失敗 (N回目)` | 300 字 |
| `## 完了報告` | 500 字 |
| `## 人手対応待ち` | 300 字 |

PO 判断の反映や CI 修正は**差分のみ**を記録し、実装計画・実装内容の全文再掲は行いません。
上限を変更する場合は `templates/_rules.md` と各テンプレートを更新してください。

## 承認・選択の聞き方

brainstorming・create-issue・sync-roadmap・mockup・architect・explain は、ユーザーの承認・選択を待つ箇所で、表や提案を本文に出したうえで問いだけを `AskUserQuestion` で聞きます。
ダイアログには問いと選択肢しか出ないため、判断材料を本文に出していない応答では `AskUserQuestion` を呼びません。
これはプロンプトの規則だけでは守られなかった（表を思考の中だけで作って問いを出す）ため、`PreToolUse` フック（`hooks/hooks.json` → `scripts/check-ask-material.sh`）で強制しています。直前に本文のテキスト（空白を除いて 20 字以上。`SPIRA_ASK_MIN_CHARS` で変更可）が無い `AskUserQuestion` の呼び出しは拒否され、本文を書いてから呼び直すよう指示が返ります。フックは spira のスキル以外の `AskUserQuestion` にも効きます。
本文のテキストで聞いてターンを終えると、Orca は返事待ちのペインを作業を終えたペイン（`done`）と区別できないためです。`AskUserQuestion` の呼び出し中は `waiting`（Needs You）と表示されます。Orca の外でも聞き方は同じです。

選択肢に無い答え（修正指示など）は `Other` に書きます。各スキルは、それを従来の修正指示と同じく扱います（表の作り直し・再提示など）。
問いの共通規則と複数スキルで同じ問い（未コミットの変更の確認）は `templates/ask-user-question.md`、各スキルの問いは各スキルのテンプレートの「問い」の節（create-issue は「承認の扱い」）にあります。

## エージェント一覧

| エージェント | 役割 |
|:--|:--|
| **planner** | タスクの要件分析と実装計画の作成 |
| **implementer** | 計画に基づくコードの実装・修正・PR 前自己レビュー |
| **po** | 設計判断（複数論点を集約して 1 回でまとめて判断） |
| **qa** | CI ステータス監視、全チェック通過後の自動マージ。呼び出し元から渡されたワークツリーだけをマージ後に削除する |
| **setup** | 開発環境の構築（ライブラリ、環境マネージャ、フレームワーク、CI）。`mise install` と `mise run setup` で整う状態にし、人手の設定が必要な値では `## 人手対応待ち` を記録して止まる |
| **orchestrator** | 自走開発の見回りを 1 回行い、ラインの状況を表で報告 |

## ラベル

spira は以下のラベルを自動作成・運用します。

| ラベル | 色 | 意味 |
|:--|:--|:--|
| `planned` | 青 | 実装計画が策定済み |
| `escalated` | 赤 | 人手による対応が必要（自動修正の限界に達した） |

## 開発

### ローカルテスト

インストール済みのプラグインとは別に、作業ツリーをそのまま読み込む。
このリポジトリの `spira/` をカレントディレクトリにして実行する。
**利用者向けのインストール手順ではない**（インストールは [セットアップ](#インストール) を参照）。

```bash
claude --plugin-dir .
```

### デバッグ

```bash
claude --debug --plugin-dir .
```

### インストール済みのプラグインに反映する

ローカルマーケットプレイスは自動更新されないため、入れ直す。

```bash
../scripts/update.sh spira
```

プラグインに変更を加えた場合は Claude Code を再起動して反映させてください。

## ライセンス

MIT
