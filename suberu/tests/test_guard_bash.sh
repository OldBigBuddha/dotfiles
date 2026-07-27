#!/usr/bin/env bash
# Contract for scripts/guard-bash.sh.
#
# The guard reads a PreToolUse payload on stdin and writes a deny decision to
# stdout when the command is forbidden. Silence means the command is allowed.
# Exit status is always 0: the decision travels in the JSON, not the status.
set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly tests_dir
# shellcheck source=./lib.sh
source "${tests_dir}/lib.sh"

guard="$(dirname "${tests_dir}")/claude/plugins/suberu/scripts/guard-bash.sh"
readonly guard

# Feed one Bash command through the guard and echo whatever it decided.
run_guard() {
  local -r command="$1"
  /usr/bin/python3 -c 'import json,sys; print(json.dumps({"hook_event_name":"PreToolUse","tool_name":"Bash","cwd":"/Users/s.yamakawa/work_dir/monorepo","tool_input":{"command":sys.argv[1]}}))' "${command}" |
    bash "${guard}"
}

assert_denied() {
  local -r command="$1"
  local -r output="$(run_guard "${command}")"
  assert_contains "${output}" '"permissionDecision":"deny"' "deny: ${command}"
}

assert_allowed() {
  local -r command="$1"
  local -r output="$(run_guard "${command}")"
  assert_equals "" "${output}" "allow: ${command}"
}

# --- git -C: crosses worktree boundaries, so the cwd stops meaning anything ---
assert_denied 'git -C /tmp status'
assert_denied 'git --no-pager -C /tmp status'
# `-C` after a subcommand is git's copy-detection flag and is unrelated.
assert_allowed 'git log -C50 --stat'
assert_allowed 'git status'

# --- worktree placement must stay flat under the repo root ---
assert_denied 'git worktree add .claude/worktrees/foo'
assert_denied 'git worktree add /Users/s.yamakawa/work_dir/monorepo/.claude/worktrees/foo'
assert_denied 'git worktree add nested/dir/foo'
assert_allowed 'git worktree add /Users/s.yamakawa/work_dir/monorepo/foo'
assert_allowed 'git worktree list'

# --- terraform: the settings.json prefix deny is trivially bypassed ---
assert_denied 'terraform apply'
assert_denied 'cd /tmp && terraform apply'
assert_denied 'terraform -chdir=/tmp apply'
assert_denied 'TF_LOG=debug terraform destroy'
assert_denied 'terraform state rm module.foo'
assert_denied 'terraform force-unlock 1234'
assert_allowed 'terraform plan'
assert_allowed 'terraform state list'
assert_allowed 'cd /tmp && terraform plan'

# --- non-Bash tools are none of this guard's business ---
readonly read_payload='{"hook_event_name":"PreToolUse","tool_name":"Read","cwd":"/tmp","tool_input":{"file_path":"/tmp/x"}}'
assert_equals "" "$(printf '%s' "${read_payload}" | bash "${guard}")" "allow: non-Bash tool passes through"

finish_tests
