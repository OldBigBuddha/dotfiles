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
