#!/usr/bin/env bash
# SessionStart / PostCompact: hand the orchestrator its fleet back.
#
# Fleet state lives in Herdr, not in this session's context. That is what makes
# a polluted orchestrator disposable: restarting it -- or being compacted --
# costs nothing, because this hook restores the picture. Without it the session
# would rebuild that picture by reading scrollback, which is the pollution the
# harness exists to prevent.
#
# Claude Code copies an installed plugin into a cache, so this script cannot
# reference the herdr-side plugin by a relative path; it resolves it by
# convention, overridable with SUBERU_HERDR_ROOT.
#
# Trace mode is off: stdout here becomes session context, and stderr noise on a
# non-orchestrator machine would be pure distraction. Failure is silent by
# design -- a missing fleet is not a reason to block a session from starting.
set -euo pipefail

readonly herdr_root="${SUBERU_HERDR_ROOT:-${HOME}/dotfiles/suberu/herdr}"
readonly herdr_bin="${HERDR_BIN_PATH:-herdr}"

if ! command -v "${herdr_bin}" >/dev/null 2>&1; then
  exit 0
fi
if [[ ! -f "${herdr_root}/bin/render_fleet.py" ]]; then
  exit 0
fi

fleet="$("${herdr_bin}" api snapshot 2>/dev/null |
  /usr/bin/python3 "${herdr_root}/bin/render_fleet.py" 2>/dev/null || true)"

if [[ -z "${fleet}" ]]; then
  exit 0
fi

printf 'Fleet (from herdr, authoritative -- do not reconstruct this by reading scrollback):\n%s\n' "${fleet}"
