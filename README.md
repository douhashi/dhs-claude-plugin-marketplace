# dhs-claude-plugin-marketplace

Claude Code プラグインのローカルマーケットプレイス。

## プラグイン一覧

| プラグイン | 説明 |
|:--|:--|
| [spira](./spira/) | 自律的な開発サイクル（設計 → 実装 → レビュー → QA）を支援するツール群 |
| [tts-notify](./tts-notify/) | Claude の Stop / Notification を hailer の broker へ渡し、音声読み上げ＋モバイル通知するフックプラグイン |

## セットアップ

### マーケットプレイスの登録

マーケットプレイスの登録は初回のみです。GitHub から登録する場合:

```
/plugin marketplace add douhashi/dhs-claude-plugin-marketplace
```

クローン済みの作業ツリーを使う場合は、そのパスを渡します。

```
/plugin marketplace add /path/to/dhs-claude-plugin-marketplace
```

### プラグインのインストール

```
/plugin install spira@dhs-claude-plugin-marketplace
/plugin install tts-notify@dhs-claude-plugin-marketplace
```

シェルからも同じことができます。

```bash
claude plugin marketplace add douhashi/dhs-claude-plugin-marketplace
claude plugin install spira@dhs-claude-plugin-marketplace
```

インストール後は Claude Code を再起動してください。

### 一括操作（クローン済みの場合）

`scripts/` のスクリプトが全プラグインをまとめて操作します。対象一覧は
`.claude-plugin/marketplace.json` から取得するため、プラグインを増やしても変更は要りません。
引数でプラグイン名を渡すと、それだけが対象になります。

```bash
scripts/install.sh              # 全プラグインを登録＋インストール
scripts/install.sh tts-notify   # 指定プラグインのみ
scripts/uninstall.sh            # 全プラグインをアンインストール
scripts/update.sh               # 全プラグインを入れ直し（uninstall → 登録 → install）
```

### チームへの共有

リポジトリの `.claude/settings.json` に以下を追加すると、リポジトリを信頼したメンバーに自動でマーケットプレイスが登録されます。
インストールは各自が「プラグインのインストール」の手順で行います（`enabledPlugins` を書いても自動インストールはされません）。

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
├── tts-notify/                # プラグイン: 通知の要約読み上げ（フック）
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── hooks/
│   ├── bin/
│   ├── lib/
│   └── README.md
├── scripts/                   # プラグインの一括インストール／更新
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

- ローカルマーケットプレイスは自動更新がデフォルト無効です。変更後は `scripts/update.sh` で入れ直してください（`/plugin uninstall` → `/plugin install` でも同じです）。
- プラグインコマンドはプラグイン名でネームスペースされます（例: `/spira:implement`）。

## ライセンス

MIT
