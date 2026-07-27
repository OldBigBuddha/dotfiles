#!/usr/bin/env bash
# PreToolUse entrypoint for Bash commands. See guard_bash.py for the rules.
#
# Trace mode is off on purpose: Claude Code surfaces a hook's stderr as the
# blocking reason, so `set -x` output would corrupt the message shown to the
# model and the user.
#
# /usr/bin/python3 is addressed absolutely because hooks inherit a shell whose
# PATH may not include mise-managed interpreters.
set -euo pipefail

# Resolved with parameter expansion and shell builtins only. Hooks inherit an
# unpredictable PATH, and this guard must still work when even `dirname` is
# missing -- failing to start is indistinguishable from having no guard.
source_path="${BASH_SOURCE[0]}"
source_dir="${source_path%/*}"
[[ "${source_dir}" == "${source_path}" ]] && source_dir="."
script_dir="$(cd "${source_dir}" && pwd)"
readonly source_path source_dir script_dir

exec /usr/bin/python3 "${script_dir}/guard_bash.py"
