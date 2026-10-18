# テンプレート: メインセッションの進め方（Orca 版）

- **書き手**: autopilot スキル（`ORCA_PANE_KEY` があるとき、下の `---` 以降を [context.md](./context.md) の `{{MAIN_SESSION}}` に入れる）
- **読み手**: `/clear` 後のメインセッション、各ライン（「Orca ラインの終わり方」節）
- ラインは `orca orchestration` の監督つきワーカーとして、ライン専用の Orca ワークツリーで走る

---

## メインセッションの進め方

メインセッションは**開発も判断もしない**。オーケストレータを呼び、報告を見せ、ラインを起動し、ラインの終了を待つだけを繰り返す。
ラインは `orca orchestration` の監督つきワーカーとして、Orca のワークツリー（表示名 `impl-<N>`、ブランチ `<ユーザー>/impl-<N>`）で走る。
ラインは人と対話できないため、Orca が起動する claude は権限確認なし（`--dangerously-skip-permissions`）で走る設定を前提とする。

0. 始めに（`/clear` の後も）`orca orchestration run-current --json` で Run が紐付いているかを確かめ、無ければ `orca orchestration run-create --objective "spira autopilot {{REPO}}" --json` で作る。Run の ID を覚えておく
1. Agent ツールで `subagent_type: "spira:orchestrator"` を起動する
   - prompt: `{{ROOT}}/.tmp/spira-autopilot/context.md に従い、見回りを 1 回行って進捗レポートを返してください。`
2. 返ってきた進捗レポートを**手を加えずに**ユーザーへ表示する（`LAUNCH:` 行と最終行の `NEXT:` 行は除く）
3. `LAUNCH: <N> <Issue URL>` 行ごとに、ラインを起動する
   - ライン指示: `{{ROOT}}/.tmp/spira-autopilot/context.md の「ライン規約」と「Orca ラインの終わり方」を Read して従ったうえで、spira:do スキルを引数 <Issue URL> で実行し、最後まで進めてください。`
   - `orca worktree list --json` に表示名 `impl-<N>` のワークツリーが無ければ新しく作り、あれば（⚠️ の再試行）それを使う

     ```bash
     # 無いとき
     orca orchestration worker-start --spec "<ライン指示>" --worktree new-top-level --repo path:{{ROOT}} --name impl-<N> --agent claude --task-title "#<N>" --json
     # あるとき
     orca orchestration worker-start --spec "<ライン指示>" --worktree name:impl-<N> --agent claude --task-title "#<N>" --json
     ```
   - 終了コードが 0 なら、JSON の Dispatch ID と `<N>` の対応を覚え、`orca worktree set --worktree name:impl-<N> --issue <N> --json` で Issue を紐付ける
   - 0 以外なら起動し直さない。JSON の `failedStage` と `residualResources` を要約してユーザーに見せ、下の `.done` を `status: failed` で書く（orchestrator が ⚠️ として回収する）
4. レポート最終行の `NEXT:` で分岐する

| NEXT | 行動 |
|:--|:--|
| `wait` | 下の「ラインの終了の待ち方」で待つ。`.done` を書いたら 1 に戻る |
| `halt` | ループを終了する（人の手が必要な設定、または自走を続けられないエスカレーションがある。レポートに手順が書かれている） |
| `done` | ループを終了する（進められる Issue が無い） |

### ラインの終了の待ち方

待機は `run_in_background: true` の Bash で走らせ、その完了通知を待つ。待機中の Bash が既に走っていれば、新しく走らせずにその通知を待つ。

```bash
orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json 2>/dev/null
```

返ってきたバッチ（FIFO で、種類を問わず全メッセージが入る）の**メッセージをすべて**、種類ごとに次のように処理する。

| 種類 | 処理 |
|:--|:--|
| `worker_done` | 送り主の Dispatch ID から `<N>` を引き（分からなければ `orca orchestration worker-list --run <Run の ID> --json` のタスク名 `#<N>` で照合する）、下の `.done` を `status: <outcome>` で書く。続けて `orca orchestration worker-release --dispatch <Dispatch ID> --json` でターミナルを閉じる（ワークツリーは残る。✅ なら orchestrator が回収時に `finish-line.sh` で削除する） |
| `question` | `orca orchestration reply --id <メッセージ ID> --body "人に確認せず、自分で判断して進めてください。判断が要る論点は spira:do の PO エージェントに任せてください。" --json` で答える |
| `escalation` | 件名と本文を要約してユーザーに見せる。ラインは止めずに待ち続ける |
| その他 | 何もしない |

すべて処理したら、`--ack <バッチの delivery ID>` を足した同じ待機を `run_in_background: true` で走らせる（ack と次の待機を兼ねる）。
`.done` を 1 つでも書いていれば 1 に戻り、書いていなければ待機の完了通知を待つ。

タイムアウト・空のバッチは区切りであって失敗ではない。`--ack` を付けずに待機を走らせ直す。
空が 3 回続いたら、`orca orchestration worker-list --run <Run の ID> --json` で走行中のラインの `projection.liveness` を見る。

| liveness | 処理 |
|:--|:--|
| `exited` | 印を残さずに止まったラインとして、下の `.done` を `status: exited` で書き、1 に戻る |
| `live` / `unverifiable` | 待ち続ける（止めない・起動し直さない） |

### `.done` の書き方

`{{ROOT}}/.tmp/spira-autopilot/lines/<N>.done` を次の形で書く。Orca のラインにはサブエージェントの usage が無いため、`agentId`・`tokens`・`tool_uses`・`duration_ms` は `—` にする。

```
agentId: —
status: <succeeded / failed / exited>
tokens: —
tool_uses: —
duration_ms: —
dispatch: <Dispatch ID（無ければ —）>
worktree: <ワークツリーのパス>
```

`worktree` は、ブランチが `impl-<N>` か `/impl-<N>` で終わるワークツリーのパスである。

```bash
git -C {{ROOT}} worktree list --porcelain | awk -v s="/impl-<N>" '/^worktree /{w=substr($0,10)} /^branch /{b=$2; if (substr(b, length(b)-length(s)+1) == s) print w}'
```

ユーザーから停止を指示されたら、新しいラインを起動せずに終了する（走行中のラインは止めない）。

## Orca ラインの終わり方

Orca のワーカーとして起動されたラインは、「ライン規約」に加えてこの節に従う。

- 終わるときに、前置き（Orca が指示の先頭に差し込む）にある `worker_done` のコマンドを**1 回だけ**送る。実行ファイル・フラグ・ID は前置きのとおりにし、自分で組み立てない
- `--outcome` は終わり方で選ぶ

  | 終わり方 | outcome |
  |:--|:--|
  | Issue が CLOSED になった（`spira:do` が PR をマージした） | `succeeded` |
  | それ以外（人手対応待ちで止まった・CI 修正打ち切りで `escalated` Issue を起票した・途中で失敗した） | `failed` |
- 前置きが 5 分ごとの heartbeat（`--type heartbeat` の生存通知）を求めていても送らず、送るのは `worker_done` だけにする（メインセッションは `check --wait` を `worker_done,escalation,question` に絞り、ラインの生存は `worker-list` の `projection.liveness` で判定するため、heartbeat は使われず通知の雑音になるだけである）
- 前置きの `ask` は使わない。判断が要る論点は `spira:do` の PO エージェントに任せる
- 前置きが無い（Orca のワーカーではない）ときは、この節を無視する
