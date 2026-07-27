#!/usr/bin/env bash
# Stand up one task: worktree, workspace, permissions, agent, brief, state.
#
# Usage: task-start.sh <slug> --goal <text> [--branch <name>] [--base <ref>]
#
# One task equals one worktree equals one workspace. Herdr rolls agent status
# up per workspace, so putting two tasks in one workspace collapses the signal
# the orchestrator relies on; the slug is therefore validated to be a single
# path component and the worktree is placed flat under the repository root.
#
# Invoked directly rather than through `herdr plugin action invoke`, because
# actions receive no argv -- they only see HERDR_PLUGIN_CONTEXT_JSON, which
# cannot carry a goal.
set -euxo pipefail

bin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly bin_dir
# shellcheck source=./lib.sh
source "${bin_dir}/lib.sh"

plugin_root="$(suberu::plugin_root)"
readonly plugin_root

slug=""
goal=""
branch=""
base="HEAD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --goal) goal="$2"; shift 2 ;;
    --branch) branch="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    -*) suberu::die "unknown option: $1" ;;
    *) slug="$1"; shift ;;
  esac
done

readonly slug goal base
[[ -n "${goal}" ]] || suberu::die "--goal is required: a worker with no stated goal cannot be reviewed"
: "${branch:=feat/${slug}}"
readonly branch

# The parent workspace is the one holding the bare repository. Herdr refuses
# worktree creation from a linked worktree's workspace, so this is resolved
# rather than assumed from whatever happens to be focused.
snapshot="$(suberu::herdr api snapshot)"
readonly snapshot
parent_workspace="$(printf '%s' "${snapshot}" | /usr/bin/python3 -c 'import json,sys
snapshot = json.load(sys.stdin)["result"]["snapshot"]
for workspace in snapshot.get("workspaces", []):
    worktree = workspace.get("worktree") or {}
    if worktree.get("repo_root") and not worktree.get("is_linked_worktree", True):
        print(workspace["workspace_id"], worktree["repo_root"])
        break')"
readonly parent_workspace
[[ -n "${parent_workspace}" ]] || suberu::die "no workspace is open on the repository root"

readonly parent_id="${parent_workspace%% *}"
readonly repo_root="${parent_workspace#* }"
worktree_path="$(suberu::flat_path "${repo_root}" "${slug}")"
readonly worktree_path

# worktree.created fires here, which is what seeds .claude/settings.local.json.
created="$(suberu::herdr worktree create \
  --workspace "${parent_id}" \
  --path "${worktree_path}" \
  --branch "${branch}" \
  --base "${base}" \
  --label "${slug}" \
  --no-focus --json)"
readonly created

workspace_id="$(printf '%s' "${created}" | suberu::json_get 'result.workspace.workspace_id')"
readonly workspace_id
pane_id="$(printf '%s' "${created}" | suberu::json_get 'result.root_pane.pane_id')"
readonly pane_id

suberu::start_agent_when_ready "${slug}" "${pane_id}"

# Render the brief with the task's own facts before handing it over.
brief="$(/usr/bin/python3 -c 'import sys
template = open(sys.argv[1]).read()
for key, value in zip(("{{GOAL}}", "{{WORKTREE}}", "{{BRANCH}}"), sys.argv[2:]):
    template = template.replace(key, value)
sys.stdout.write(template)' \
  "${plugin_root}/templates/delegation-brief.md" "${goal}" "${worktree_path}" "${branch}")"
readonly brief

# No --wait: the status event handler reports completion, so blocking here
# would only re-import the timeout problem the event model removed.
suberu::herdr agent prompt "${slug}" "${brief}" >/dev/null

# Tokens are display-only and expire; the durable record is on disk.
state_file="$(suberu::state_dir)/tasks/${workspace_id}.json"
readonly state_file
mkdir -p "$(dirname "${state_file}")"
/usr/bin/python3 -c 'import json,sys
json.dump(dict(zip(("workspace_id","slug","goal","branch","worktree"), sys.argv[2:])), open(sys.argv[1],"w"), indent=2)' \
  "${state_file}" "${workspace_id}" "${slug}" "${goal}" "${branch}" "${worktree_path}"

suberu::herdr workspace report-metadata "${workspace_id}" \
  --source suberu --token "goal=${goal}" --token "branch=${branch}" >/dev/null

suberu::log "started ${slug} in ${workspace_id} at ${worktree_path}"
