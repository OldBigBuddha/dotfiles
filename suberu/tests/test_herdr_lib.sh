#!/usr/bin/env bash
# Contract for the herdr-side units that carry logic worth testing:
# slug/path validation, settings seeding, status-transition detection, and
# fleet rendering. The thin herdr CLI orchestration around them is verified
# live (see README) rather than mocked.
set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly tests_dir
# shellcheck source=./lib.sh
source "${tests_dir}/lib.sh"

herdr_dir="$(dirname "${tests_dir}")/herdr"
readonly herdr_dir
# shellcheck source=../herdr/bin/lib.sh
source "${herdr_dir}/bin/lib.sh"

scratch="$(mktemp -d)"
readonly scratch
trap 'rm -rf "${scratch}"' EXIT

# --- flat placement is a structural invariant, not a convention ---
# suberu::flat_path rejects by exiting, so it needs its own subshell: an
# `exit` in the caller's shell would skip the `||` branch entirely.
capture_flat_path() {
  (suberu::flat_path "/repo" "$1") 2>/dev/null || printf 'REJECTED'
}

assert_equals "/repo/feature-x" "$(capture_flat_path 'feature-x')" "flat path for a plain slug"
assert_contains "$(capture_flat_path 'nested/slug')" "REJECTED" "reject slug with a separator"
assert_contains "$(capture_flat_path '..')" "REJECTED" "reject parent-directory slug"
assert_contains "$(capture_flat_path '')" "REJECTED" "reject empty slug"
assert_contains "$(capture_flat_path '.hidden')" "REJECTED" "reject slug starting with a dot"

# --- where worktrees belong is git's answer, not a guess from the path shape ---
# shellcheck source=./fixtures.sh
source "${tests_dir}/fixtures.sh"
read -r fx_normal_root _ <<<"$(fixture_normal_repo "${scratch}/normal")"
read -r fx_bare_root _ <<<"$(fixture_bare_repo "${scratch}/bare")"
readonly fx_normal_root fx_bare_root

assert_equals "$(cd "${fx_normal_root}" && pwd)" "$(suberu::worktree_home "${fx_normal_root}")" \
  "conventional layout puts worktrees inside the repository root"
assert_equals "$(cd "${fx_bare_root}/.." && pwd)" "$(suberu::worktree_home "${fx_bare_root}")" \
  "bare layout puts worktrees beside the bare directory"

# --- seeding permissions must never clobber a worktree's own settings ---
readonly template="${scratch}/template.json"
readonly target="${scratch}/settings.local.json"
printf '%s' '{"permissions":{"allow":["Bash(terraform plan*)"],"deny":["Bash(terraform apply*)"]}}' >"${template}"
printf '%s' '{"permissions":{"allow":["Bash(pnpm test*)"]},"model":"opus"}' >"${target}"

/usr/bin/python3 "${herdr_dir}/bin/merge_settings.py" "${template}" "${target}"
merged="$(cat "${target}")"
assert_contains "${merged}" 'pnpm test' "merge keeps the pre-existing allow entry"
assert_contains "${merged}" 'terraform plan' "merge adds the template allow entry"
assert_contains "${merged}" 'terraform apply' "merge adds the template deny entry"
assert_contains "${merged}" '"model"' "merge keeps unrelated keys"

/usr/bin/python3 "${herdr_dir}/bin/merge_settings.py" "${template}" "${target}"
assert_equals "$(printf '%s' "${merged}" | tr -d ' \n')" "$(tr -d ' \n' <"${target}")" "merge is idempotent"

# --- a type the template did not expect drops the baseline, so it must say so ---
# The worktree's own value still wins; what must not happen is the guardrails
# going missing with nobody told.
merge_conflict() {
  local -r existing="$1"
  local -r conflicted="${scratch}/conflict.json"
  printf '%s' "${existing}" >"${conflicted}"
  # Only the warning is under test, so stdout is dropped before the swap.
  { /usr/bin/python3 "${herdr_dir}/bin/merge_settings.py" "${template}" "${conflicted}" >/dev/null; } 2>&1
}

assert_contains "$(merge_conflict '{"permissions":null}')" "permissions" \
  "a null where a table was expected is reported"
