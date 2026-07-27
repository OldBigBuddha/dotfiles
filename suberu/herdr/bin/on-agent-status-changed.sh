#!/usr/bin/env bash
# pane.agent_status_changed handler: tell the orchestrator when a worker stops.
#
# This replaces polling. Polling cost the orchestrator context on every check
# and, through `herdr agent prompt --wait`, ran into the caller's two-minute
# tool timeout. A handler costs no tokens at all: it is a shell script the
# Herdr server runs, and it only speaks up on a real working -> stopped edge.
set -euxo pipefail

bin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly bin_dir
# shellcheck source=./lib.sh
source "${bin_dir}/lib.sh"

decision="$(/usr/bin/python3 "${bin_dir}/status_transition.py" \
  "$(suberu::state_dir)" "${HERDR_PLUGIN_EVENT_JSON:-{\}}")"
readonly decision

if [[ "${decision}" != "notify" ]]; then
  exit 0
fi

workspace_id="$(printf '%s' "${HERDR_PLUGIN_EVENT_JSON}" | suberu::json_get 'data.workspace_id')"
readonly workspace_id

label="$(suberu::herdr workspace get "${workspace_id}" | suberu::json_get 'result.workspace.label')"
readonly label

suberu::herdr notification show "Suberu: ${label:-${workspace_id}}" \
  --body "Stopped working. Read its .suberu/report.md." \
  --sound request
