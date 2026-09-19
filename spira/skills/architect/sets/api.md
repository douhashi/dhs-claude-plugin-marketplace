# アーキテクチャセット: API

同梱の内容は叩き台であり、最新かどうかは architect スキルの実行時に調査で確かめる。

## 対象と対象外

- 対象: 画面を持たず、HTTP で他のクライアント（Web・モバイル・CLI・外部システム）に機能を提供するサーバー
- 対象外: 画面を持つ Web アプリケーション（`web.md`）、コマンドラインツール（`cli.md`）
- 責務: 配布先へのデプロイまで。配布先は `_deploy.md` の判定で決める

## 最終検証日

2026-09-20

## 構成パターン

| パターン | 使う場面 |
|:--|:--|
| API 単体（Hono on Workers） | 複数のクライアントが同じ API を使う |
| API + 非同期処理（Workers + Queues） | 短いジョブを応答と切り離して処理する |
| API + ワーカー（fly.io） | `_deploy.md` の判定で fly.io になった |

## 選定の観点

| 要件 | 優先するもの |
|:--|:--|
| 長時間ジョブキューや独自ツール・ネイティブ依存（例: ffmpeg, ヘッドレスブラウザ）の有無で | 配布先を `_deploy.md` の判定で決める |
| 想定規模が大きく高負荷が見込まれるなら | 高負荷に強い Cloudflare に載せられるよう、長時間ジョブと独自ツールを避けられないか先に確かめる |
| 複数セットにまたがる案件なら | 共通レイヤー（認証・DB・API 仕様）を API セットで決める |
| 複数のクライアントが使うなら | API 仕様を 1 か所で定義し、クライアントはそれに従わせる |
| AI エージェントに実装させるなら | 薄く覚えることの少ない Hono を優先する |
| AI エージェントに Cloudflare を扱わせるなら | Workers 固有 API の現行仕様を調査で確かめてから実装させる |

## 推奨スタック例

Cloudflare を選んだときの例。fly.io を選んだときは `_deploy.md` の「fly.io を選んだときのフレームワーク」に従う。

| 役割 | 推奨 | 理由 |
|:--|:--|:--|
| 実行環境 | Cloudflare Workers | 安価で高負荷に対応できる |
| フレームワーク | Hono | Workers でも Node.js でも動き、fly.io に移っても同じコードを使える |
| DB | Cloudflare D1 | Workers からバインディングで使える SQLite 互換の DB |
| ファイル保存 | Cloudflare R2 | Workers からバインディングで使えるオブジェクトストレージ |
| 非同期処理 | Cloudflare Queues | 短いジョブを Workers の中で非同期に処理できる |

## 代替の検索語

- Hono Cloudflare Workers
- Cloudflare Workers framework guide
- Cloudflare Workers bindings D1 R2 Queues
- Cloudflare Workers runtime APIs compatibility
- Hono Node.js deploy fly.io
