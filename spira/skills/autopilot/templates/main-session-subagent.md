# テンプレート: メインセッションの進め方（サブエージェント版）

- **書き手**: autopilot スキル（`ORCA_PANE_KEY` が無いとき、下の `---` 以降を [context.md](./context.md) の `{{MAIN_SESSION}}` に入れる）
- **読み手**: `/clear` 後のメインセッション
- ラインはメインセッションが Agent ツールで起動するバックグラウンドのサブエージェント

---

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
