#!/usr/bin/env bash
# Print the whole fleet in a handful of lines.
#
# This is the orchestrator's substitute for remembering: state lives in Herdr,
# so a session that was compacted -- or restarted outright -- gets its bearings
# back by running this instead of re-reading scrollback.
set -euxo pipefail

bin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly bin_dir
# shellcheck source=./lib.sh
source "${bin_dir}/lib.sh"

# Scoped to the repository this was run in: an orchestrator manages one
# project, and workspaces belonging to another are not its business. A cwd
# outside any repository has no project to scope to, so it sees everything.
scope=()
if repo_key="$(suberu::repo_key ".")"; then
  scope=(--repo-key "${repo_key}")
fi
readonly repo_key

suberu::herdr api snapshot |
  /usr/bin/python3 "${bin_dir}/render_fleet.py" ${scope[@]+"${scope[@]}"} "$@"

# Named rather than inlined: the reports are the orchestrator's only window into
# what workers did, and it cannot discover them by looking inside a worktree.
if [[ -n "${repo_key}" ]]; then
  printf 'reports: %s/reports/%s/<workspace>.md\n' \
    "$(suberu::state_dir)" "$(suberu::repo_slug ".")"
fi
