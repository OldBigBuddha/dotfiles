#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
command="$(echo "${input}" | jq -r '.tool_input.command // empty')"

if echo "${command}" | grep -Eq '(^|[[:space:];&|(`])sleep([[:space:];&|)`]|$)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "The sleep command is blocked. Do not use sleep for polling or waiting. Use run_in_background / Monitor to wait for background jobs, or ScheduleWakeup to resume at a later time. If this sleep is not for polling/waiting (e.g. part of test code), state that explicitly and use a different approach."
    }
  }'
  exit 0
fi

exit 0
