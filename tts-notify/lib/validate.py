#!/usr/bin/env python3
"""tts-notify response validator (stdlib only — mirrors extract.py's no-dep rule).

Reads the OpenRouter structured-output *content* (a JSON string the model is
asked to emit, shape: {"sentences":[{"text","reading"}, ...]}) on stdin, and
writes validated NDJSON to stdout — one object per usable sentence:

    {"say": <reading>, "show": <text>}

This is exactly the input contract worker.sh feeds to hailer (say -> speech,
show -> text). The model side is *already* schema-constrained (strict
json_schema), so this is a second, client-side guard for preview models that
don't fully honor strict mode. Its real job is to make drops *visible*: every
rejected sentence (and any parse failure) is explained on stderr, which
summarize.sh routes into worker.log. Exit is always 0 — an empty stdout makes
the caller degrade gracefully, never break the hook chain.
"""
import json
import sys


def _norm(value) -> str:
    """Coerce to a stripped string; non-strings (None/num/bool) -> ""/str()."""
    if value is None:
        return ""
    if not isinstance(value, str):
        value = str(value)
    return value.strip()


def main() -> int:
    raw = sys.stdin.read()
    if not raw.strip():
        print("empty content", file=sys.stderr)
        return 0

    try:
        data = json.loads(raw)
    except (ValueError, TypeError) as exc:
        print(f"content not valid JSON: {exc}", file=sys.stderr)
        return 0

    if not isinstance(data, dict):
        print(f"content is {type(data).__name__}, expected object", file=sys.stderr)
        return 0

    sentences = data.get("sentences")
    if not isinstance(sentences, list):
        print("missing/!list 'sentences'", file=sys.stderr)
        return 0
    if not sentences:
        print("'sentences' is empty", file=sys.stderr)
        return 0

    emitted = 0
    for i, sent in enumerate(sentences):
        if not isinstance(sent, dict):
            print(f"sentence[{i}] is {type(sent).__name__}, skipped", file=sys.stderr)
            continue
        reading = _norm(sent.get("reading"))
        text = _norm(sent.get("text"))
        # reading is what TTS speaks; nothing to say -> drop.
        if not reading:
            print(f"sentence[{i}] empty reading, dropped", file=sys.stderr)
            continue
        # text is the display/notify body; fall back to the reading.
        if not text:
            print(f"sentence[{i}] empty text, fell back to reading", file=sys.stderr)
            text = reading
        print(json.dumps({"say": reading, "show": text}, ensure_ascii=False))
        emitted += 1

    if emitted == 0:
        print("no usable sentence after validation", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
