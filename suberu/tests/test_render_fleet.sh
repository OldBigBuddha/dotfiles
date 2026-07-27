#!/usr/bin/env bash
# Contract for repository scoping in the fleet render.
#
# An orchestrator manages one repository, so its fleet must not name workspaces
# belonging to another one. The filter runs against real git fixtures rather
# than crafted paths: attribution asks git which repository a checkout belongs
# to, and a directory tree that merely looks like a repository would test
# nothing.
#
# Trace mode is off for the same reason as the other suites: assertion output
# is the readable contract of a run.
set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly tests_dir
# shellcheck source=./lib.sh
source "${tests_dir}/lib.sh"
# shellcheck source=./fixtures.sh
source "${tests_dir}/fixtures.sh"

herdr_dir="$(dirname "${tests_dir}")/herdr"
readonly herdr_dir
readonly render="${herdr_dir}/bin/render_fleet.py"

scratch="$(mktemp -d)"
readonly scratch
trap 'rm -rf "${scratch}"' EXIT

read -r fx_bare_root fx_bare_wt <<<"$(fixture_bare_repo "${scratch}/bare")"
read -r fx_other_root _ <<<"$(fixture_normal_repo "${scratch}/other")"
readonly fx_bare_root fx_bare_wt fx_other_root

# The key is the git common directory, which is what Herdr reports as repo_key.
repo_key_of() {
  local -r path="$1"
  local common_dir
  common_dir="$(cd "${path}" && git rev-parse --git-common-dir)"
  if [[ "${common_dir}" != /* ]]; then
    common_dir="${path}/${common_dir}"
  fi
  (cd "${common_dir}" && pwd -P)
}

repo_key="$(repo_key_of "${fx_bare_root}")"
other_key="$(repo_key_of "${fx_other_root}")"
readonly repo_key other_key

# One snapshot covering every attribution case at once, so the filter is tested
# against a mixed fleet rather than one hand-picked workspace at a time:
#
#   w3  root of this repository, attributed by repo_key
#   wD  linked worktree of this repository, attributed by repo_key
#   wX  another repository entirely
#   wC  opened by hand, so Herdr recorded no worktree at all -- attributable
#       only through its panes' cwd
#   wU  no worktree and a cwd that is not in any repository
snapshot="${scratch}/snapshot.json"
readonly snapshot
/usr/bin/python3 -c 'import json,sys
repo_key, other_key, checkout, wt = sys.argv[2:6]
json.dump({"result": {"snapshot": {
    "workspaces": [
        {"workspace_id": "w3", "label": "monorepo", "agent_status": "working",
         "worktree": {"repo_key": repo_key, "checkout_path": checkout,
                      "is_linked_worktree": False}},
        {"workspace_id": "wD", "label": "image-build", "agent_status": "working",
         "tokens": {"goal": "finalise the manifest", "branch": "chore/img"},
         "worktree": {"repo_key": repo_key, "checkout_path": wt,
                      "is_linked_worktree": True}},
        {"workspace_id": "wX", "label": "dotfiles", "agent_status": "idle",
         "tokens": {"goal": "unrelated project"},
         "worktree": {"repo_key": other_key, "checkout_path": other_key,
                      "is_linked_worktree": False}},
        {"workspace_id": "wC", "label": "hand-opened", "agent_status": "idle",
         "tokens": {"goal": "USER-OWNED -- do not close"}},
        {"workspace_id": "wU", "label": "homeless", "agent_status": "idle",
         "tokens": {"goal": "cwd in no repository"}},
    ],
    "agents": [
        {"workspace_id": "wC", "cwd": wt},
        {"workspace_id": "wC", "cwd": wt},
        {"workspace_id": "wU", "cwd": "/nonexistent/suberu/test/path"},
    ],
}}}, open(sys.argv[1], "w"))' \
  "${snapshot}" "${repo_key}" "${other_key}" "${fx_bare_root}" "${fx_bare_wt}"

scoped="$(/usr/bin/python3 "${render}" --repo-key "${repo_key}" <"${snapshot}")"
readonly scoped

assert_contains "${scoped}" "w3" "the repository's own root workspace is listed"
assert_contains "${scoped}" "wD" "a linked worktree of this repository is listed"
assert_equals "0" "$(printf '%s' "${scoped}" | grep -c 'wX')" \
  "a workspace in another repository is not listed"

# The regression this filter exists to avoid. Herdr records `worktree` only for
# workspaces it created, so filtering on that field alone erases the workspaces
# a human opened by hand -- exactly the ones carrying an owner marker that says
# not to touch them.
assert_contains "${scoped}" "wC" \
  "a hand-opened workspace is attributed through its panes' cwd"
assert_contains "${scoped}" "USER-OWNED" "its owner marker survives the filter"

assert_equals "0" "$(printf '%s' "${scoped}" | grep -c 'wU')" \
  "a workspace whose cwd is in no repository is dropped"

# A session outside any repository has no project to scope to, so it still sees
# everything rather than nothing.
unscoped="$(/usr/bin/python3 "${render}" <"${snapshot}")"
readonly unscoped
assert_contains "${unscoped}" "wX" "without --repo-key every workspace is listed"
assert_contains "${unscoped}" "wU" "without --repo-key nothing is dropped"

# Scoping shrinks the fleet; it must not become a way around the line budget.
budgeted="$(/usr/bin/python3 "${render}" --repo-key "${repo_key}" --max-lines 2 <"${snapshot}")"
assert_equals "2" "$(printf '%s\n' "${budgeted}" | wc -l | tr -d ' ')" \
  "the line budget still applies after filtering"

# Rendering itself is unchanged by scoping.
assert_contains "${scoped}" "(orchestrator)" "the root workspace is still marked"
assert_contains "${scoped}" "chore/img" "branch tokens still render"

finish_tests
