# tts-notify

Claude Code の **Stop / Notification** を OpenRouter で短く
要約し、[hailer](https://github.com/douhashi/hailer) の broker（`POST /hail`）
経由で音声読み上げ＋モバイル通知するフックプラグイン。

Notification は「ツール使用許可要求」など**ユーザーのアクションが要る通知だけ**を
読み上げ、入力待ちアイドル通知（`waiting for your input` 等）はドロップする。

旧 `~/.claude/hooks/tts-on-*.sh` ＋ 常駐コーディネータ（:16101）構成の置き換え。
読み上げ／通知の配送は hailer broker が担うため、このプラグイン自体は
**常駐サービス不要**（デタッチ worker 方式）。

## 構成

```
tts-notify/
├── .claude-plugin/plugin.json   # マニフェスト（hooks: ./hooks/hooks.json）
├── hooks/
│   ├── hooks.json               # Stop/Notification → dispatch.sh
│   └── dispatch.sh              # 薄い共通ディスパッチャ（即 setsid デタッチ→即 return）
├── bin/worker.sh                # デタッチ実行: 抽出→要約→hailer /hail へ POST
└── lib/
    ├── common.sh                # 設定ロード/ログ/パス（共通処理を集約）
    ├── extract.py               # transcript JSONL 抽出（stdlib のみ）
    ├── summarize.sh             # OpenRouter 要約（NDJSON {say, show} を出力）
    └── validate.py              # 要約応答の検証/正規化（stdlib のみ・弾いた理由をログ）
```

2 イベントは **単一 `dispatch.sh`**（`--source` 引数で差分）に集約。dispatch は
イベント JSON を stash して `setsid` で `worker.sh` を即デタッチし即 return する
ため、Claude Code を一切ブロックしない。失敗は常に静かな no-op（exit 0）。

## 動作

1. `dispatch.sh <source>` … stdin のイベント JSON を一時保存し worker をデタッチ起動
2. `worker.sh` …
   - **単一フライト**: `flock -n`。要約〜`/hail` POST の最中に来た新イベントは
     **ドロップ**（先がち・キューなし・取り戻しなし。意図的に単純化）。POST は即
     返るため、実再生の順序制御は broker 側の責務
   - notification は `.message` を判定し、入力待ちアイドル通知はドロップ。
     許可要求など要アクション通知のみ要約対象
   - テキスト取得: notification は `.message`、stop は
     transcript から最新 assistant 本文＋直前 user（最大 `TTS_NOTIFY_TRANSCRIPT_WAIT`
     秒バウンドでフラッシュ待ち）
   - OpenRouter で要約（`stop`=1〜2 文 / `notification`=1 文、`text`+`reading`
     構造化出力。プロンプト・スキーマは irodori-tts-docker coordinator から忠実移植）。
     応答は `validate.py`（stdlib）で検証・正規化し、弾いた文は理由を `worker.log` へ
   - 各文を hailer の segment に変換し `POST $HAIL_URL/hail` へ送る。
     `show`（自然な日本語表記）→ `text`（ntfy push 本文）、`say`（英単語→カタカナ版）
     → `speech`（TTS が合成する読み）。`targets` は省略し broker の enabled 全
     チャネルへファンアウト（音量は broker channel が権威）
3. 鍵欠如/要約失敗時の graceful degrade:
   - notification → 生メッセージをそのまま送る（`{"say": 生文}`、text も生文）
   - stop → ドロップ（assistant 本文は長大になりうるため生読みしない）

## セットアップ

### 1. 秘密（OpenRouter API キー）

プラグイン外・リポ外の `~/.config/tts-notify/env`（chmod 600）に置く:

```sh
mkdir -p ~/.config/tts-notify
umask 077
cat > ~/.config/tts-notify/env <<'EOF'
OPENROUTER_API_KEY=sk-or-...
EOF
chmod 600 ~/.config/tts-notify/env
```

キーが無くても壊れない（要約スキップで degrade）。OpenRouter 側で spend 上限推奨。

### 2. TTS / 通知バックエンド（hailer）

[hailer](https://github.com/douhashi/hailer) の broker を起動しておく
（読み上げ・モバイル通知の配送はすべて broker が担当）:

```sh
cd ~/ghq/github.com/douhashi/hailer && docker compose up -d
```

疎通確認は `hail status`（または `curl -s "$HAIL_URL/health"`）。チャネルの
有効/無効・音量は `hail channels` / `hail mute <ch>` / `hail volume <0-100>` で
broker 側を操作する（このプラグインからは設定しない）。broker が別ホスト/別ポート
の場合は `HAIL_URL` を設定する（既定 `http://127.0.0.1:8080`、`hail` CLI と共通）。

### 3. インストール

```sh
/plugin marketplace add /path/to/dhs-claude-plugin-marketplace
/plugin install tts-notify@dhs-claude-plugin-marketplace
```

旧構成（`~/.claude/settings.json` の `tts-on-*.sh` を指す Stop/Notification
フック）は**重複発火するので削除**すること。

## 設定（`~/.config/tts-notify/env` または環境変数）

| 変数 | 既定 | 説明 |
|---|---|---|
| `OPENROUTER_API_KEY` | （無し） | OpenRouter キー。未設定で要約 degrade |
| `OPENROUTER_MODEL` | `openai/gpt-5-mini` | 要約モデル |
| `OPENROUTER_URL` | `https://openrouter.ai/api/v1/chat/completions` | エンドポイント |
| `HAIL_URL` | `http://127.0.0.1:8080` | hailer broker のベース URL（`hail` CLI と共通） |
| `TTS_NOTIFY_PRESET` | `gena` | 声プリセット（`fenrys`/`gena`/`sophie`） |
| `TTS_NOTIFY_CUE` | `true` | 先頭で開始音を鳴らすか（`true`/`false`） |
| `TTS_NOTIFY_TRANSCRIPT_WAIT` | `5` | transcript フラッシュ待ち秒 |
| `TTS_NOTIFY_CACHE` | `~/.cache/tts-notify` | ロック/ログ置き場（`worker.log`） |

## デバッグ

`~/.cache/tts-notify/worker.log` を見る（`spoke` / `busy -> drop` /
`... -> drop` の理由が出る）。手動実行:

```sh
echo '{"message":"テスト"}' > /tmp/e.json
CLAUDE_PLUGIN_ROOT=$PWD/tts-notify tts-notify/bin/worker.sh notification /tmp/e.json
```
