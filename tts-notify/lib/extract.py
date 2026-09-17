#!/usr/bin/env python3
"""Extract the CURRENT turn's final assistant message from a Claude Code transcript JSONL.

Stdlib only (no pip deps).

Claude Code は transcript を **遅延フラッシュ** する。Stop hook が走る時点では、その
ターンの最終本文はまだファイルに無い（実測: hook 完了の約 150ms 後に、最終 text
レコードと stop_hook_summary が同じフラッシュでまとめて現れる）。

したがって「ファイル末尾の assistant 本文」を返すと **前ターンの本文** が返る。
以前の版はそれをやっていて、しかも caller 側のフラッシュ待ちループが「本文が取れたら
break」だったため必ず初回で抜けていた。待っているつもりで一度も待っておらず、
読み上げは常に 1 つ前のメッセージになっていた（worker.log と transcript の
突き合わせで 8/8 ずれを確認）。

そこで、本文が **今ターンのもの** と確定できるときだけ返す。確定条件は 4 つ:

  1. 直近の「ターン開始レコード」より後ろにあること
     （tool_result は起点にしない。isMeta は起点にする。理由は _is_turn_start）
  2. ``message.stop_reason`` が ``tool_use`` でないこと = ターンの最終ブロック。
     1 つの API メッセージは block ごとに別レコードで書かれ、どのレコードにも同じ
     stop_reason が載る。これが無いとツール実行前の途中経過 text（「まず確認します」
     等）を掴む
  3. ``--fired-at`` が渡されていれば、hook 発火の直前以降に書かれていること
     （1 の起点レコード自体がまだ未フラッシュ、というケースの保険）
  4. sidechain（サブエージェント）のレコードでないこと

確定するまでは ``--wait`` 秒までポーリングする。ポーリングをここに置くのは、
sub-second sleep の可搬性のため: ``sleep 0.2`` は BSD sleep で切り捨てられ得るので
シェル側のループには書けない（このプラグインは macOS 固有の無言化を何度も踏んでいる）。
python の ``time.sleep`` なら両方で同じに効き、インタプリタ起動も 1 回で済む。

Usage:  extract.py <transcript_path> [--fired-at <epoch>] [--wait <sec>]
Prints: {"user": "...", "assistant": "..."} on success, {} otherwise.
"""
from __future__ import annotations

import argparse
import datetime
import json
import time

# 本文レコードの timestamp は hook 発火の手前に付く。そのズレを吸収する幅。
#
# 手元の全 transcript 2706 ターンで「発火時刻 − 最終本文 timestamp」を測ると
# p50=0.07s / p99=1.3s / max=2.99s だった。ここを 2 秒にすると 8 ターンが弾かれて
# 無言になる。**狭すぎる側の失敗は無言**（= 原因が表に出ない）なので、実測 max の
# 5 倍を取る。時刻はあくまで「起点レコードすら未フラッシュ」ケースの保険であり、
# 今ターン判定の主役は構造側（直近の起点より後 + stop_reason != tool_use）。
#
# なお fired_at の秒切り捨て（macOS の date に %N が無い）は発火時刻を過小評価する
# 方向なので、判定を緩める側にしか効かない。取り逃しの要因にはならない。
FIRED_AT_TOLERANCE_SEC = 15.0

# 実測のフラッシュ遅延は約 150ms。声のレイテンシに直結するので細かめに見る。
POLL_INTERVAL_SEC = 0.2


def _blocks(rec: dict) -> list:
    content = (rec.get("message") or {}).get("content")
    return content if isinstance(content, list) else []


def _joined_text(rec: dict) -> str | None:
    content = (rec.get("message") or {}).get("content")
    if isinstance(content, str):
        return content.strip() or None
    parts = [
        c.get("text", "")
        for c in _blocks(rec)
        if isinstance(c, dict) and c.get("type") == "text"
    ]
    return "\n".join(t for t in parts if t).strip() or None


def _is_turn_start(rec: dict) -> bool:
    """このターンを始めたユーザ側レコードか。

    除くのは tool_result（ターンの途中で入るだけ）と sidechain。``isMeta`` は
    **除かない**: ノイズの印だと思って弾いたら、キュー投入されたプロンプトが
    isMeta=True で記録されていて起点を取り逃した（全 transcript のリプレイで、
    弾くと 2 ターンぶん前のターンの本文を掴む穴が残る。含めると 0 になる）。
    """
    if rec.get("type") != "user" or rec.get("isSidechain"):
        return False
    if any(isinstance(c, dict) and c.get("type") == "tool_result" for c in _blocks(rec)):
        return False
    return _joined_text(rec) is not None


def _is_turn_final_text(rec: dict) -> bool:
    """ターンを終わらせた assistant 本文か。"""
    if rec.get("type") != "assistant" or rec.get("isSidechain"):
        return False
    stop_reason = (rec.get("message") or {}).get("stop_reason")
    if stop_reason is None or stop_reason == "tool_use":
        return False
    return _joined_text(rec) is not None


def _epoch(rec: dict) -> float | None:
    ts = rec.get("timestamp")
    if not isinstance(ts, str):
        return None
    try:
        return datetime.datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def _load(path: str) -> list[dict]:
    records: list[dict] = []
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for raw in f:
                line = raw.strip()
                if not line:
                    continue
                try:
                    records.append(json.loads(line))
                except json.JSONDecodeError:
                    # 書き込み途中の行。次のポーリングで読み直せばよい。
                    continue
    except OSError:
        return []
    return records


def extract(records: list[dict], fired_at: float | None) -> dict:
    """今ターンの本文が確定していれば {"user", "assistant"}、未確定なら {}。"""
    start_idx = -1
    for i in range(len(records) - 1, -1, -1):
        if _is_turn_start(records[i]):
            start_idx = i
            break
    if start_idx < 0:
        return {}

    floor = None if fired_at is None else fired_at - FIRED_AT_TOLERANCE_SEC
    asst = None
    for i in range(len(records) - 1, start_idx, -1):
        rec = records[i]
        if not _is_turn_final_text(rec):
            continue
        if floor is not None:
            at = _epoch(rec)
            if at is None:
                continue
            if at < floor:
                # これより前のレコードはもっと古い。今ターンの本文はまだ無い。
                break
        asst = _joined_text(rec)
        break
    if asst is None:
        return {}

    out = {"assistant": asst}
    user = _joined_text(records[start_idx])
    if user:
        out["user"] = user
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("transcript")
    ap.add_argument(
        "--fired-at",
        type=float,
        default=None,
        help="hook が発火した epoch 秒。渡すと、それ以降に書かれた本文だけを採る",
    )
    ap.add_argument(
        "--wait",
        type=float,
        default=0.0,
        help="今ターンの本文が確定するまで待つ上限秒（既定 0 = 1 回だけ試す）",
    )
    args = ap.parse_args()

    deadline = time.monotonic() + max(args.wait, 0.0)
    while True:
        out = extract(_load(args.transcript), args.fired_at)
        if out or time.monotonic() >= deadline:
            print(json.dumps(out, ensure_ascii=False))
            return 0
        time.sleep(POLL_INTERVAL_SEC)


if __name__ == "__main__":
    raise SystemExit(main())
