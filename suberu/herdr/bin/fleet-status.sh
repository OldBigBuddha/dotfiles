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

suberu::herdr api snapshot | /usr/bin/python3 "${bin_dir}/render_fleet.py" "$@"
