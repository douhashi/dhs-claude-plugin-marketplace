# Claude Code プラグイン仕様

## 概要

プラグインは Claude Code をカスタム機能で拡張する自己完結型のコンポーネントディレクトリ。
スキル、エージェント、フック、MCP サーバー、LSP サーバーを含めることができる。

## ディレクトリ構造

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json           # マニフェスト（オプション）
├── skills/                   # スキル（SKILL.md を含むディレクトリ）
├── commands/                 # コマンド（レガシー。新規は skills/ を使う）
├── agents/                   # エージェント定義（Markdown）
├── hooks/
│   └── hooks.json            # フック設定
├── settings.json             # デフォルト設定
├── .mcp.json                 # MCP サーバー設定
├── .lsp.json                 # LSP サーバー設定
└── scripts/                  # ユーティリティスクリプト
```

**重要**: `commands/`, `agents/`, `skills/`, `hooks/` は `.claude-plugin/` の外、プラグインルートに配置する。

## マニフェスト（plugin.json）

`.claude-plugin/plugin.json` にプラグインのメタデータを定義する。省略時はデフォルト場所から自動検出される。

### 必須フィールド

| フィールド | 型 | 説明 |
|:--|:--|:--|
| `name` | string | 一意の識別子（kebab-case）。スキルの名前空間になる |

### メタデータフィールド

| フィールド | 型 | 説明 |
|:--|:--|:--|
| `version` | string | セマンティックバージョン（例: `"1.0.0"`） |
| `description` | string | プラグインの説明 |
| `author` | object | `{ "name": "...", "email": "..." }` |
| `homepage` | string | ドキュメント URL |
| `repository` | string | ソースコード URL |
| `license` | string | ライセンス識別子 |
| `keywords` | array | 検索タグ |

### コンポーネントパスフィールド

カスタムパスはデフォルトディレクトリを**補足**する（置き換えない）。

| フィールド | 型 | 説明 |
|:--|:--|:--|
| `commands` | string\|array | 追加コマンドファイル/ディレクトリ |
| `agents` | string\|array | 追加エージェントファイル |
| `skills` | string\|array | 追加スキルディレクトリ |
| `hooks` | string\|array\|object | フック設定パスまたはインライン |
| `mcpServers` | string\|array\|object | MCP 設定パスまたはインライン |
| `lspServers` | string\|array\|object | LSP 設定パスまたはインライン |

パスはプラグインルートからの相対パスで `./` で始める。

### 環境変数

- `${CLAUDE_PLUGIN_ROOT}`: プラグインディレクトリへの絶対パス。フック・スクリプト内で使用する。

## フック

`hooks/hooks.json` または `plugin.json` 内にインラインで定義する。

### 利用可能なイベント

| イベント | 説明 |
|:--|:--|
| `PreToolUse` | ツール使用前 |
| `PostToolUse` | ツール使用成功後 |
| `PostToolUseFailure` | ツール使用失敗後 |
| `UserPromptSubmit` | プロンプト送信時 |
| `Stop` | Claude 停止時 |
| `SubagentStart` | サブエージェント開始時 |
| `SubagentStop` | サブエージェント停止時 |
| `SessionStart` / `SessionEnd` | セッション開始/終了時 |

### フックタイプ

- `command`: シェルコマンドを実行
- `prompt`: LLM でプロンプトを評価
- `agent`: ツール付きエージェントで検証

## MCP サーバー

`.mcp.json` に定義する。

```json
{
  "mcpServers": {
    "server-name": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/my-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
      "env": { "KEY": "value" }
    }
  }
}
```

## テスト

```bash
# ローカルテスト
claude --plugin-dir ./my-plugin

# 複数プラグイン同時読み込み
claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two

# デバッグ
claude --debug --plugin-dir ./my-plugin
```

## バージョン管理

セマンティックバージョニング（`MAJOR.MINOR.PATCH`）に従う。

- MAJOR: 破壊的変更
- MINOR: 後方互換の新機能
- PATCH: 後方互換のバグ修正

## 参考リンク

- https://code.claude.com/docs/ja/plugins.md
- https://code.claude.com/docs/ja/plugins-reference.md
