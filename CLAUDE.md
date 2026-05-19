# dhs-claude-plugin-marketplace

Claude Code プラグインのローカルマーケットプレイス。

## マーケットプレイス構成

```
dhs-claude-plugin-marketplace/
├── .claude-plugin/
│   └── marketplace.json      # マーケットプレイスマニフェスト
├── spira/                    # プラグイン: 自律的開発サイクル支援
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── skills/
│   ├── agents/
│   └── README.md
├── tts-notify/               # プラグイン: 通知の要約読み上げ（フック）
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── hooks/
│   ├── bin/
│   ├── lib/
│   └── README.md
├── docs/                     # ドキュメント
└── CLAUDE.md
```

## プラグイン一覧

### spira

自律的な開発サイクルを支援するツール群を提供する Claude Code プラグイン。

- **ブレインストーミング**: テーマについて深く議論し、要求を定義するスキル
- **Issue 作成**: 議論結果や指示に基づいて GitHub Issue を起票するスキル
- **ドキュメント更新**: 議論結果や指示に基づいてドキュメントを更新するスキル
- **設計判断**: コードベースとドキュメントを調査し、PO視点で設計判断を下すスキル
- **開発環境セットアップ**: プロジェクトの初期セットアップを行うエージェント/スキル
- **計画策定**: GitHub Issue に基づいて実装計画を作成するスキル（`spira:plan`）
- **実装サイクル**: 計画済み Issue を入力に、実装・PR 作成・CI 監視を自律実行するスキル（`spira:implement`）
- **一気通貫サイクル**: 計画から PR マージまでを単一フローで実行するスキル（`spira:do`）
- **次タスク抽出**: 対応すべき Issue を 1 件抽出するスキル（`spira:pick`）
- **タスク管理**: `gh project` を操作するスキル群

### tts-notify

Claude の Stop / SubagentStop / Notification を OpenRouter で短く要約し、
ローカル TTS（stt-tts-runpod の `tts_say.sh`）で読み上げるフックプラグイン。

- **薄い共通ディスパッチャ**: 3 イベントを単一 `dispatch.sh` に集約、`setsid`
  でデタッチして即 return（Claude を非ブロッキング）。常駐サービス不要
- **要約**: OpenRouter 構造化出力（プロンプト/スキーマは irodori-tts-docker
  coordinator から忠実移植）。鍵は `~/.config/tts-notify/env`（リポ外・600）
- **単一フライト**: `flock -n` で再生/要約中の新イベントはドロップ（先がち）
- 詳細は `tts-notify/README.md`

## ドキュメント

- @docs/plugin-spec.md : Claude Code プラグインの仕様まとめ
- @docs/skills-spec.md : スキルの仕様と作成方法
- @docs/agents-spec.md : エージェントの仕様と作成方法
- @docs/skill-format.md : スキルのセクション構造フォーマット定義
- @docs/agent-format.md : エージェントのセクション構造フォーマット定義
- @docs/conventions.md : このプロジェクトの規約

## 開発指針

- **コードとドキュメントの同期**: スキル・エージェント・フック等を追加・変更・削除した場合は、対応する `docs/` 配下のドキュメントも必ず同時に更新する。コードだけ変更してドキュメントを放置しない。
- **計画時のドキュメント更新**: 実装計画を立てる際は、影響するドキュメントの更新タスクを必ず計画に含める。

## 開発

### マーケットプレイス登録

```bash
/plugin marketplace add /path/to/dhs-claude-plugin-marketplace
```

### プラグインインストール

```bash
/plugin install spira@dhs-claude-plugin-marketplace
```

### スクリプト一括操作（`scripts/`）

`claude plugin` CLI を叩くシェルスクリプト。**引数なしで全プラグイン対象**
（対象一覧は `.claude-plugin/marketplace.json` の `.plugins[].name` から動的
取得＝単一ソース。プラグイン追加時もスクリプト変更不要）。引数でプラグインを
指定するとそれだけが対象。共通処理は `scripts/lib.sh` に集約。

```bash
scripts/install.sh              # 全プラグインを登録＋インストール
scripts/install.sh tts-notify   # 指定プラグインのみ
scripts/uninstall.sh            # 全プラグインをアンインストール
scripts/update.sh               # 全プラグインを入れ直し（uninstall→登録→install）
```

実行後は Claude Code の再起動が必要。

### ローカルテスト（プラグイン単体）

```bash
claude --plugin-dir ./spira
```

### デバッグ

```bash
claude --debug --plugin-dir ./spira
```
