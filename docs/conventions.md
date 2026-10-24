# プロジェクト規約

## 命名規則

- プラグイン名: `spira`
- スキル名: kebab-case（例: `setup-dev`, `run-cycle`）
- エージェント名: kebab-case（例: `planner`, `code-reviewer`）
- スクリプト: kebab-case（例: `validate-query.sh`）

## スキル名前空間

プラグインとしてインストールされた場合、全スキルに `spira:` が接頭辞として付く。

- `/spira:setup-dev`
- `/spira:implement`

## ディレクトリ構造

```
dhs-claude-plugin-marketplace/
├── .claude-plugin/
│   └── marketplace.json       # マーケットプレイスマニフェスト
├── spira/                     # プラグイン本体
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── skills/
│   │   ├── autopilot/
│   │   │   ├── SKILL.md
│   │   │   └── templates/     # コンテキスト・状態・報告・案内のテンプレート
│   │   ├── architect/
│   │   │   ├── SKILL.md
│   │   │   ├── sets/          # 判断の材料（アーキテクチャセット・配布先の判定）
│   │   │   │   ├── _deploy.md
│   │   │   │   ├── web.md
│   │   │   │   ├── api.md
│   │   │   │   ├── cli.md
│   │   │   │   ├── desktop.md
│   │   │   │   └── mobile.md
│   │   │   └── templates/     # 出力の書式
│   │   │       ├── architecture-set.md
│   │   │       ├── proposal.md
│   │   │       └── architecture-doc.md
│   │   ├── brainstorming/
│   │   │   ├── SKILL.md
│   │   │   └── templates/     # スキル固有の出力テンプレート
│   │   │       ├── discussion-points.md
│   │   │       ├── dialogue.md
│   │   │       └── summary.md
│   │   ├── create-issue/
│   │   │   ├── SKILL.md
│   │   │   └── templates/
│   │   │       └── issue-plan.md
│   │   ├── decide/
│   │   │   └── SKILL.md
│   │   ├── do/
│   │   │   └── SKILL.md
│   │   ├── explain/
│   │   │   ├── SKILL.md
│   │   │   └── templates/
│   │   │       ├── dependencies.md
│   │   │       ├── facts.md
│   │   │       └── page.md
│   │   ├── implement/
│   │   │   └── SKILL.md
│   │   ├── pick/
│   │   │   └── SKILL.md
│   │   ├── mockup/
│   │   │   ├── SKILL.md
│   │   │   └── templates/
│   │   │       ├── proposal.md
│   │   │       ├── mockup.md
│   │   │       ├── design-system.md
│   │   │       └── visualization.md
│   │   ├── plan/
│   │   │   └── SKILL.md
│   │   ├── request/
│   │   │   ├── SKILL.md
│   │   │   └── templates/
│   │   │       └── investigation-report.md
│   │   ├── sync-roadmap/
│   │   │   ├── SKILL.md
│   │   │   └── templates/
│   │   │       └── roadmap-triage.md
│   │   ├── update-doc/
│   │   │   └── SKILL.md
│   │   └── ...
│   ├── agents/
│   │   ├── orchestrator.md
│   │   ├── planner.md
│   │   ├── implementer.md
│   │   ├── po.md
│   │   ├── qa.md
│   │   └── setup.md
│   ├── hooks/
│   │   └── hooks.json
│   ├── templates/             # Issue 本文・コメント・コミット/PR・承認の問いのテンプレート（SSoT）
│   │   ├── _rules.md
│   │   ├── issue-body.md
│   │   ├── commit-and-pr.md
│   │   ├── implementation-plan.md
│   │   ├── plan-revision.md
│   │   ├── design-decision.md
│   │   ├── implementation-result.md
│   │   ├── qa-result.md
│   │   ├── blocked.md
│   │   ├── roadmap-pr.md
│   │   ├── ask-user-question.md  # 承認・選択を AskUserQuestion で聞くときの共通規則
│   │   └── completion-report.md
│   ├── scripts/               # スキル・エージェントが共有するシェルスクリプト
│   │   ├── clean-line.sh      # 中断・失敗したラインの impl-N を片付ける。Orca の */impl-N はワークツリーを残して既定ブランチに戻す（autopilot / orchestrator 共通）
│   │   ├── finish-line.sh     # 完了した Orca のラインのワークツリー impl-N とブランチ */impl-N を削除する（orchestrator）
│   │   └── check-ask-material.sh  # 判断材料を本文に出さずに AskUserQuestion を呼んだら拒否する（PreToolUse フック）
│   └── README.md
├── docs/
│   ├── plugin-spec.md
│   ├── skills-spec.md
│   ├── agents-spec.md
│   ├── issue-format.md
│   └── conventions.md
└── CLAUDE.md
```

