# テンプレート: 依存スキルの確認と導入

- **書き手**: explain スキル（Phase 1）
- **用途**: 図とページの見た目に使うデザインスキルが入っているかを確かめ、無ければユーザースコープへの導入を提案する
- **読み手**: ユーザー

## 依存スキル

| スキル | プラグイン | マーケットプレイス（GitHub） |
|:--|:--|:--|
| `diagram-design` | `diagram-design@diagram-design` | `cathrynlavery/diagram-design` |
| `ui-ux-pro-max:ui-ux-pro-max` | `ui-ux-pro-max@ui-ux-pro-max-skill` | `nextlevelbuilder/ui-ux-pro-max-skill` |

## 確認のしかた

1. このセッションで使えるスキルの一覧に、`diagram-design`（`diagram-design:diagram-design` の形でもよい）と `ui-ux-pro-max:ui-ux-pro-max` があるかを見る。あれば使える
2. 一覧に無いスキルは、`claude plugin list` でプラグインが入っているかを見る

| 一覧 | `claude plugin list` | 状態 |
|:--|:--|:--|
| ある | — | 使える |
| 無い | 入っていて有効 | 入っているが読み込まれていない（再起動が要る） |
| 無い | 入っていない・無効 | 入っていない |

## 導入の提案

使えないスキルごとに、状態と次のどちらかを本文に出す。

- **入っていない**: ユーザースコープに入れるコマンド

  ```bash
  claude plugin marketplace add <マーケットプレイス>
  claude plugin install <プラグイン> --scope user
  ```

- **入っているが読み込まれていない**: Claude Code の再起動が要ること

## 問い

承認・選択は、`${CLAUDE_PLUGIN_ROOT}/templates/ask-user-question.md` の規則に従って `AskUserQuestion` で聞く。

| 項目 | 内容 |
|:--|:--|
| `question` | 図解に使うスキルが使えません。どうしますか |
| `header` | `導入` |
| `options` | `導入する（推奨）`（ユーザースコープに入れ、再起動を案内して終える） / `導入せずに続ける`（代わりのスキルで図解する） / `ここで終える`（何もせずに終える） |

「入っているが読み込まれていない」だけのときは、`導入する（推奨）` を `再起動する（推奨）`（再起動を案内して終える）に置き換える。

| ユーザーの応答 | 行動 |
|:--|:--|
| `導入する` | 「導入の提案」のコマンドを実行し、`claude plugin list` で入ったことを確かめる。続けて、Claude Code を再起動してから同じ質問で `/spira:explain` を実行し直すよう案内して終える |
| `再起動する` | Claude Code を再起動してから同じ質問で `/spira:explain` を実行し直すよう案内して終える |
| `導入せずに続ける` | Phase 2 へ進み、Phase 7 で「導入せずに続けるとき」に従う |
| `ここで終える` | 以降の Phase を実行せずに終える |
| `Other`: 具体的な指示 | 指示に従う |

コマンドが失敗したら、出力をそのまま示して終える。

## 導入せずに続けるとき

| 使えないスキル | 代わり |
|:--|:--|
| `diagram-design` | `artifact-diagramming` を読み込み、その指針で図を描く |
| `ui-ux-pro-max:ui-ux-pro-max` | `artifact-design` の指針だけで見た目を決める |

ページの末尾（出典の節）に、代わりを使ったことを 1 行添える。
