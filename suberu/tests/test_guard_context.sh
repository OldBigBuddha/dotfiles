#!/usr/bin/env bash
# Contract for scripts/guard-context.sh -- the context-pollution guard.
#
# The orchestrator must not pull worker material into its own context: not
# implementation files, not raw agent scrolls. Workers are unrestricted, so the
# guard has to tell the two roles apart from the payload alone.
#
# Both repository layouts are exercised. An earlier version inferred the role
# from directory shape and silently treated a textbook bare repository as "not
# an orchestrator", disabling every rule without a word -- the worst failure a
# guardrail can have.
set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly tests_dir
# shellcheck source=./lib.sh
source "${tests_dir}/lib.sh"
# shellcheck source=./fixtures.sh
source "${tests_dir}/fixtures.sh"

guard="$(dirname "${tests_dir}")/claude/plugins/suberu/scripts/guard-context.sh"
readonly guard

scratch="$(mktemp -d)"
readonly scratch
trap 'rm -rf "${scratch}"' EXIT

read -r normal_root normal_wt <<<"$(fixture_normal_repo "${scratch}/normal")"
read -r bare_root bare_wt <<<"$(fixture_bare_repo "${scratch}/bare")"
readonly normal_root normal_wt bare_root bare_wt

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

# --- conventional layout: worktrees live inside the repository root ---
assert_denied "orchestrator reads worker source" \
  "${normal_root}" Read file_path "${normal_wt}/src/main.go"
assert_denied "orchestrator greps inside a worktree" \
  "${normal_root}" Grep path "${normal_wt}/src"
assert_denied "orchestrator edits worker source" \
  "${normal_root}" Edit file_path "${normal_wt}/src/main.go"

# --- bare layout: worktrees are siblings, not children ---
assert_denied "bare-root orchestrator reads worker source" \
  "${bare_root}" Read file_path "${bare_wt}/src/main.go"
assert_denied "bare-root orchestrator cats worker source" \
  "${bare_root}" Bash command "cat ${bare_wt}/src/main.go"

# --- summaries exist to be read by the orchestrator ---
assert_allowed "orchestrator reads a worker report" \
  "${normal_root}" Read file_path "${normal_wt}/.suberu/report.md"
assert_allowed "orchestrator reads CLAUDE.local.md" \
  "${normal_root}" Read file_path "${normal_wt}/CLAUDE.local.md"

# --- anything outside the repository is unrelated to fleet hygiene ---
assert_allowed "orchestrator reads its own dotfiles" \
  "${normal_root}" Read file_path "/Users/s.yamakawa/dotfiles/suberu/README.md"
assert_allowed "orchestrator reads a file at the repo root" \
  "${normal_root}" Read file_path "${normal_root}/README.md"

# --- raw agent scrollback is the other pollution route ---
assert_denied "orchestrator reads an agent scroll" \
  "${normal_root}" Bash command "herdr agent read nbd-io-bench --lines 200"
assert_denied "orchestrator reads a pane scroll" \
  "${normal_root}" Bash command "herdr pane read w4:p1"
assert_allowed "orchestrator queries fleet state" \
  "${normal_root}" Bash command "herdr workspace list"
assert_allowed "orchestrator checks agent status" \
  "${normal_root}" Bash command "herdr agent get nbd-io-bench"

# --- workers own their worktree ---
assert_allowed "worker reads its own source" \
  "${normal_wt}" Read file_path "${normal_wt}/src/main.go"
assert_allowed "worker cats its own source" \
  "${normal_wt}" Bash command "cat ${normal_wt}/src/main.go"
assert_allowed "bare-layout worker reads its own source" \
  "${bare_wt}" Read file_path "${bare_wt}/src/main.go"

# --- a directory that is not a repository carries no fleet semantics ---
mkdir -p "${scratch}/plain"
assert_allowed "non-repository cwd is not policed" \
  "${scratch}/plain" Read file_path "${scratch}/plain/anything.txt"

# --- an undeterminable role must say so rather than fail open ---
# /bin holds bash but not git, so the guard runs and finds git missing.
undetermined="$(PATH=/bin run_guard "${normal_root}" Read file_path "${normal_wt}/src/main.go")"
readonly undetermined
assert_contains "${undetermined}" '"systemMessage"' "warn when git cannot be consulted"

finish_tests
