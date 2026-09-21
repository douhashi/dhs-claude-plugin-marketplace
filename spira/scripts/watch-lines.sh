#!/usr/bin/env bash
#
# 自走開発のライン（lines/N.log、stream-json）の経過を、全ライン分まとめて
# `[#N] HH:MM:SS 種別 要約` の 1 行ずつで流す。
#
#   watch-lines.sh [ライン dir]   # 既定: .tmp/spira-autopilot/lines
#
# 2 秒ごとに直下の N.log（N は数字だけ）を探し、新しいログは追い始め、
# archive/ へ退避されて消えたログは追うのをやめる。Ctrl-C で全部止まる。
# macOS（bash 3.2・BSD tail）でも動くよう、連想配列や GNU 専用オプションは使わない。

set -u

DIR="${1:-.tmp/spira-autopilot/lines}"
[ -d "$DIR" ] || { echo "watch-lines: $DIR がありません" >&2; exit 1; }

# 1 行の stream-json イベントを 0 行以上の表示行にする（$n はライン番号）。
# shellcheck disable=SC2016  # jq のフィルタなので $ は展開しない
FILTER='
def oneline: tostring | gsub("\\s+"; " ");
def head: "[#\($n)] \(now | strflocaltime("%H:%M:%S"))";
def emit($kind; $text): "\(head) \($kind) \($text | oneline)" | .[0:120];
def point: .command // .file_path // .pattern // .skill // .description // "";
def body: if type == "array" then map(.text? // empty) | join(" ") else . end;
def minutes: "\((. // 0) / 60000 | floor) 分";
def usd: ((. // 0) * 100 | round) as $c | "$\($c / 100 | floor).\($c % 100 + 100 | tostring | .[1:])";
. as $raw
| (try fromjson catch null) as $e
| if ($e | type) != "object" then emit("出力"; $raw)
  elif $e.type == "system" and $e.subtype == "init" then emit("開始"; $e.model // "")
  elif $e.type == "assistant" then
    $e.message.content[]?
    | if .type == "tool_use" then emit("ツール"; "\(.name) \(.input | point)")
      elif .type == "text" then emit("発言"; .text | split("\n")[0])
      else empty end
  elif $e.type == "user" then
    $e.message.content[]?
    | select(.type == "tool_result" and .is_error == true)
    | emit("エラー"; .content | body)
  elif $e.type == "result" then
    emit("結果"; "\($e.subtype) \($e.total_cost_usd | usd) · \($e.num_turns // 0) ターン · \($e.duration_ms | minutes)")
  else empty end
'

# 追っているログと、それを流すサブシェルの PID（並列の配列）。
LOGS=()
PIDS=()

# サブシェルの子（tail と jq）を止める。サブシェルは子が終わると自分も終わる。
stop() { pkill -P "$1" 2>/dev/null; }

stop_all() {
  local i
  for i in ${PIDS[@]+"${!PIDS[@]}"}; do
    stop "${PIDS[$i]}"
  done
  exit 0
}
trap stop_all INT TERM HUP

tracked() {
  local i
  for i in ${LOGS[@]+"${!LOGS[@]}"}; do
    [ "${LOGS[$i]}" = "$1" ] && return 0
  done
  return 1
}

while :; do
  for f in "$DIR"/[0-9]*.log; do
    [ -f "$f" ] || continue
    n="$(basename "$f" .log)"
    case "$n" in *[!0-9]*) continue ;; esac   # 退避途中の N-<日時>.log は拾わない
    tracked "$f" && continue
    # stderr を捨てるのは、止めたときにサブシェルが出す Terminated を表示に混ぜないため
    (tail -n +1 -F "$f" | jq -R -r --unbuffered --arg n "$n" "$FILTER") 2>/dev/null &
    LOGS+=("$f")
    PIDS+=("$!")
  done
  for i in ${LOGS[@]+"${!LOGS[@]}"}; do
    [ -f "${LOGS[$i]}" ] && continue
    stop "${PIDS[$i]}"
    unset "LOGS[$i]" "PIDS[$i]"
  done
  sleep 2
done
