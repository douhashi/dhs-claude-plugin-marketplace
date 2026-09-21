# エージェント仕様

## 概要

サブエージェントは特定のタスクを処理する特化した AI アシスタント。
独自のコンテキストウィンドウ、システムプロンプト、ツールアクセス、権限で実行される。

## ファイル形式

`agents/` ディレクトリに Markdown ファイルとして定義する。

```markdown
---
name: my-agent
description: エージェントの説明
tools: Read, Grep, Glob
model: sonnet
---

システムプロンプトをここに記述する。
```

## フロントマターフィールド

| フィールド | 必須 | 説明 |
|:--|:--|:--|
| `name` | はい | 一意の識別子（小文字・ハイフン） |
| `description` | はい | Claude がこのエージェントに委譲する条件。`use proactively` を含めると積極的に使用される |
| `tools` | いいえ | 使用可能なツール。省略時は全ツール継承 |
| `disallowedTools` | いいえ | 拒否するツール |
| `model` | いいえ | `sonnet`, `opus`, `haiku`, `inherit`（デフォルト: `inherit`） |
| `permissionMode` | いいえ | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan`（プラグインのエージェントでは無視される） |
| `maxTurns` | いいえ | 最大ターン数 |
| `skills` | いいえ | プリロードするスキル名リスト |
| `mcpServers` | いいえ | 利用可能な MCP サーバー（プラグインのエージェントでは無視される） |
| `hooks` | いいえ | ライフサイクルフック（プラグインのエージェントでは無視される） |
| `memory` | いいえ | 永続メモリスコープ: `user`, `project`, `local` |
| `background` | いいえ | `true` でバックグラウンド実行 |
| `isolation` | いいえ | `worktree` で git worktree 分離実行 |

プラグインのエージェントでは、セキュリティ上の理由で `hooks`・`mcpServers`・`permissionMode` が無視される。必要な場合はエージェントファイルを `.claude/agents/` か `~/.claude/agents/` にコピーして使う。

## 組み込みエージェント

| エージェント | モデル | 用途 |
|:--|:--|:--|
| **Explore** | Haiku | コードベース検索・分析（読み取り専用） |
| **Plan** | 継承 | プランモードでのコードベース研究 |
| **general-purpose** | 継承 | 複雑なマルチステップタスク |

## 永続メモリ

`memory` フィールドでセッション間の知識を蓄積できる。

| スコープ | 保存先 | 用途 |
|:--|:--|:--|
| `user` | `~/.claude/agent-memory/<name>/` | 全プロジェクト共通の知識 |
| `project` | `.claude/agent-memory/<name>/` | プロジェクト固有（バージョン管理可能） |
| `local` | `.claude/agent-memory-local/<name>/` | プロジェクト固有（gitignore） |

## フック

エージェントの frontmatter で直接定義するか、`settings.json` で `SubagentStart`/`SubagentStop` イベントを使う。

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
```

## 使い分け

- **メイン会話**: 頻繁なやり取り、反復的改善、素早い変更
- **サブエージェント**: 大量出力の分離、ツール制限の強制、自己完結型タスク
- **スキル**: メインコンテキストで実行する再利用可能プロンプト

サブエージェントは、既定でメイン会話から 3 層下まで自分のサブエージェントを生成できる。上限の層のサブエージェントには `Agent` ツールが渡されない。
深さは環境変数 `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` で変えられる（`1` で入れ子を禁止）。
特定のエージェントだけ生成を禁止するには、`tools` から `Agent` を外すか `disallowedTools` に入れる。

## ベストプラクティス

- 各エージェントは 1 つの特定タスクに特化させる
- description は Claude が委譲判断に使うため詳細に書く
- セキュリティのため必要最小限のツールアクセスに絞る
- プロジェクトエージェントはバージョン管理にチェックインしてチームで共有する

## 参考リンク

- https://code.claude.com/docs/ja/sub-agents.md
