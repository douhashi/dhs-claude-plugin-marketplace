# テンプレート: 自走開発のコンテキスト

- **書き手**: autopilot スキル（`.tmp/spira-autopilot/context.md` に書き出す）
- **読み手**: `/clear` 後のメインセッション、orchestrator エージェント、各ライン（メインセッションが起動するサブエージェント、または Orca のワーカー）
- `{{MAIN_SESSION}}` は、autopilot スキルの Phase 5 で選んだ版（[main-session-subagent.md](./main-session-subagent.md) か [main-session-orca.md](./main-session-orca.md)）で埋める。入れた中の `{{...}}` も埋める
- `{{...}}` はすべて埋める。埋められない値があれば書き出さずに報告する
- 下の `---` 以降をそのまま書き出す

---

# 自走開発コンテキスト

このファイルだけで自走開発を再開できるように書かれている。前の会話の記憶は当てにしない。

## 基本情報

| 項目 | 値 |
|:--|:--|
| リポジトリ | `{{REPO}}` |
| ルート | `{{ROOT}}` |
| 作業ディレクトリ | `{{ROOT}}/.tmp/spira-autopilot` |
| 状態ファイル | `{{ROOT}}/.tmp/spira-autopilot/state.md` |
| デフォルトブランチ | `{{BRANCH}}` |
| シークレットの置き場所 | `{{STORE}}`（`infisical` / `dotenv`） |
| Infisical 環境 | `{{ENV}}` |
| シークレットのファイル | `{{ENV_FILE}}`（ルートからの相対パス） |
| spira | `{{PLUGIN_ROOT}}` |
| 最大ライン数 | {{MAX_LINES}} |
| ラインの権限モード | メインセッションと同じ（`bypassPermissions` 前提。ラインは人と対話できないため） |
| 作成日時 | {{CREATED_AT}} |

## ループのルール

1. **可能な限り自走する**。ユーザーへの質問・確認で止まらない。判断が要る論点は `spira:do` の PO エージェントに任せる
2. **Issue の選択は `spira:pick`、開発は `spira:do` に任せる**。ループ側で計画・実装をしない
3. **ブロッカーの無い Issue だけを並列で進める**。同時に走るラインは最大 {{MAX_LINES}} 本（基本情報の「最大ライン数」）
4. **人の手による設定が必要になったら止める**。シークレットの置き場所にプレースホルダで変数を作り、埋める手順を案内してループを終了する
5. **状態はファイルに残す**。進捗は `state.md`、各ラインの終了は `lines/<Issue 番号>.done`（メインセッションが完了通知から書く）にある。ラインの会話は `<CLAUDE_CONFIG_DIR>/projects/<slug>/<セッション ID>/subagents/agent-<agentId>.jsonl` に記録され、終わった後も読んで事後調査できる。agentId とセッション ID は `state.md` の結果表に残る
6. **ループ中に見つかった Issue は orchestrator が判定する**。取り込むのは**システムを壊す不具合だけ**で、拡張や壊さない不具合は今回のループでは扱わない。取り込むものはロードマップの適切な位置に追加し、PR を作ってマージする
7. **キックオフで対象外とした Issue は扱わない**（`state.md` の「対象外 Issue」表）。扱うようにするには、いったんループを終えて `/spira:autopilot` からやり直す
8. **`escalated` Issue は自走では扱わない**（ループ開始前からあるものも含む）。ループ中に見つかっても、止めるのは自走を続けられないときだけ。他の Issue を進められるなら、見送って続ける
9. **ロードマップは常に現状を表す**。キックオフ時点でロードマップのずれは直し、未記載の Issue は整理済み。orchestrator はループ中、見つかった不具合の行の追加だけを PR にする。チェック状態の修正と完了行の完了節への移動は、ループが終わるとき（NEXT が done / halt）に 1 本の PR にまとめてマージする

{{MAIN_SESSION}}

## ライン規約

各ライン（メインセッションが起動するサブエージェント）はこの節に従う。ラインは人と対話できない。

- `spira:do` を渡された Issue URL で最後まで進める。途中でユーザーに質問しない
- 複数のコマンドは `bash -c` / `sh -c` にまとめず、1 つずつ実行するか、`&&` で繋ぐか、スクリプトファイルにして実行する（`cd <dir> &&` の後ろに、変数で始まる文を含む複数文の `bash -c` を置くと、権限モードに関係なく許可待ちで止まる。シークレットの有無・置き場所を問わない）
- シークレットが必要なコマンドは、置き場所に応じて次のように実行する
  - `infisical`: `infisical run --env {{ENV}} -- <コマンド>`（worktree でもデフォルトブランチにコミット済みの `.infisical.json` で繋がる）。複数のコマンドのときは、コマンドごとに `infisical run --env {{ENV}} --` を付けて `&&` で繋ぐか、スクリプトファイルにして `infisical run --env {{ENV}} -- <スクリプト>` で実行する
  - `dotenv`: プロジェクトの読み込み（mise の `_.file`・dotenv 等）に任せる。読み込まれないときは `set -a; . {{ROOT}}/{{ENV_FILE}}; set +a` の後に実行する
- シークレットの値を出力・コミット・Issue コメントに書かない
- **人の手による設定が必要と判明したら**、次の 3 つを行ってすぐに終了する（PR は作らない）
  1. 変数ごとのプレースホルダを作る（setup が作成済みでも行う。既存の値は上書きしない）
     - `infisical`: `{{PLUGIN_ROOT}}/templates/blocked.md` の「プレースホルダの作成」に従い、環境 `{{ENV}}` に作る
     - `dotenv`: `{{ROOT}}/{{ENV_FILE}}` に `NAME=` で始まる行が無い変数だけ、`printf '%s=__SPIRA_PLACEHOLDER__\n' NAME >> {{ROOT}}/{{ENV_FILE}}` で足す（worktree 内のファイルではなくルートのファイルに書く）
  2. `{{ROOT}}/.tmp/spira-autopilot/lines/<Issue 番号>.blocked.md` に次の表を書く

     ```markdown
     | 変数 | 用途 | 値の入手先 |
     |:--|:--|:--|
     | `NAME` | （何に使うか 1 文） | （取得できる画面・URL・担当者） |
     ```
  3. `{{PLUGIN_ROOT}}/templates/blocked.md` を Read し、Issue に `## 人手対応待ち` をコメントする（`infisical` は「Infisical がある場合」、`dotenv` は「Infisical が無い場合」の版。setup が記録済みなら重ねてコメントしない）
- `spira:do` が setup の人手対応待ちで終わった場合も、人の手による設定が必要と判明したものとして上の 3 つを行う
