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
│   │   └── <skill>/
│   │       ├── SKILL.md
│   │       ├── sets/         # そのスキルが判断に使う材料（任意。例: architect のアーキテクチャセット）
│   │       └── templates/    # そのスキル専用の出力テンプレート（任意）
│   ├── agents/
│   ├── templates/            # Issue 本文・コメントのテンプレート（プラグイン共通）
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

- **ブレインストーミング**: 論点を洗い出し、1 つずつ対話で決着させ、Issue 化とドキュメント更新まで繋ぐスキル（`spira:brainstorming`）
- **構成決め**: 同梱のアーキテクチャセットを叩き台に、要件の根拠と調査の出典を添えて構成と配布先を提案し、承認後に `spira:update-doc` で `docs/architecture.md` に残してから `spira:create-issue` で構成の立ち上げ Issue を起票するスキル（`spira:architect`）
- **Issue 作成**: 作成予定 Issue を一覧表で提示し、承認を得てから起票し、ロードマップの適切な位置に追記して PR→マージまで行うスキル（`spira:create-issue`）
- **フィードバック**: フィードバックの内容を確認・調査し、起票が必要なら `spira:create-issue` で Issue を起票してロードマップを更新するスキル（`spira:feedback`）
- **ドキュメント更新**: ドキュメントを更新し、PR 作成から CI 通過後のマージまで行うスキル（`spira:update-doc`）
- **設計判断**: コードベースとドキュメントを調査し、PO視点で設計判断を下すスキル
- **開発環境セットアップ**: `mise install` と `mise run setup` で整う環境を構築し、人手の設定が必要な値では Infisical のプレースホルダ作成（無ければ設定箇所の案内）と `## 人手対応待ち` の記録をして止まるエージェント（`spira:setup`）
- **計画策定**: GitHub Issue に基づいて実装計画を作成するスキル（`spira:plan`）
- **実装サイクル**: 計画済み Issue を入力に、実装・PR 作成・CI 監視を自律実行するスキル（`spira:implement`）
- **一気通貫サイクル**: 計画から PR マージまでを単一フローで実行するスキル（`spira:do`）
- **次タスク抽出**: 対応すべき Issue を 1 件抽出するスキル（`spira:pick`）
- **自走開発**: 前提条件（必要な環境変数と、その置き場所の Infisical または `.env`。Infisical は `.infisical.json` のデフォルトブランチへのコミットまで求める。必要なシークレットが 0 件なら置き場所の検査は飛ばす）を検査し、ロードマップのずれを直す PR をマージし、ロードマップ未記載の Issue を一緒に整理してからループ開発のコンテキストを `.tmp` に書き出すスキル（`spira:autopilot`）と、それに従い `spira:pick` → `spira:do` を最大 3 ラインで回し、ループ中に見つかったシステムを壊す不具合のロードマップへの追加と、ループ終了時のロードマップの整合修正（PR→マージ）を行いながら表で進捗を報告するエージェント（`spira:orchestrator`）。ラインは orchestrator の報告の `LAUNCH:` 行を受けてメインセッションが起動するバックグラウンドの `general-purpose` サブエージェントで（`bypassPermissions` 前提）、完了通知を `lines/N.done` に書いて回収し、会話記録 `subagents/agent-<agentId>.jsonl` で事後調査できる
- **タスク管理**: `gh project` を操作するスキル群

### tts-notify

Claude の Stop / Notification を hailer の broker（`POST /announce`）へ渡し、
音声読み上げ＋モバイル通知するフックプラグイン。

- **薄い共通ディスパッチャ**: 2 イベントを単一 `dispatch.sh` に集約、`setsid`
  でデタッチして即 return（Claude を非ブロッキング）。常駐サービス不要
- **要約しない・秘密を持たない**: 生テキストと task 名を broker へ渡すだけ。口調
  （persona）・声・変換ルール・要約モデル・鍵・失敗時の degrade はすべて broker の責務
- **今ターンの本文の特定**: transcript は遅延フラッシュされ、hook 発火時点では最終
  本文がまだファイルに無い。`lib/extract.py` が「今ターンのものか」を判定し、確定
  するまでバウンド付きで待つ（素朴に末尾を採ると常に 1 つ前のメッセージを読む）
- **単一フライト**: atomic な `mkdir` ロックで、抽出〜POST 中の新イベントはドロップ（先がち）
- 詳細は `tts-notify/README.md`

## ドキュメント

- @docs/plugin-spec.md : Claude Code プラグインの仕様まとめ
- @docs/skills-spec.md : スキルの仕様と作成方法
- @docs/agents-spec.md : エージェントの仕様と作成方法
- @docs/skill-format.md : スキルのセクション構造フォーマット定義
- @docs/agent-format.md : エージェントのセクション構造フォーマット定義
- @docs/conventions.md : このプロジェクトの規約
- @docs/issue-format.md : Issue 本文・コメントの書式と記述量の制約

## 開発指針

- **コードとドキュメントの同期**: スキル・エージェント・フック等を追加・変更・削除した場合は、対応する `docs/` 配下のドキュメントも必ず同時に更新する。コードだけ変更してドキュメントを放置しない。
- **計画時のドキュメント更新**: 実装計画を立てる際は、影響するドキュメントの更新タスクを必ず計画に含める。
- **Issue 記述はテンプレートに従う**: Issue 本文・コメントの書式と字数上限は `spira/templates/` が単一ソース。スキル・エージェント本文に書式を直書きしない。
- **スキルの出力もテンプレートに従う**: 特定スキルでしか使わない出力書式は `spira/skills/<skill>/templates/` に置き、SKILL.md からは相対リンクで参照する。SKILL.md 本文に書式を直書きしない。

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