assert_contains "$(merge_conflict '{"permissions":"everything"}')" "permissions" \
  "a scalar where a table was expected is reported"
assert_contains "$(merge_conflict '{"permissions":{"deny":"Bash(rm:*)"}}')" "deny" \
  "a string where a list was expected is reported"
assert_equals "" "$(merge_conflict '{"permissions":{"allow":["Bash(pnpm test*)"]}}')" \
  "a compatible file merges without a word"

# The worktree's own value survives the warning.
printf '%s' '{"permissions":"everything"}' >"${scratch}/keep.json"
/usr/bin/python3 "${herdr_dir}/bin/merge_settings.py" "${template}" "${scratch}/keep.json" 2>/dev/null
assert_contains "$(cat "${scratch}/keep.json")" 'everything' "the worktree's own value is kept"

# Malformed JSON must abort rather than overwrite what it could not read.
printf '%s' '{"permissions": {"allow": ["Read"' >"${scratch}/broken.json"
broken_rc=0
/usr/bin/python3 "${herdr_dir}/bin/merge_settings.py" "${template}" "${scratch}/broken.json" \
  >/dev/null 2>&1 || broken_rc=$?
assert_equals "1" "${broken_rc}" "unreadable settings abort the seeding"
assert_equals '{"permissions": {"allow": ["Read"' "$(cat "${scratch}/broken.json")" \
  "unreadable settings are left untouched"

# --- seeding must not leave the worktree dirty ---
# Otherwise every finished task needs `task-finish.sh --force`, so the operator
# learns to always pass it and a worktree holding real uncommitted work is
# discarded just as readily. A check that is always bypassed protects nothing.
read -r _ seeded_wt <<<"$(fixture_normal_repo "${scratch}/seeded")"
readonly seeded_wt
# Echoes the handler's diagnostics; its stdout is trace output, not a result.
seed_worktree() {
  { HERDR_PLUGIN_ROOT="${herdr_dir}" \
    HERDR_PLUGIN_EVENT_JSON="{\"data\":{\"worktree\":{\"path\":\"${seeded_wt}\"}}}" \
    bash "${herdr_dir}/bin/on-worktree-created.sh" >/dev/null; } 2>&1
}

seed_worktree >/dev/null
assert_contains "$(cat "${seeded_wt}/.claude/settings.local.json")" 'terraform apply' \
  "seeding writes the permission baseline"
assert_equals "" "$(git -C "${seeded_wt}" status --porcelain)" \
  "seeding leaves the worktree clean"

# --- one state namespace per repository ---
# The state directory is shared by every repository an orchestrator is opened
# on, so a flat namespace would mix two projects' reports together and let one
# orchestrator tear down the other's tasks.
assert_equals "$(cd "${fx_bare_root}" && pwd -P)" "$(suberu::repo_key "${fx_bare_root}")" \
  "a repository is identified by its git common directory"
assert_equals "bare" "$(suberu::repo_slug "${fx_bare_root}")" \
  "the bare layout is named after the directory its worktrees sit in"
assert_equals "normal" "$(suberu::repo_slug "${fx_normal_root}")" \
  "the conventional layout is named after the repository root"

# The report lives in the state directory, not the worktree. Reading anything
# inside a worktree costs the orchestrator that tree's CLAUDE.md and skill
# manifest, so a report kept there defeats its own purpose.
report="$(HERDR_PLUGIN_STATE_DIR="${scratch}/state" suberu::report_path w9 "${fx_bare_root}")"
readonly report
assert_equals "${scratch}/state/reports/bare/w9.md" "${report}" \
  "reports live in the state directory, under their repository"
assert_equals "0" "$(printf '%s' "${report}" | grep -c "${seeded_wt}")" \
  "the report path is outside every worktree"

task_state="$(HERDR_PLUGIN_STATE_DIR="${scratch}/state" suberu::task_state_path w9 "${fx_bare_root}")"
readonly task_state
assert_equals "${scratch}/state/tasks/bare/w9.json" "${task_state}" \
  "task records are namespaced by repository too"

