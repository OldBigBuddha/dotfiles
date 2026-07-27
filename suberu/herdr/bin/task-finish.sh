#!/usr/bin/env bash
# Tear down a finished task: close the workspace, drop the checkout, keep the
# branch.
#
# Usage: task-finish.sh <workspace-id>
#
# The branch survives on purpose. A checkout is reproducible; commits that only
# exist in one are not, and a teardown that could lose them would make the
# orchestrator hesitate to clean up at all.
set -euxo pipefail

bin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly bin_dir
# shellcheck source=./lib.sh
source "${bin_dir}/lib.sh"

workspace_id=""
force=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) force="--force"; shift ;;
    -*) suberu::die "unknown option: $1" ;;
    *) workspace_id="$1"; shift ;;
  esac
done
readonly workspace_id force

[[ -n "${workspace_id}" ]] || suberu::die "usage: task-finish.sh [--force] <workspace-id>"

state_file="$(suberu::state_dir)/tasks/${workspace_id}.json"
readonly state_file

# Only tear down what Suberu created. This command removes a checkout, so
# pointed at a workspace someone opened by hand -- the repository's main
# worktree, say -- it would delete work Suberu never had any claim to.
if [[ ! -f "${state_file}" ]]; then
  suberu::die "${workspace_id} is not a Suberu task (no record in $(suberu::state_dir)/tasks); close it with \`herdr workspace close\` instead"
fi

# A pane can be running something that leaves no trace in git state. Tearing
# down blind once killed a fourteen-minute production image build at its final
# step, and nothing warned.
if [[ -z "${force}" ]]; then
  busy="$(suberu::pane_process_report "${workspace_id}" |
    /usr/bin/python3 "${bin_dir}/busy_check.py")"
  readonly busy

  if [[ -n "${busy}" ]]; then
    suberu::log "${workspace_id} still has work running:"
    printf '%s\n' "${busy}" >&2
    suberu::die "refusing to tear it down; wait for it to finish, or re-run with --force to kill it"
  fi
fi

# Herdr refuses to drop a checkout holding uncommitted or untracked work. That
# refusal is the point: the worker's report and any unpushed edits live there,
# and discarding them silently would be worse than leaving the workspace open.
if ! suberu::herdr worktree remove --workspace "${workspace_id}" ${force:+"${force}"} --json; then
  if [[ -z "${force}" ]]; then
    suberu::die "${workspace_id} still has uncommitted or untracked files; review them, then re-run with --force"
  fi
  suberu::die "could not remove the worktree for ${workspace_id}"
fi

state_file="$(suberu::state_dir)/tasks/${workspace_id}.json"
readonly state_file
rm -f "${state_file}"

suberu::log "finished ${workspace_id}; its branch is untouched"
