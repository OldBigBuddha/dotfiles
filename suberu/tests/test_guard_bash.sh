#!/usr/bin/env bash
# Contract for scripts/guard-bash.sh.
#
# The guard reads a PreToolUse payload on stdin and writes a deny decision to
# stdout when the command is forbidden. Silence means the command is allowed.
# Exit status is always 0: the decision travels in the JSON, not the status.
#
# Worktree placement is checked against real repositories in both layouts,
# because where a worktree "belongs" is a question only git can answer.
set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly tests_dir
# shellcheck source=./lib.sh
source "${tests_dir}/lib.sh"
# shellcheck source=./fixtures.sh
source "${tests_dir}/fixtures.sh"

guard="$(dirname "${tests_dir}")/claude/plugins/suberu/scripts/guard-bash.sh"
readonly guard

scratch="$(mktemp -d)"
readonly scratch
trap 'rm -rf "${scratch}"' EXIT

read -r normal_root _ <<<"$(fixture_normal_repo "${scratch}/normal")"
read -r bare_root _ <<<"$(fixture_bare_repo "${scratch}/bare")"
readonly normal_root bare_root
bare_home="$(dirname "${bare_root}")"
readonly bare_home

# Feed one Bash command through the guard and echo whatever it decided.
run_guard() {
  local -r cwd="$1"
  local -r command="$2"
  /usr/bin/python3 -c 'import json,sys; print(json.dumps({"hook_event_name":"PreToolUse","tool_name":"Bash","cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' \
    "${cwd}" "${command}" | bash "${guard}"
}

assert_denied() {
  local -r cwd="$1"
  local -r command="$2"
  local -r output="$(run_guard "${cwd}" "${command}")"
  assert_contains "${output}" '"permissionDecision":"deny"' "deny: ${command}"
}

assert_allowed() {
  local -r cwd="$1"
  local -r command="$2"
  local -r output="$(run_guard "${cwd}" "${command}")"
  assert_equals "" "${output}" "allow: ${command}"
}

# --- git -C: crosses worktree boundaries, so the cwd stops meaning anything ---
assert_denied "${normal_root}" 'git -C /tmp status'
assert_denied "${normal_root}" 'git --no-pager -C /tmp status'
# `-C` after a subcommand is git's copy-detection flag and is unrelated.
assert_allowed "${normal_root}" 'git log -C50 --stat'
assert_allowed "${normal_root}" 'git status'

# --- worktree placement, conventional layout: flat inside the root ---
assert_allowed "${normal_root}" "git worktree add ${normal_root}/feature-x"
assert_allowed "${normal_root}" 'git worktree add feature-x'
assert_denied "${normal_root}" 'git worktree add .claude/worktrees/foo'
assert_denied "${normal_root}" "git worktree add ${normal_root}/.claude/worktrees/foo"
assert_denied "${normal_root}" 'git worktree add nested/dir/foo'
# The escape that actually happened once: a relative path climbing out of the
# repository, which the old component-counting check waved through.
assert_denied "${normal_root}" 'git worktree add ../outside'
assert_allowed "${normal_root}" 'git worktree list'

# --- worktree placement, bare layout: flat beside the bare directory ---
assert_allowed "${bare_root}" "git worktree add ${bare_home}/feature-y"
assert_allowed "${bare_root}" 'git worktree add ../feature-y'
assert_denied "${bare_root}" "git worktree add ${bare_root}/inside-the-bare-dir"
assert_denied "${bare_root}" "git worktree add ${bare_home}/nested/dir"

# --- terraform: the settings.json prefix deny is trivially bypassed ---
assert_denied "${normal_root}" 'terraform apply'
assert_denied "${normal_root}" 'cd /tmp && terraform apply'
assert_denied "${normal_root}" 'terraform -chdir=/tmp apply'
assert_denied "${normal_root}" 'TF_LOG=debug terraform destroy'
assert_denied "${normal_root}" 'terraform state rm module.foo'
assert_denied "${normal_root}" 'terraform force-unlock 1234'
assert_allowed "${normal_root}" 'terraform plan'
assert_allowed "${normal_root}" 'terraform state list'
assert_allowed "${normal_root}" 'cd /tmp && terraform plan'

# --- outside any repository there is no placement rule to enforce ---
mkdir -p "${scratch}/plain"
assert_allowed "${scratch}/plain" 'git worktree add anywhere/at/all'

# --- non-Bash tools are none of this guard's business ---
readonly read_payload='{"hook_event_name":"PreToolUse","tool_name":"Read","cwd":"/tmp","tool_input":{"file_path":"/tmp/x"}}'
assert_equals "" "$(printf '%s' "${read_payload}" | bash "${guard}")" "allow: non-Bash tool passes through"

# --- an undeterminable repository must warn rather than fail open ---
# /bin holds bash but not git, so the guard runs and finds git missing.
undetermined="$(PATH=/bin run_guard "${normal_root}" 'git worktree add nested/dir/foo')"
readonly undetermined
assert_contains "${undetermined}" '"systemMessage"' "warn when git cannot be consulted"

finish_tests