## スキル設計方針

- 副作用のあるスキル（デプロイ、コミット等）は `disable-model-invocation: true` を設定
- 読み取り専用のスキルは `allowed-tools` で制限する
- 大きなスキルは `SKILL.md` を 500 行以下に保ち、サポートファイルに分離する
- `description` にはユーザーが自然に使うキーワードを含める
- 出力の書式・分量の定義は SKILL.md 本文に直書きせず、テンプレートファイルに分離する
  - 複数スキル／エージェントで共有する書式（Issue 本文・コメント・ロードマップ PR）は `spira/templates/` に置き、`${CLAUDE_PLUGIN_ROOT}/templates/<name>.md` で参照する
  - 単一スキル専用の書式は `spira/skills/<skill>/templates/` に置き、相対 markdown リンクで参照する
- ユーザーの承認・選択を待つ箇所は、表や提案を本文に出し、問いだけを `AskUserQuestion` で聞く。本文のテキストで聞いてターンを終えない
  - 判断材料（表・提案・URL・質問の背景）を本文に出していない応答で `AskUserQuestion` を呼ばない。ダイアログには問いと選択肢しか出ないため。`spira/hooks/hooks.json` の `PreToolUse` フックが、直前に本文のテキストが無い呼び出しを拒否する
  - 問いの共通規則（問いの数・選択肢の数・`header` の長さ・推奨の置き方・`Other` の扱い）と、複数スキルで同じ形になる問い（未コミットの変更の確認）は `spira/templates/ask-user-question.md` に置く
  - 各スキルの問いの文・選択肢・回答ごとの行動は、そのスキルのテンプレートに「問い」の節として置く
  - `allowed-tools` に `AskUserQuestion` を足さない（許可なしで使えるツールであり、足さなくても呼び出せる）
- スキルが判断に使う材料（例: architect のアーキテクチャセット）は `spira/skills/<skill>/sets/` に置き、出力の書式を置く `templates/` と分ける

## エージェント設計方針

- 1 エージェント = 1 責務
- 読み取り専用タスクには `tools` でファイル編集を除外する
- 複雑な検証にはフックを活用する

## Issue テンプレート

- Issue 本文・コメントの書式と字数上限は `spira/templates/` 配下の markdown ファイルが単一ソース
- スキル・エージェントの本文に書式を直書きしない。`${CLAUDE_PLUGIN_ROOT}/templates/<name>.md` を参照させる
- 投稿は `--body-file` を使い、直前に `wc -m` で上限を確認する
- 詳細は @docs/issue-format.md

## スクリプト

- `scripts/` ディレクトリに配置
- shebang 行を含める（`#!/bin/bash` or `#!/usr/bin/env bash`）
- 実行権限を付与する（`chmod +x`）
- フック・スキル・エージェントからは `${CLAUDE_PLUGIN_ROOT}/scripts/...` で参照する

## コミットメッセージ

Conventional Commits スタイル（`<type>(<scope>): <説明>`）で書く。

- `type` の一覧と使い分けは `spira/skills/create-issue/templates/issue-plan.md` の「タイトルの書式」節が単一ソース
- implement / do が作るコミット・PR の書式は `spira/templates/commit-and-pr.md` が単一ソース
- 実装コミットと PR タイトルは、元 Issue のタイトルをそのまま使う

## テスト

機能追加・変更後は必ず `claude --plugin-dir .` でローカルテストを行う。
