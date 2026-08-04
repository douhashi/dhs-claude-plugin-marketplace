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
│   │   ├── implement/
│   │   │   └── SKILL.md
│   │   ├── pick/
│   │   │   └── SKILL.md
│   │   ├── plan/
│   │   │   └── SKILL.md
│   │   ├── update-doc/
│   │   │   └── SKILL.md
│   │   └── ...
│   ├── agents/
│   │   ├── planner.md
│   │   ├── implementer.md
│   │   ├── po.md
│   │   ├── qa.md
│   │   └── setup.md
│   ├── hooks/
│   │   └── hooks.json
│   ├── templates/             # Issue 本文・コメントのテンプレート（SSoT）
│   │   ├── _rules.md
│   │   ├── issue-body.md
│   │   ├── implementation-plan.md
│   │   ├── plan-revision.md
│   │   ├── design-decision.md
│   │   ├── implementation-result.md
│   │   ├── qa-result.md
│   │   └── completion-report.md
│   ├── scripts/
│   │   └── ...
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
  - 複数スキル／エージェントで共有する書式（Issue 本文・コメント）は `spira/templates/` に置き、`${CLAUDE_PLUGIN_ROOT}/templates/<name>.md` で参照する
  - 単一スキル専用の書式は `spira/skills/<skill>/templates/` に置き、相対 markdown リンクで参照する

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
- フックからは `${CLAUDE_PLUGIN_ROOT}/scripts/...` で参照する

## コミットメッセージ

変更の目的を簡潔に記述する。

## テスト

機能追加・変更後は必ず `claude --plugin-dir .` でローカルテストを行う。
