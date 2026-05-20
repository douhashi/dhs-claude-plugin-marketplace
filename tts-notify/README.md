# tts-notify

Claude Code の **Stop / SubagentStop / Notification** を OpenRouter で短く
要約し、ローカル TTS（[stt-tts-runpod](https://github.com/douhashi/stt-tts-runpod)
の `scripts/tts_say.sh`）で読み上げるフックプラグイン。

旧 `~/.claude/hooks/tts-on-*.sh` ＋ 常駐コーディネータ（:16101）構成の置き換え。
**常駐サービス不要**（デタッチ worker 方式）。

## 構成

```
tts-notify/
├── .claude-plugin/plugin.json   # マニフェスト（hooks: ./hooks/hooks.json）
├── hooks/
│   ├── hooks.json               # Stop/SubagentStop/Notification → dispatch.sh
│   └── dispatch.sh              # 薄い共通ディスパッチャ（即 setsid デタッチ→即 return）
├── bin/worker.sh                # デタッチ実行: 抽出→要約→tts_say.sh
└── lib/
    ├── common.sh                # 設定ロード/ログ/パス（共通処理を集約）
    ├── extract.py               # transcript JSONL 抽出（stdlib のみ）
    └── summarize.sh             # OpenRouter 要約（プロンプト/スキーマは coordinator 由来）
```

3 イベントは **単一 `dispatch.sh`**（`--source` 引数で差分）に集約。dispatch は
イベント JSON を stash して `setsid` で `worker.sh` を即デタッチし即 return する
ため、Claude Code を一切ブロックしない。失敗は常に静かな no-op（exit 0）。

## 動作

1. `dispatch.sh <source>` … stdin のイベント JSON を一時保存し worker をデタッチ起動
2. `worker.sh` …
   - **単一フライト**: `flock -n`。再生/要約中に来た新イベントは**ドロップ**
     （先がち・キューなし・取り戻しなし。意図的に単純化）
   - テキスト取得: notification は `.message`、stop/subagent_stop は
     transcript から最新 assistant 本文＋直前 user（最大 `TTS_NOTIFY_TRANSCRIPT_WAIT`
     秒バウンドでフラッシュ待ち）
   - OpenRouter で要約（`stop`=1〜2 文 / `notification`=1 文、`text`+`reading`
     構造化出力。プロンプト・スキーマは irodori-tts-docker coordinator から忠実移植）
   - `reading`（英単語→カタカナ版）を `tts_say.sh` で読み上げ
3. 鍵欠如/要約失敗時の graceful degrade:
   - notification → 生メッセージをそのまま読み上げ
   - stop/subagent_stop → ドロップ（assistant 本文は長大になりうるため生読みしない）

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

### 2. TTS バックエンド

`stt-tts-runpod` のローカルスタックを起動しておく:

```sh
cd ~/ghq/github.com/douhashi/stt-tts-runpod && scripts/local_serve.sh -d
```

### 3. インストール

```sh
/plugin marketplace add /path/to/dhs-claude-plugin-marketplace
/plugin install tts-notify@dhs-claude-plugin-marketplace
```

旧構成（`~/.claude/settings.json` の `tts-on-*.sh` を指す Stop/Notification/
SubagentStop フック）は**重複発火するので削除**すること。

## 設定（`~/.config/tts-notify/env` または環境変数）

| 変数 | 既定 | 説明 |
|---|---|---|
| `OPENROUTER_API_KEY` | （無し） | OpenRouter キー。未設定で要約 degrade |
| `OPENROUTER_MODEL` | `openai/gpt-5-mini` | 要約モデル |
| `OPENROUTER_URL` | `https://openrouter.ai/api/v1/chat/completions` | エンドポイント |
| `TTS_NOTIFY_SAY` | `~/ghq/github.com/douhashi/stt-tts-runpod/scripts/tts_say.sh` | 読み上げコマンド |
| `TTS_NOTIFY_PRESET` | `gena` | 声プリセット |
| `TTS_NOTIFY_VOLUME` | `50` | 音量 %（tts_say.sh の `TTS_VOLUME`） |
| `TTS_NOTIFY_CUE` | `default` | 開始効果音（tts_say.sh の `TTS_CUE`） |
| `TTS_NOTIFY_TRANSCRIPT_WAIT` | `5` | transcript フラッシュ待ち秒 |
| `TTS_NOTIFY_CACHE` | `~/.cache/tts-notify` | ロック/ログ置き場（`worker.log`） |

## デバッグ

`~/.cache/tts-notify/worker.log` を見る（`spoke` / `busy -> drop` /
`... -> drop` の理由が出る）。手動実行:

```sh
echo '{"message":"テスト"}' > /tmp/e.json
CLAUDE_PLUGIN_ROOT=$PWD/tts-notify tts-notify/bin/worker.sh notification /tmp/e.json
```
