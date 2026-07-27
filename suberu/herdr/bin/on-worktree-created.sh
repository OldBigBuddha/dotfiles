#!/usr/bin/env bash
# worktree.created handler: make a fresh worktree safe to hand to an agent.
#
# This is the layer that solves a structural gap: Claude Code plugins cannot
# ship `permissions`, so nothing can distribute them by installation. Herdr can
# write them at worktree-creation time instead, and Claude Code enforces them
# from there. Distribution and enforcement live in different systems on purpose.
#
# Runs for every worktree Herdr creates, including ones a human made by hand,
# which is what makes the guarantee unconditional.
set -euxo pipefail

bin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly bin_dir
# shellcheck source=./lib.sh
source "${bin_dir}/lib.sh"

plugin_root="$(suberu::plugin_root)"
readonly plugin_root

checkout_path="$(printf '%s' "${HERDR_PLUGIN_EVENT_JSON:-}" | suberu::json_get 'data.worktree.path')"
readonly checkout_path

if [[ -z "${checkout_path}" || ! -d "${checkout_path}" ]]; then
  suberu::die "worktree.created carried no usable checkout path"
fi

/usr/bin/python3 "${bin_dir}/merge_settings.py" \
  "${plugin_root}/templates/worker-settings.local.json" \
  "${checkout_path}/.claude/settings.local.json"

# The report is the only channel back to the orchestrator, so the directory
# exists from the start rather than depending on the worker to create it.
mkdir -p "${checkout_path}/.suberu"

suberu::log "seeded ${checkout_path}"
