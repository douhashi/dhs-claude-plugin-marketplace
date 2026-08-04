# Spira

Claude Code プラグインとして、自律的な開発サイクル（計画 → 実装 → PR 作成 → CI 監視・マージ）を支援するツール群を提供します。

## 特徴

- **開発サイクル自動化**: GitHub Issue を入力に、計画・実装・PR 作成・CI 監視・マージまでを一貫して自動実行
- **エージェント分業**: planner / implementer / po / qa / setup の 5 エージェントが役割を分担
- **Issue 駆動**: 全プロセスの結果が GitHub Issue にコメントとして記録される
- **ブレインストーミング**: 論点を洗い出し、1 つずつ対話で決着させ、ドキュメント更新と Issue 化まで繋ぐ対話型スキル
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

与えられたテーマについて論点を洗い出し、1 つずつ対話で決着させていきます。

1. **最新化** — `main` に移動して `git pull`
2. **情報収集** — 関連ドキュメント・コード・外部仕様を調べる（調査結果は列挙せず論点に落とす）
3. **質問** — 埋まらなかった不明点をユーザーに聞く（最大 3 つ）
4. **論点の洗い出し** — 論点テーブルを出力（重要な順、最大 7 行）
5. **議論** — `議論中` の論点を 1 つだけ扱う。1 応答 400 字以内・質問は 1 つ
6. **テーブル更新** — 結論を書き込み全体を再掲し、次の論点へ
7. **ドキュメント更新** — 全論点決着後、確認のうえ `spira:update-doc` を呼び出しマージまで行う
8. **Issue 化の提案** — マージ後、確認のうえ `spira:create-issue` を呼び出す（候補の提示と承認は create-issue 側で行う）

論点の状態は `未着手` / `議論中` / `解決` / `保留` の 4 つ。`議論中` は常に 1 つだけ存在します。

```bash
/spira:brainstorming 通知機能の改善
```

出力の書式と分量は `skills/brainstorming/templates/` で定義しています。

| 出力 | テンプレート | 上限 |
|:--|:--|--:|
| 論点テーブル | `discussion-points.md` | 7 行 |
| 1 論点の提示・議論 | `dialogue.md` | 400 字／応答 |
| 議論の結論 | `summary.md` | 800 字 |

### `/spira:update-doc <更新対象または指示>`

ドキュメントを更新し、PR を作成してマージします。

1. **対象の特定** — 更新対象ファイルと反映内容を整理
2. **ブランチ作成** — `main` を最新化し `docs/<slug>` を切る
3. **更新** — 既存フォーマットに従って編集し、差分を提示して PR 作成の承認を得る
4. **PR 作成** — コミット・push・`gh pr create`
5. **CI 監視・マージ** — 全チェック通過後に squash マージ（失敗時はマージせず報告）

git リポジトリでない場合やリモート・`gh` 認証が無い場合は、ローカル編集までで終了します。

```bash
/spira:update-doc docs/conventions.md にブランチ命名規則を追記
```

### `/spira:create-issue [owner/repo]`

議論結果や指示に基づいて GitHub Issue を起票します。**承認前に起票しません。**

1. **内容の整理** — 会話の文脈から関心事ごとに分割
2. **提示と承認** — 作成予定 Issue を一覧表で提示し、承認を待つ
3. **本文の作成** — `templates/issue-body.md` に沿って本文を書き、`wc -m` で 1,500 字以内を確認
4. **起票** — 承認された表の全行を `gh issue create` で作成
5. **報告** — 1 行 1 件で URL を提示

承認段階で提示するのは次の表だけです。本文の全文は、ユーザーが求めた Issue の分だけ提示します。

| # | タイトル | 目的 | 完了条件 |
|:--|:--|:--|:--|
| 1 | 論点テーブルに状態列を追加 | 議論の進捗が追えない | 状態 4 種が表で判別できる |
| 2 | update-doc に PR 作成を追加 | 更新が手作業で止まる | PR 作成からマージまで自動で回る |

承認は表全体に対して行い、承認されたら全行を起票します。粒度・分割・統合などの調整が入った場合は、
一部だけ起票せずに表を作り直して再提示し、改めて承認を得ます。

```bash
/spira:create-issue douhashi/dhs-claude-plugin-marketplace
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
│   │   ├── SKILL.md
│   │   └── templates/     # 論点テーブル・対話・結論のテンプレート
│   ├── create-issue/      # Issue 起票
│   │   ├── SKILL.md
│   │   └── templates/     # 作成予定 Issue 一覧のテンプレート
│   ├── decide/            # 設計判断
│   ├── do/                # 一気通貫サイクル
│   ├── implement/         # 実装サイクル
│   ├── pick/              # 次タスク抽出
│   ├── plan/              # 計画策定
│   └── update-doc/        # ドキュメント更新・PR・マージ
├── agents/
│   ├── planner.md         # 計画エージェント
│   ├── implementer.md     # 実装エージェント
│   ├── po.md              # 設計判断エージェント
│   ├── qa.md              # QA・CI 監視エージェント
│   └── setup.md           # 環境構築エージェント
├── templates/             # Issue 本文・コメントのテンプレート
│   ├── _rules.md          # 共通ルール・字数上限一覧・投稿手順
│   ├── issue-body.md
│   ├── implementation-plan.md
│   ├── plan-revision.md
│   ├── design-decision.md
│   ├── implementation-result.md
│   ├── qa-result.md
│   └── completion-report.md
└── README.md
```

## Issue の記述量

spira が Issue に書き込む本文・コメントは、`templates/` 配下のテンプレートで書式と字数上限が
定義されています。スキル・エージェントは投稿前に `wc -m` で字数を確認し、上限を超えた内容は投稿しません。

| 書き込み先 | 上限 |
|:--|--:|
| Issue 本文 | 1,500 字 |
| `## 実装計画` | 2,500 字 |
| `## 設計判断` | 800 字／論点 |
| `## 計画の修正` | 500 字 |
| `## 実装内容` | 1,200 字 |
| `## 設計判断に基づく修正` / `## CI 修正 (N回目)` | 500 字 |
| `## QA 結果` / `## CI 失敗 (N回目)` | 300 字 |
| `## 完了報告` | 500 字 |

PO 判断の反映や CI 修正は**差分のみ**を記録し、実装計画・実装内容の全文再掲は行いません。
上限を変更する場合は `templates/_rules.md` と各テンプレートを更新してください。

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
