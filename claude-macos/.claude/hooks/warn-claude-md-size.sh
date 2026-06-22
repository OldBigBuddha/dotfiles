#!/usr/bin/env bash
# PostToolUse hook: when an edited CLAUDE*.md exceeds the line cap, feed
# context back to Claude nudging it to compress the file.
#
# -x is intentionally omitted: trace output on stderr would be surfaced as
# hook feedback. Everything stays on stdout as a single JSON object.
set -euo pipefail

readonly THRESHOLD=200

main() {
  local input file_path base lines

  input="$(cat)"

  file_path="$(printf '%s' "${input}" | jq -r '.tool_input.file_path // empty')"
  [[ -n "${file_path}" ]] || exit 0

  base="$(basename "${file_path}")"
  [[ "${base}" == CLAUDE*.md ]] || exit 0
  [[ -f "${file_path}" ]] || exit 0

  lines="$(wc -l < "${file_path}" | tr -d '[:space:]')"
  (( lines > THRESHOLD )) || exit 0

  jq -n \
    --arg fp "${file_path}" \
    --argjson n "${lines}" \
    --argjson t "${THRESHOLD}" \
    '{
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: "\($fp) is now \($n) lines, over the \($t)-line cap for instruction files. Consider compressing it: split distinct concerns into focused files and keep the instruction file lean and scannable."
      }
    }'
}

main "$@"
