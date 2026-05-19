#!/usr/bin/env python3
"""Extract the latest turn context from a Claude Code transcript JSONL.

Stdlib only (no pip deps). Ported/simplified from the irodori-tts-docker
coordinator's transcript.py: walk records backward for the most recent
assistant record that has text content, then the most recent user message
before it (used as context so summaries aren't vague).

Simplifications vs. the reference (per "keep it simple"): no fired_at
staleness comparison and no internal polling — the caller (worker.sh) does a
short bounded retry loop instead.

Usage:  extract.py <transcript_path>
Prints: {"user": "...", "assistant": "..."} on success, {} otherwise.
"""
from __future__ import annotations

import json
import sys


def _assistant_text(rec: dict) -> str | None:
    content = (rec.get("message") or {}).get("content")
    if not isinstance(content, list):
        return None
    parts = [
        c.get("text", "")
        for c in content
        if isinstance(c, dict) and c.get("type") == "text"
    ]
    joined = "\n".join(t for t in parts if t)
    return joined or None


def _user_text(rec: dict) -> str | None:
    content = (rec.get("message") or {}).get("content")
    if isinstance(content, str):
        return content.strip() or None
    if isinstance(content, list):
        parts = [
            c.get("text", "")
            for c in content
            if isinstance(c, dict) and c.get("type") == "text"
        ]
        return "\n".join(t for t in parts if t).strip() or None
    return None


def main() -> int:
    if len(sys.argv) < 2:
        print("{}")
        return 0
    path = sys.argv[1]
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
                    continue
    except OSError:
        print("{}")
        return 0

    asst_idx, asst = -1, None
    for i in range(len(records) - 1, -1, -1):
        if records[i].get("type") != "assistant":
            continue
        t = _assistant_text(records[i])
        if t:
            asst_idx, asst = i, t
            break
    if asst is None:
        print("{}")
        return 0

    user = None
    for i in range(asst_idx - 1, -1, -1):
        if records[i].get("type") != "user":
            continue
        u = _user_text(records[i])
        if u:
            user = u
            break

    out: dict[str, str] = {"assistant": asst}
    if user:
        out["user"] = user
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
