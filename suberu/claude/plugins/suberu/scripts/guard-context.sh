#!/usr/bin/env bash
# PreToolUse entrypoint for the context-pollution guard. See guard_context.py.
#
# Trace mode is off on purpose: Claude Code surfaces a hook's stderr as the
# blocking reason, so `set -x` output would corrupt the message shown to the
# model and the user.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir

exec /usr/bin/python3 "${script_dir}/guard_context.py"
