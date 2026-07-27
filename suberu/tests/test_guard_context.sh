#!/usr/bin/env bash
# Contract for scripts/guard-context.sh -- the context-pollution guard.
#
# The orchestrator must not pull worker material into its own context: not
# implementation files, not raw agent scrolls. Workers are unrestricted; the
# guard therefore has to tell the two roles apart from the payload alone.
#
# Fixtures are a synthetic repo so the suite does not depend on the state of
# any real checkout: <root>/.git/ is a directory holding worktrees/ (the
# orchestrator's cwd), and <root>/wt/.git is a file (a linked worktree).
set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly tests_dir
# shellcheck source=./lib.sh
source "${tests_dir}/lib.sh"

guard="$(dirname "${tests_dir}")/claude/plugins/suberu/scripts/guard-context.sh"
readonly guard

fixture_root="$(mktemp -d)"
readonly fixture_root
trap 'rm -rf "${fixture_root}"' EXIT

mkdir -p "${fixture_root}/.git/worktrees/wt"
mkdir -p "${fixture_root}/wt/src" "${fixture_root}/wt/.suberu"
printf 'gitdir: %s/.git/worktrees/wt\n' "${fixture_root}" >"${fixture_root}/wt/.git"

readonly orchestrator_cwd="${fixture_root}"
readonly worker_cwd="${fixture_root}/wt"

# Build a PreToolUse payload and run it through the guard.
run_guard() {
  local -r cwd="$1"
  local -r tool="$2"
  local -r field="$3"
  local -r value="$4"
  /usr/bin/python3 -c 'import json,sys; print(json.dumps({"hook_event_name":"PreToolUse","cwd":sys.argv[1],"tool_name":sys.argv[2],"tool_input":{sys.argv[3]:sys.argv[4]}}))' \
    "${cwd}" "${tool}" "${field}" "${value}" | bash "${guard}"
}

assert_denied() {
  local -r label="$1"
  shift
  local -r output="$(run_guard "$@")"
  assert_contains "${output}" '"permissionDecision":"deny"' "deny: ${label}"
}

assert_allowed() {
  local -r label="$1"
  shift
  local -r output="$(run_guard "$@")"
  assert_equals "" "${output}" "allow: ${label}"
}

# --- the orchestrator must delegate instead of reading worker source ---
assert_denied "orchestrator reads worker source" \
  "${orchestrator_cwd}" Read file_path "${fixture_root}/wt/src/main.go"
assert_denied "orchestrator greps inside a worktree" \
  "${orchestrator_cwd}" Grep path "${fixture_root}/wt/src"
assert_denied "orchestrator edits worker source" \
  "${orchestrator_cwd}" Edit file_path "${fixture_root}/wt/src/main.go"

# --- summaries are written to be read by the orchestrator ---
assert_allowed "orchestrator reads a worker report" \
  "${orchestrator_cwd}" Read file_path "${fixture_root}/wt/.suberu/report.md"
assert_allowed "orchestrator reads CLAUDE.local.md" \
  "${orchestrator_cwd}" Read file_path "${fixture_root}/wt/CLAUDE.local.md"

# --- anything outside the repository is unrelated to fleet hygiene ---
assert_allowed "orchestrator reads its own dotfiles" \
  "${orchestrator_cwd}" Read file_path "/Users/s.yamakawa/dotfiles/suberu/README.md"
assert_allowed "orchestrator reads a file at the repo root" \
  "${orchestrator_cwd}" Read file_path "${fixture_root}/README.md"

# --- raw agent scrollback is the other pollution route ---
assert_denied "orchestrator reads an agent scroll" \
  "${orchestrator_cwd}" Bash command "herdr agent read nbd-io-bench --lines 200"
assert_denied "orchestrator reads a pane scroll" \
  "${orchestrator_cwd}" Bash command "herdr pane read w4:p1"
assert_denied "orchestrator cats worker source" \
  "${orchestrator_cwd}" Bash command "cat ${fixture_root}/wt/src/main.go"
assert_allowed "orchestrator queries fleet state" \
  "${orchestrator_cwd}" Bash command "herdr workspace list"
assert_allowed "orchestrator checks agent status" \
  "${orchestrator_cwd}" Bash command "herdr agent get nbd-io-bench"

# --- workers own their worktree and are not restricted ---
assert_allowed "worker reads its own source" \
  "${worker_cwd}" Read file_path "${fixture_root}/wt/src/main.go"
assert_allowed "worker cats its own source" \
  "${worker_cwd}" Bash command "cat ${fixture_root}/wt/src/main.go"

finish_tests
