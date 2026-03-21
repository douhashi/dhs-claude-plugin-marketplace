# Spira

Claude Code プラグインとして、自律的な開発サイクル（設計 → 実装 → レビュー → QA）を支援するツール群を提供します。

## 特徴

- **開発サイクル自動化**: GitHub Issue を入力に、計画・実装・レビュー・PR 作成・CI 監視・マージまでを一貫して自動実行
- **エージェント分業**: planner / implementer / reviewer / qa / setup の 5 エージェントが役割を分担
- **Issue 駆動**: 全プロセスの結果が GitHub Issue にコメントとして記録される
- **ブレインストーミング**: テーマについて深く議論し、要求を定義する対話型スキル

## セットアップ

```bash
# リポジトリのクローン
git clone https://github.com/douhashi/spira.git

# プラグインとして読み込み
claude --plugin-dir /path/to/spira
```

## 使い方

### `/spira:brainstorming <テーマ>`

与えられたテーマについて深く議論し、要求を定義します。

- テーマの本質を掘り下げ、「何を実現すべきか」を明確にする
- ユーザーから求められた場合のみ、議論の結果を GitHub Issue として作成する

```bash
# 例: 通知機能についてブレインストーミング
/spira:brainstorming 通知機能の改善
```

### `/spira:implement <Issue番号>`

指定した GitHub Issue に対して、以下のサイクルを自動実行します。

1. **設計** (planner) — 要件分析・実装計画の作成
2. **実装** (implementer) — 計画に基づくコード変更
3. **レビュー** (reviewer) — テスト・lint 実行、コード品質の検証
4. **修正ループ** — レビュー指摘への対応（最大 5 回）
5. **PR 作成** — ワークツリーから Pull Request を作成
6. **QA・CI 修正ループ** (qa) — CI 監視・失敗時の自動修正・マージ（最大 5 回）
7. **完了報告** — Issue への最終レポート

```bash
# 例: Issue #42 の実装サイクルを開始
/spira:implement 42
```

## プロジェクト構成

```
spira/
├── .claude-plugin/
│   └── plugin.json        # プラグインマニフェスト
├── skills/
│   ├── brainstorming/
│   │   └── SKILL.md       # ブレインストーミングスキル
│   └── implement/
│       └── SKILL.md       # 開発サイクル自動化スキル
├── agents/
│   ├── planner.md         # 設計エージェント
│   ├── implementer.md     # 実装エージェント
│   ├── reviewer.md        # レビューエージェント
│   ├── qa.md              # QA・CI監視エージェント
│   └── setup.md           # 環境構築エージェント
├── docs/
│   ├── plugin-spec.md     # プラグイン仕様
│   ├── skills-spec.md     # スキル仕様
│   ├── agents-spec.md     # エージェント仕様
│   └── conventions.md     # プロジェクト規約
└── CLAUDE.md              # プロジェクト指示
```

## エージェント一覧

| エージェント | 役割 |
|:--|:--|
| **planner** | タスクの要件分析と実装計画の作成 |
| **implementer** | 計画に基づくコードの実装・修正 |
| **reviewer** | コードレビュー、テスト・lint 実行による品質検証 |
| **qa** | CI ステータス監視、全チェック通過後の自動マージ |
| **setup** | 開発環境の構築（ライブラリ、環境マネージャ、フレームワーク、CI） |

## 開発

### ローカルテスト

```bash
claude --plugin-dir .
```

### デバッグ

```bash
claude --debug --plugin-dir .
```

プラグインに変更を加えた場合は Claude Code を再起動して反映させてください。

## ライセンス

MIT
