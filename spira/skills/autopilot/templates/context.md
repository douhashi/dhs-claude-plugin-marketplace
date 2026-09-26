# テンプレート: 自走開発のコンテキスト

- **書き手**: autopilot スキル（`.tmp/spira-autopilot/context.md` に書き出す）
- **読み手**: `/clear` 後のメインセッション、orchestrator エージェント、各ライン（メインセッションが起動するサブエージェント）
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

## メインセッションの進め方

メインセッションは**開発も判断もしない**。オーケストレータを呼び、報告を見せ、ラインを起動し、完了通知を待つだけを繰り返す。
権限モードは `bypassPermissions` を前提とする（ラインはメインセッションの権限モードで走り、人と対話できない）。

1. Agent ツールで `subagent_type: "spira:orchestrator"` を起動する
   - prompt: `{{ROOT}}/.tmp/spira-autopilot/context.md に従い、見回りを 1 回行って進捗レポートを返してください。`
2. 返ってきた進捗レポートを**手を加えずに**ユーザーへ表示する（`LAUNCH:` 行と最終行の `NEXT:` 行は除く）
3. `LAUNCH: <N> <Issue URL>` 行ごとに、Agent ツールでラインを起動する（1 つのメッセージでまとめて起動してよい）
   - `subagent_type: "general-purpose"`、`run_in_background: true`、description: `ライン #<N>`
   - prompt: `{{ROOT}}/.tmp/spira-autopilot/context.md の「ライン規約」を Read して従ったうえで、spira:do スキルを引数 <Issue URL> で実行し、最後まで進めてください。`
   - 起動結果の agentId と `<N>` の対応を覚えておく
4. レポート最終行の `NEXT:` で分岐する

| NEXT | 行動 |
|:--|:--|
| `wait` | ラインの完了通知を待つ。通知を受けたら下の `.done` を書いて 1 に戻る |
| `halt` | ループを終了する（人の手が必要な設定、または自走を続けられないエスカレーションがある。レポートに手順が書かれている） |
| `done` | ループを終了する（進められる Issue が無い） |

完了通知を受けたら、その agentId に対応する `<N>` について `{{ROOT}}/.tmp/spira-autopilot/lines/<N>.done` を次の形で書く（通知に無い値は `—`）。

```
agentId: <agentId>
status: <通知の status>
tokens: <usage のトークン数（subagent_tokens）>
tool_uses: <usage の tool_uses>
duration_ms: <usage の duration_ms>
```

ユーザーから停止を指示されたら、新しいラインを起動せずに終了する（走行中のラインは止めない）。

## ライン規約

各ライン（メインセッションが起動するサブエージェント）はこの節に従う。ラインは人と対話できない。

- `spira:do` を渡された Issue URL で最後まで進める。途中でユーザーに質問しない
- シークレットが必要なコマンドは、置き場所に応じて次のように実行する
  - `infisical`: `infisical run --env {{ENV}} -- <コマンド>`（worktree でもデフォルトブランチにコミット済みの `.infisical.json` で繋がる）
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
