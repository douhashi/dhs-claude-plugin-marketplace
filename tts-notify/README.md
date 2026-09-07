# tts-notify

Claude Code の **Stop / Notification** を [hailer](https://github.com/douhashi/hailer) の
broker（`POST /announce`）へ渡し、音声読み上げ＋モバイル通知するフックプラグイン。

Notification は「ツール使用許可要求」など**ユーザーのアクションが要る通知だけ**を
読み上げ、入力待ちアイドル通知（`waiting for your input` 等）はドロップする。

## 責務

**このプラグインは要約しない。秘密も持たない。**

生テキストと task 名を broker へ渡すだけで、以下はすべて broker 側の責務:

| 決めるもの | どこにあるか |
|---|---|
| 口調（persona） | broker の `presets/<preset>.md` |
| 声（voice） | tts-synth の `presets/<preset>.wav` |
| 変換ルール・文数 | broker の `tasks/<task>.md` と `tasks.json` |
| 要約モデル・OpenRouter 鍵 | broker の env（`OPENROUTER_MODEL` / `OPENROUTER_API_KEY`） |
| 要約失敗時の degrade | broker の task 定義（`fallback: raw \| drop`） |
| 音量・mute | broker の channel（`hail volume` / `hail mute`） |

> 以前はこのプラグインが OpenRouter を直接叩いて要約していた。その形だと鍵と
> プロンプトを作業機ごとに配ることになり、**機種変で `~/.config/tts-notify/env` が
> 失われて 4 日間無言になった**（要約失敗は graceful degrade するのでエラーが出ない）。
> 要約を broker に寄せて、producer から鍵を無くしたのはその再発防止でもある。

ここに残るのは Claude Code 固有の仕事だけ:

- transcript の抽出とフラッシュ待ち（`lib/extract.py`）
- 入力待ちアイドル通知の除外
- 単一フライト制御

## 構成

```
tts-notify/
├── .claude-plugin/plugin.json   # マニフェスト（hooks: ./hooks/hooks.json）
├── hooks/
│   ├── hooks.json               # Stop/Notification → dispatch.sh
│   └── dispatch.sh              # 薄い共通ディスパッチャ（新セッションへデタッチ→即 return）
├── bin/worker.sh                # デタッチ実行: 抽出 → broker /announce へ POST
└── lib/
    ├── common.sh                # 設定ロード/ログ/パス
    └── extract.py               # transcript JSONL 抽出（stdlib のみ）
```

2 イベントは **単一 `dispatch.sh`**（引数で差分）に集約。dispatch はイベント JSON を
stash して `worker.sh` を**新しいセッション**へデタッチし即 return するため、
Claude Code を一切ブロックしない（`setsid` が無い macOS では python3 で
`setsid(2)` を呼ぶ）。フックチェーンは壊さない（exit 0）が、worker の起動に失敗した
場合は理由を `worker.log` に残す。

## 動作

1. `dispatch.sh <source>` … stdin のイベント JSON を一時保存し worker をデタッチ起動
2. `worker.sh` …
   - **単一フライト**: atomic な `mkdir` ロック。POST 中に来た新イベントは**ドロップ**
     （先がち・キューなし・取り戻しなし）
   - notification は `.message` を判定し、入力待ちアイドル通知はドロップ →
     task `claude-notification`
   - stop は transcript から最新 assistant 本文＋直前 user を取り出す
     （最大 `TTS_NOTIFY_TRANSCRIPT_WAIT` 秒バウンドでフラッシュ待ち）→ task `claude-stop`
   - `POST $HAIL_URL/announce` に `{text, task, preset?, cue}` を送る。
     broker は **202 で即返し**、要約と配送はバックグラウンドで行う

broker 側が preset/task を解決できない場合は同期で **400** が返るので、設定ミスは
`worker.log` にはっきり出る（無言で消えない）。

## セットアップ

### 1. broker

[hailer](https://github.com/douhashi/hailer) の broker を起動しておく。疎通確認は
`hail status`。broker が別ホスト/別ポートなら `HAIL_URL` を設定する
（既定 `http://127.0.0.1:8080`、`hail` CLI と共通）。

#### リモート broker（Cloudflare tunnel + Access 経由）

このフックは**機械クライアント**なので Access の対話ログインを処理できない。
**Service Token** が要る。

```sh
mkdir -p ~/.config/tts-notify
umask 077
cat > ~/.config/tts-notify/env <<'EOF'
HAIL_URL=https://<admin-host>
CF_ACCESS_CLIENT_ID=<...>.access
CF_ACCESS_CLIENT_SECRET=<...>
# 声と口調を同時に決める。省略すると broker の HAILER_DEFAULT_PRESET に従う
TTS_NOTIFY_PRESET=sophie
EOF
chmod 600 ~/.config/tts-notify/env
```

- token 対が**両方揃っているときだけ**ヘッダを送る（loopback 運用は従来どおり）。
- **再生（声）はサーバではなくクライアントで鳴る**。声を聞くマシンで `hail listen` を
  常駐させておくこと（通知は ntfy がスマホへ push する）。

> Access に弾かれると Cloudflare は **302 → ログイン画面（200 HTML）** を返す。curl の
> リダイレクト追跡を有効にすると「成功」に化けて無言で声が出なくなるため、worker は
> **content-type が HTML なら Cloudflare の応答**と判定して `worker.log` に理由を残す。

### 2. インストール

```sh
/plugin marketplace add /path/to/dhs-claude-plugin-marketplace
/plugin install tts-notify@dhs-claude-plugin-marketplace
```

## 設定（`~/.config/tts-notify/env` または環境変数）

| 変数 | 既定 | 説明 |
|---|---|---|
| `HAIL_URL` | `http://127.0.0.1:8080` | hailer broker のベース URL（`hail` CLI と共通） |
| `CF_ACCESS_CLIENT_ID` | （無し） | Cloudflare Access の service token。リモート broker のときのみ |
| `CF_ACCESS_CLIENT_SECRET` | （無し） | 同上。**両方揃ったときだけ**ヘッダを送る |
| `TTS_NOTIFY_PRESET` | （無し＝broker の既定） | 声と口調（`fenrys`/`gena`/`sophie`） |
| `TTS_NOTIFY_CUE` | `true` | 先頭で開始音を鳴らすか（`true`/`false`） |
| `TTS_NOTIFY_TRANSCRIPT_WAIT` | `5` | transcript フラッシュ待ち秒 |
| `TTS_NOTIFY_CACHE` | `~/.cache/tts-notify` | ロック/ログ置き場（`worker.log`） |

> **OpenRouter の設定はここには無い。** broker 側の env で持つ。

## デバッグ

`~/.cache/tts-notify/worker.log` を見る（`announced` / `busy -> drop` /
`... -> drop` の理由が出る）。手動実行:

```sh
echo '{"message":"テスト"}' > /tmp/e.json
CLAUDE_PLUGIN_ROOT=$PWD/tts-notify tts-notify/bin/worker.sh notification /tmp/e.json
```

要約結果そのものは broker のログに出る（`announced task=... preset=...`）。
このプラグイン側のログは「投げたかどうか」までしか分からない。