# Suberu owns .suberu and hides it itself; settings.local.json belongs to Claude
# Code and is normally ignored repo- or user-wide. Where it is not, say so
# rather than quietly writing to the repository's shared exclude file.
git -C "${seeded_wt}" config core.excludesFile /dev/null
assert_contains "$(seed_worktree)" "settings.local.json" \
  "an unignored settings.local.json is reported, not silently left dirty"

# --- teardown must not fire blind ---
readonly idle_pane='[{"pane_id":"w9:p1","foreground_processes":[{"argv0":"caffeinate","cmdline":"caffeinate -i"},{"argv0":"claude","cmdline":"claude"}]}]'
readonly busy_pane='[{"pane_id":"w9:p2","foreground_processes":[{"argv0":"zsh","cmdline":"zsh"},{"argv0":"packer","cmdline":"packer build -var environment=production"}]}]'

assert_equals "" "$(printf '%s' "${idle_pane}" | /usr/bin/python3 "${herdr_dir}/bin/busy_check.py")" \
  "an idle agent pane is not busy"
assert_contains "$(printf '%s' "${busy_pane}" | /usr/bin/python3 "${herdr_dir}/bin/busy_check.py")" \
  "packer build" "a running build is reported as busy"

# A workspace Suberu did not create must never be torn down by it: task-finish
# removes the checkout, so `v2` or any hand-made worktree would go with it.
unowned_rc=0
HERDR_PLUGIN_STATE_DIR="${scratch}/empty-state" \
  bash "${herdr_dir}/bin/task-finish.sh" wZZ >/dev/null 2>&1 || unowned_rc=$?
assert_equals "1" "${unowned_rc}" "a workspace Suberu does not own is refused"

# --- notify on a real transition only; the event carries no previous status ---
readonly state_dir="${scratch}/state"
transition() {
  /usr/bin/python3 "${herdr_dir}/bin/status_transition.py" "${state_dir}" \
    "{\"data\":{\"pane_id\":\"w9:p1\",\"workspace_id\":\"w9\",\"agent_status\":\"$1\"}}"
}

assert_equals "" "$(transition working)" "first sighting is not a transition"
assert_equals "" "$(transition working)" "repeated working is not a transition"
assert_equals "notify" "$(transition idle)" "working to idle needs the orchestrator"
assert_equals "" "$(transition idle)" "repeated idle does not re-notify"
assert_equals "" "$(transition working)" "going back to work is not worth a notification"

# --- the pollution fix must not itself flood the context ---
readonly snapshot="${scratch}/snapshot.json"
printf '%s' '{"result":{"snapshot":{"workspaces":[{"workspace_id":"w3","label":"monorepo","agent_status":"working","worktree":{"checkout_path":"/repo","is_linked_worktree":false}},{"workspace_id":"w4","label":"task-a","agent_status":"idle","tokens":{"goal":"do a thing","branch":"feat/a"}}]}}}' >"${snapshot}"

fleet="$(/usr/bin/python3 "${herdr_dir}/bin/render_fleet.py" --max-lines 20 <"${snapshot}")"
assert_contains "${fleet}" "task-a" "fleet render names each workspace"
assert_contains "${fleet}" "idle" "fleet render carries agent status"
assert_contains "${fleet}" "feat/a" "fleet render carries the branch token"

# A single verbose goal must not outweigh the rest of the fleet.
long_goal="$(printf 'x%.0s' {1..200})"
wordy='{"result":{"snapshot":{"workspaces":[{"workspace_id":"w4","label":"task-a","agent_status":"idle","tokens":{"goal":"'"${long_goal}"'"}}]}}}'
readonly long_goal wordy
wide="$(printf '%s' "${wordy}" | /usr/bin/python3 "${herdr_dir}/bin/render_fleet.py")"
if [[ "${#wide}" -lt 120 ]]; then
  assert_equals "short" "short" "fleet render bounds a long goal"
else
  assert_equals "short" "${#wide} chars" "fleet render bounds a long goal"
fi

truncated="$(/usr/bin/python3 "${herdr_dir}/bin/render_fleet.py" --max-lines 2 <"${snapshot}")"
assert_equals "2" "$(printf '%s\n' "${truncated}" | wc -l | tr -d ' ')" "fleet render honours the line budget"

finish_tests
