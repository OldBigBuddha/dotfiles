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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir

exec /usr/bin/python3 "${script_dir}/guard_bash.py"
