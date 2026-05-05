# Spira

Claude Code プラグインとして、自律的な開発サイクル（計画 → 実装 → PR 作成 → CI 監視・マージ）を支援するツール群を提供します。

## 特徴

- **開発サイクル自動化**: GitHub Issue を入力に、計画・実装・PR 作成・CI 監視・マージまでを一貫して自動実行
- **エージェント分業**: planner / implementer / po / qa / setup の 5 エージェントが役割を分担
- **Issue 駆動**: 全プロセスの結果が GitHub Issue にコメントとして記録される
- **ブレインストーミング**: テーマについて深く議論し、要求を定義する対話型スキル
- **次タスク抽出**: `escalated` ラベルを優先しつつ、対応すべき Issue を 1 件選び出す

## セットアップ

### インストール

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
/spira:brainstorming 通知機能の改善
```

### `/spira:plan <Issue URL>`

指定した GitHub Issue について実装計画を作成します。`planned` ラベルが付与済みの場合はスキップします。

1. **計画策定済みチェック** — `planned` ラベルがあれば終了
2. **設計** (planner) — 要件分析・実装計画の作成
3. **設計判断** (po) — 論点があれば PO エージェントが集約判断（1 回呼び出し）
4. **ラベル付与** — `planned` ラベルを付与

```bash
/spira:plan https://github.com/owner/repo/issues/42
```

### `/spira:implement <Issue URL>`

`planned` 済みの Issue に対して実装サイクルを実行します。

1. **実装** (implementer / setup) — 計画に基づくコード変更／環境構築。PR 前に自己レビュー
2. **設計判断** (po) — 論点があれば PO エージェントが集約判断
3. **PR 作成** — ワークツリーから Pull Request を作成
4. **QA・CI 修正ループ** (qa) — CI 監視・失敗時の自動修正・マージ（最大 2 回）
   - 2 回失敗時は `escalated` ラベル付きでフォローアップ Issue を起票して終了
5. **完了報告** — Issue への最終レポート

```bash
/spira:implement https://github.com/owner/repo/issues/42
```

### `/spira:do <Issue URL>`

計画から PR マージまでを単一フローで実行します。`planned` ラベルがあれば計画フェーズをスキップして実装から開始します。

```bash
/spira:do https://github.com/owner/repo/issues/42
```

### `/spira:pick`

現在のリポジトリで、次に対応すべき Open な Issue を 1 件抽出します。
副作用なし（Issue・ラベルへの書き込みは行わない）。

優先順:

1. `escalated` ラベル付きの Open Issue（番号が若い順）
2. それ以外の Open Issue（番号が若い順）

出力（3 行、URL を最終行に置きチェイン可能）:

```
優先度: escalated
タイトル: <title>
URL: <url>
```

## プロジェクト構成

```
spira/
├── .claude-plugin/
│   └── plugin.json        # プラグインマニフェスト
├── skills/
│   ├── brainstorming/     # ブレインストーミング
│   ├── do/                # 一気通貫サイクル
│   ├── implement/         # 実装サイクル
│   ├── pick/              # 次タスク抽出
│   └── plan/              # 計画策定
├── agents/
│   ├── planner.md         # 計画エージェント
│   ├── implementer.md     # 実装エージェント
│   ├── po.md              # 設計判断エージェント
│   ├── qa.md              # QA・CI 監視エージェント
│   └── setup.md           # 環境構築エージェント
└── README.md
```

## エージェント一覧

| エージェント | 役割 |
|:--|:--|
| **planner** | タスクの要件分析と実装計画の作成 |
| **implementer** | 計画に基づくコードの実装・修正・PR 前自己レビュー |
| **po** | 設計判断（複数論点を集約して 1 回でまとめて判断） |
| **qa** | CI ステータス監視、全チェック通過後の自動マージ |
| **setup** | 開発環境の構築（ライブラリ、環境マネージャ、フレームワーク、CI） |

## ラベル

spira は以下のラベルを自動作成・運用します。

| ラベル | 色 | 意味 |
|:--|:--|:--|
| `planned` | 青 | 実装計画が策定済み |
| `escalated` | 赤 | 人手による対応が必要（自動修正の限界に達した） |

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
