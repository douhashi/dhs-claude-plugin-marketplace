# アーキテクチャセット: Web

同梱の内容は叩き台であり、最新かどうかは architect スキルの実行時に調査で確かめる。

## 対象と対象外

- 対象: ブラウザで使う Web アプリケーション（画面とサーバー処理を 1 つのアプリで持つもの）
- 対象外: 画面を持たない API（`api.md`）、デスクトップアプリ（`desktop.md`）、モバイルアプリ（`mobile.md`）
- 責務: 配布先へのデプロイまで。配布先は `_deploy.md` の判定で決める

## 最終検証日

2026-09-20

## 構成パターン

| パターン | 使う場面 |
|:--|:--|
| フルスタック（Next.js on Workers） | 画面とサーバー処理を 1 つのアプリで持つ |
| フロントエンド + API セット | 画面以外のクライアント（モバイル・CLI 等）も同じ API を使う |
| フルスタック + コンテナ（fly.io） | `_deploy.md` の判定で fly.io になった |

## 選定の観点

| 要件 | 優先するもの |
|:--|:--|
| 長時間ジョブキューや独自ツール・ネイティブ依存（例: ffmpeg, ヘッドレスブラウザ）の有無で | 配布先を `_deploy.md` の判定で決める |
| 想定規模が大きく高負荷が見込まれるなら | 高負荷に強い Cloudflare に載せられるよう、長時間ジョブと独自ツールを避けられないか先に確かめる |
| 画面以外のクライアントも同じ API を使うなら | API セットを分け、画面は API を呼ぶだけにする |
| 複数セットにまたがる案件で API セットが無いなら | 共通レイヤー（認証・DB・API 仕様）を Web セットで決める |
| 複数セットにまたがる案件で API セットがあるなら | 共通レイヤーは API セットに任せる |
| AI エージェントに実装させるなら | 学習データが多く公式ドキュメントが充実した Next.js と Tailwind CSS を優先する |
| AI エージェントに Cloudflare を扱わせるなら | Workers 固有 API の現行仕様を調査で確かめてから実装させる |
| Cloudflare の Next.js ガイドが OpenNext 以外を推奨しているなら | 調査で成熟度を確かめ、推奨に移るかを決める |

## 推奨スタック例

Cloudflare を選んだときの例。fly.io を選んだときは `_deploy.md` の「fly.io を選んだときのフレームワーク」に従う。

| 役割 | 推奨 | 理由 |
|:--|:--|:--|
| 実行環境 | Cloudflare Workers | 安価で高負荷に対応できる |
| フレームワーク | Next.js（OpenNext の Cloudflare アダプター） | Next.js を Workers で動かせる |
| スタイル | Tailwind CSS | ユーティリティクラスで書け、AI エージェントも扱いやすい |
| DB | Cloudflare D1 | Workers からバインディングで使える SQLite 互換の DB |
| ファイル保存 | Cloudflare R2 | Workers からバインディングで使えるオブジェクトストレージ |
| 非同期処理 | Cloudflare Queues | 短いジョブを Workers の中で非同期に処理できる |

## 代替の検索語

- OpenNext Cloudflare adapter
- vinext Cloudflare
- Next.js Cloudflare Workers
- Cloudflare Workers bindings D1 R2 Queues
- Cloudflare Workers runtime APIs compatibility
- Cloudflare Workers Node.js compatibility
- Next.js deploy fly.io
