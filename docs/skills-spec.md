# スキル仕様

## 概要

スキルは `SKILL.md` ファイルに指示を記述することで Claude の機能を拡張する。
ユーザーが `/skill-name` で呼び出すか、Claude が関連する場合に自動的に使用する。

## ディレクトリ構成

```
skills/
└── my-skill/
    ├── SKILL.md           # メイン指示（必須）
    ├── reference.md       # 参照資料（オプション）
    ├── examples/          # 出力例（オプション）
    └── scripts/           # ユーティリティスクリプト（オプション）
```

プラグイン内では `plugin-name:skill-name` の名前空間が付く。

## SKILL.md のフロントマター

```yaml
---
name: my-skill
description: スキルの説明
argument-hint: "[引数のヒント]"
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Grep, Glob
model: sonnet
context: fork
agent: Explore
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
---

ここにスキルの指示を書く。
```

### フィールド一覧

| フィールド | 必須 | 説明 |
|:--|:--|:--|
| `name` | いいえ | 表示名。省略時はディレクトリ名。小文字・数字・ハイフンのみ（最大 64 文字） |
| `description` | 推奨 | 何をするか、いつ使うか。Claude が自動読み込みの判断に使用 |
| `argument-hint` | いいえ | オートコンプリートで表示するヒント |
| `disable-model-invocation` | いいえ | `true` で Claude の自動呼び出しを無効化 |
| `user-invocable` | いいえ | `false` で `/` メニューから非表示 |
| `allowed-tools` | いいえ | スキル実行中に許可なしで使えるツール |
| `model` | いいえ | 使用するモデル |
| `context` | いいえ | `fork` でサブエージェントとして実行 |
| `agent` | いいえ | `context: fork` 時のエージェントタイプ（`Explore`, `Plan`, `general-purpose` 等） |
| `hooks` | いいえ | スキルライフサイクルにスコープされたフック |

## 呼び出し制御

| 設定 | ユーザーが呼び出せる | Claude が呼び出せる |
|:--|:--|:--|
| デフォルト | Yes | Yes |
| `disable-model-invocation: true` | Yes | No |
| `user-invocable: false` | No | Yes |

## 引数

`$ARGUMENTS` で全引数を取得。位置引数は `$ARGUMENTS[0]` または `$0` でアクセス。

```yaml
---
name: fix-issue
description: GitHub issue を修正する
---

Fix GitHub issue $ARGUMENTS following our coding standards.
```

`/fix-issue 123` → `$ARGUMENTS` が `123` に展開される。

## 動的コンテキスト注入

`` !`command` `` 構文でスキル読み込み前にシェルコマンドを実行し、結果を埋め込む。

```yaml
---
name: pr-summary
context: fork
agent: Explore
---

PR diff: !`gh pr diff`
Changed files: !`gh pr diff --name-only`
```

## 文字列置換

| 変数 | 説明 |
|:--|:--|
| `$ARGUMENTS` | 全引数 |
| `$ARGUMENTS[N]` / `$N` | N番目の引数（0ベース） |
| `${CLAUDE_SESSION_ID}` | 現在のセッション ID |

## ベストプラクティス

- `SKILL.md` は 500 行以下に保つ。詳細はサポートファイルに分離する
- description にユーザーが自然に使うキーワードを含める
- 副作用のあるスキルには `disable-model-invocation: true` を設定
- `context: fork` はタスク指示を含むスキルにのみ使う（ガイドラインのみのスキルには不向き）

## 参考リンク

- https://code.claude.com/docs/ja/skills.md
