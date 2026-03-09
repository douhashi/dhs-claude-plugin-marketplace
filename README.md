# dhs-claude-plugin-marketplace

Claude Code プラグインのローカルマーケットプレイス。

## プラグイン一覧

| プラグイン | 説明 |
|:--|:--|
| [spira](./spira/) | 自律的な開発サイクル（設計 → 実装 → レビュー → QA）を支援するツール群 |

## セットアップ

### マーケットプレイスの登録

Claude Code 起動後、以下のコマンドでマーケットプレイスを登録します（初回のみ）。

```bash
/plugin marketplace add /path/to/dhs-claude-plugin-marketplace
```

### プラグインのインストール

```bash
/plugin install spira@dhs-claude-plugin-marketplace
```

### チームへの共有

リポジトリの `.claude/settings.json` に以下を追加すると、リポジトリを信頼したメンバーに自動でマーケットプレイスが登録されます。

```json
{
  "extraKnownMarketplaces": {
    "dhs-claude-plugin-marketplace": {
      "source": {
        "source": "github",
        "repo": "douhashi/dhs-claude-plugin-marketplace"
      }
    }
  }
}
```

## ディレクトリ構成

```
dhs-claude-plugin-marketplace/
├── .claude-plugin/
│   └── marketplace.json       # マーケットプレイスマニフェスト
├── spira/                     # プラグイン: 自律的開発サイクル支援
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── skills/
│   ├── agents/
│   └── README.md
└── docs/
```

## 開発

### ローカルテスト（プラグイン単体）

```bash
claude --plugin-dir ./spira
```

### デバッグ

```bash
claude --debug --plugin-dir ./spira
```

プラグインに変更を加えた場合は Claude Code を再起動して反映させてください。

### 注意事項

- ローカルマーケットプレイスは自動更新がデフォルト無効です。変更後は `/plugin uninstall` → `/plugin install` で再インストールしてください。
- プラグインコマンドはプラグイン名でネームスペースされます（例: `/spira:implement`）。

## ライセンス

MIT
