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

## 応答

「導入の提案」の最後に、選べる行動（入っていない: `導入する` / `導入せずに続ける` / `ここで終える`、入っているが読み込まれていない: `再起動する` / `導入せずに続ける` / `ここで終える`）を示し、ユーザーの判断を待つ。

| ユーザーの応答 | 行動 |
|:--|:--|
| `導入する` | 「導入の提案」のコマンドを実行し、`claude plugin list` で入ったことを確かめる。続けて、Claude Code を再起動してから同じ質問で `/spira:explain` を実行し直すよう案内して終える |
| `再起動する` | Claude Code を再起動してから同じ質問で `/spira:explain` を実行し直すよう案内して終える |
| `導入せずに続ける` | Phase 2 へ進み、Phase 7 で「導入せずに続けるとき」に従う |
| `ここで終える` | 以降の Phase を実行せずに終える |
| それ以外の具体的な指示 | 指示に従う |

コマンドが失敗したら、出力をそのまま示して終える。

## 導入せずに続けるとき

| 使えないスキル | 代わり |
|:--|:--|
| `diagram-design` | `artifact-diagramming` を読み込み、その指針で図を描く |
| `ui-ux-pro-max:ui-ux-pro-max` | `artifact-design` の指針だけで見た目を決める |

ページの末尾（出典の節）に、代わりを使ったことを 1 行添える。
