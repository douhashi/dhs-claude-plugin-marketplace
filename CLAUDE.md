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

- **開発環境セットアップ**: プロジェクトの初期セットアップを行うエージェント/スキル
- **開発サイクル自動化**: 計画・実装・レビューを自律的に回すエージェント/スキル
- **タスク管理**: `gh project` を操作するスキル群

## ドキュメント

- @docs/plugin-spec.md : Claude Code プラグインの仕様まとめ
- @docs/skills-spec.md : スキルの仕様と作成方法
- @docs/agents-spec.md : エージェントの仕様と作成方法
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
