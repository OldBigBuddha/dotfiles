#!/usr/bin/env bash
# PreToolUse entrypoint for the context-pollution guard. See guard_context.py.
#
# Trace mode is off on purpose: Claude Code surfaces a hook's stderr as the
# blocking reason, so `set -x` output would corrupt the message shown to the
# model and the user.
set -euo pipefail

# Resolved with parameter expansion and shell builtins only; see guard-bash.sh.
source_path="${BASH_SOURCE[0]}"
source_dir="${source_path%/*}"
[[ "${source_dir}" == "${source_path}" ]] && source_dir="."
script_dir="$(cd "${source_dir}" && pwd)"
readonly source_path source_dir script_dir

exec /usr/bin/python3 "${script_dir}/guard_context.py"
