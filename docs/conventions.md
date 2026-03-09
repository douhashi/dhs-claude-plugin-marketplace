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
│   │   ├── implement/
│   │   │   └── SKILL.md
│   │   └── ...
│   ├── agents/
│   │   ├── planner.md
│   │   ├── implementer.md
│   │   ├── reviewer.md
│   │   └── qa.md
│   ├── hooks/
│   │   └── hooks.json
│   ├── scripts/
│   │   └── ...
│   └── README.md
├── docs/
│   ├── plugin-spec.md
│   ├── skills-spec.md
│   ├── agents-spec.md
│   └── conventions.md
└── CLAUDE.md
```

## スキル設計方針

- 副作用のあるスキル（デプロイ、コミット等）は `disable-model-invocation: true` を設定
- 読み取り専用のスキルは `allowed-tools` で制限する
- 大きなスキルは `SKILL.md` を 500 行以下に保ち、サポートファイルに分離する
- `description` にはユーザーが自然に使うキーワードを含める

## エージェント設計方針

- 1 エージェント = 1 責務
- 読み取り専用タスクには `tools` でファイル編集を除外する
- 複雑な検証にはフックを活用する

## スクリプト

- `scripts/` ディレクトリに配置
- shebang 行を含める（`#!/bin/bash` or `#!/usr/bin/env bash`）
- 実行権限を付与する（`chmod +x`）
- フックからは `${CLAUDE_PLUGIN_ROOT}/scripts/...` で参照する

## コミットメッセージ

変更の目的を簡潔に記述する。

## テスト

機能追加・変更後は必ず `claude --plugin-dir .` でローカルテストを行う。
