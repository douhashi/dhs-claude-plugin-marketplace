#!/usr/bin/env bash
#
# PreToolUse フック（matcher: AskUserQuestion）。
# 直前に判断材料（本文のテキスト）を出さずに AskUserQuestion を呼んだら拒否する。
#   ダイアログには問いと選択肢しか出ず、思考の中の表はユーザーに見えないため。
# 「直前」は、同じ tool_use を含む assistant の行から遡り、別の tool_use か user の行に
# 当たるまでの text ブロック。思考（thinking）は数えない。
#
# transcript は遅延フラッシュされ、フック起動時点では自分の tool_use の行がまだ無い。
# tool_use_id の行が現れるまで待ち、待ちきれなければ通す（フェイルオープン）。
#
# 環境変数:
#   SPIRA_ASK_MIN_CHARS  本文とみなす最小字数（空白を除く。既定 20）
#   SPIRA_ASK_WAIT       transcript を待つ秒数（既定 5）
set -uo pipefail

min="${SPIRA_ASK_MIN_CHARS:-20}"
wait_sec="${SPIRA_ASK_WAIT:-5}"

input=$(cat)
transcript=$(jq -r '.transcript_path // empty' <<<"$input")
tool_use_id=$(jq -r '.tool_use_id // empty' <<<"$input")
[ -n "$transcript" ] && [ -n "$tool_use_id" ] || exit 0

count_text() {
  jq -nrR --arg id "$tool_use_id" '
    def blocks: [.message.content[]? | select(type == "object")];
    def has_tool_use: [blocks[] | select(.type == "tool_use")] | length > 0;
    def text_len: [blocks[] | select(.type == "text") | .text | gsub("\\s"; "") | length] | add // 0;
    [inputs | fromjson?] as $rows
    | ($rows | map(.type == "assistant" and ([blocks[] | select(.type == "tool_use" and .id == $id)] | length > 0)) | index(true)) as $i
    | if $i == null then "missing"
      else reduce range($i - 1; -1; -1) as $k ({stop: false, n: ($rows[$i] | text_len)};
        if .stop then .
        else $rows[$k] as $r
          | if $r.type == "user" then .stop = true
            elif $r.type == "assistant" then
              if ($r | has_tool_use) then .stop = true else .n += ($r | text_len) end
            else . end
        end) | .n
      end' "$transcript"
}

deadline=$(( $(date +%s%N) + wait_sec * 1000000000 ))
while :; do
  n=$(count_text 2>/dev/null) || n=missing
  [ "$n" != "missing" ] && break
  [ "$(date +%s%N)" -ge "$deadline" ] && exit 0
  sleep 0.1
done

case "$n" in *[!0-9]*|"") exit 0 ;; esac
[ "$n" -ge "$min" ] && exit 0

jq -n '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: "判断材料が本文に出ていません。AskUserQuestion のダイアログには問いと選択肢しか表示されず、思考（thinking）の中に書いた表や提案はユーザーに見えません。問いが指す対象（表・提案・URL・変更のあるファイル・質問の背景）を、思考ではなくユーザーに見える応答のテキストとして書き出し、そのあとで同じ問いの AskUserQuestion をもう一度呼んでください。"
}}'
