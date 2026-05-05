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

### ローカルテスト（プラグイン単体）

```bash
claude --plugin-dir ./spira
```

### デバッグ

```bash
claude --debug --plugin-dir ./spira
```
