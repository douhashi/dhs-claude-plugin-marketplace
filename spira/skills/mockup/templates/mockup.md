# テンプレート: モックアップの HTML

- **書き手**: mockup スキル（Phase 5 で作成し、Phase 8 で `docs/mockups/` に反映する）
- **用途**: 画面の見た目と振る舞いを、実装の手本として残す
- **読み手**: 開発者と planner・implementer などのエージェント（HTML をブラウザで開く・ソースを読む）

## 置き場所と名前

| ファイル | 内容 |
|:--|:--|
| `docs/mockups/<画面の slug>.html` | 1 画面 1 ファイル。slug は英小文字・ハイフン（例: `login`, `notification-list`） |
| `docs/mockups/README.md` | 画面の一覧（「一覧」節） |

作業中は `.tmp/spira-mockup/screens/<画面の slug>.html` に置き、提案ページ（[proposal.md](proposal.md)）に埋め込んで見せる。承認後に同じ内容を `docs/mockups/` に写す。

## HTML の規約

- 1 ファイルで完結させる。CSS と JavaScript はインラインで書き、外部から読むのは Web フォントだけにする
- 先頭に次のコメントを置く

  ```html
  <!--
    画面: （画面名）
    機能: （コンセプトの文書の path:line）
    状態: 通常 / 空 / 読み込み中 / エラー（描いたもの）
    デザインシステム: docs/development/design-system.md
  -->
  ```

- 色・書体・余白・角丸・影・動きの時間は `:root` の CSS 変数で定義し、名前はデザインシステムのトークン名と揃える。要素のスタイルに生の値を書かない
- 状態が複数あるときは、画面上部の切り替え（タブ等）で見比べられるようにする。切り替えの UI はモックアップの一部ではないと分かる見た目にする。URL のハッシュ（例: `#empty`）でも状態を選べるようにし、提案ページから状態を指定して埋め込めるようにする
- 対象デバイスが両方なら、幅 390px と 1280px の両方で崩れないようにする
- 動きは CSS の transition / animation で実際に動かし、`prefers-reduced-motion` のときは止める
- 文言はプロダクトで実際に表示するものを書く。データは実在しそうな値にする
- 画像は SVG か CSS で描く。外部の画像 URL を使わない
- 実装技術のコード（React のコンポーネント等）は書かない。HTML と CSS で見た目を表す

## 一覧

`docs/mockups/README.md` の雛形。画面を足すたびに行を足す。

```markdown
# モックアップ

画面ごとのデザインモックアップ。ブラウザで開いて確認する。デザインの定義は `docs/development/design-system.md` を正とする。
追加・更新は `spira:mockup` で行う。

| 画面 | ファイル | 機能 | 描いた状態 |
|:--|:--|:--|:--|
| （画面名） | [login.html](login.html) | `docs/concept.md:12` | 通常・エラー |
```
