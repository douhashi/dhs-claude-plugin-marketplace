# 配布先の判定: Web / API 共通

Web セット（`web.md`）と API セット（`api.md`）が共通で使う、配布先を fly.io と Cloudflare のどちらにするかの判定。
同梱の内容は叩き台であり、最新かどうかは architect スキルの実行時に調査で確かめる。

## 最終検証日

2026-09-20

## 判定

| 要件 | 配布先 |
|:--|:--|
| 長時間ジョブキューがあるなら | fly.io |
| 独自ツール・ネイティブ依存（例: ffmpeg, ヘッドレスブラウザ）があるなら | fly.io |
| 長時間ジョブが将来入りそうなら | fly.io |
| いずれも無いなら | Cloudflare |

上から順に当てはめ、最初に当てはまった行で決める。

## 理由

- **Cloudflare**: 安価で高負荷に対応できるが、Workers 独自の実行環境と API が大きく学習コストが高い
- **Cloudflare**: 実行時間とネイティブバイナリに制約があり、長時間ジョブと独自ツールには向かない
- **Cloudflare**: AI エージェントの知識が古くなりやすいため、Workers 固有 API の現行仕様を調査で確かめる
- **fly.io**: コンテナさえ動けば手元と同じ環境を作りやすく、独自ツールを動かしやすい
- **fly.io**: 長時間ジョブのワーカーを Web / API と同じ手順で配布できる
- 長時間ジョブを後から入れると配布先の移行になるため、見込みがあれば初めから fly.io に倒す

## fly.io を選んだときのフレームワーク

| 要件 | 優先するもの |
|:--|:--|
| 独自ツールが特定の言語を求めるなら | その言語のフレームワーク |
| 独自ツールが言語を問わないなら | Cloudflare 側の推奨スタック例と同じフレームワークをコンテナで動かす |

Cloudflare 専用のサービス（D1 / R2 / Queues）は fly.io 側では使わず、同じ役割のものを architect スキルの調査で選ぶ。

## 代替の検索語

- Cloudflare Workers limits CPU time
- Cloudflare Queues consumer limits
- fly.io Machines pricing
- Cloudflare Containers
