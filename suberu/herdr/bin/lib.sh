#!/usr/bin/env bash
# Shared helpers for Suberu's herdr-side commands.
#
# Sourced, never executed, so it sets no shell options of its own: the caller
# owns `set -euxo pipefail`.
#
# Every herdr call goes through suberu::herdr so that HERDR_BIN_PATH (injected
# when Herdr runs a plugin command) is honoured, and the same scripts still
# work when a human runs them from a normal shell.

# Absolute path to the plugin root, whether invoked by Herdr or by hand.
suberu::plugin_root() {
  if [[ -n "${HERDR_PLUGIN_ROOT:-}" ]]; then
    printf '%s' "${HERDR_PLUGIN_ROOT}"
    return 0
  fi
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

# Durable state lives on disk, not in Herdr's workspace tokens: tokens are
# display-only and carry a TTL, so they cannot be the source of truth.
suberu::state_dir() {
  printf '%s' "${HERDR_PLUGIN_STATE_DIR:-${HOME}/.local/state/herdr/plugins/suberu}"
}

suberu::herdr() {
  "${HERDR_BIN_PATH:-herdr}" "$@"
}

# Start an agent in a freshly created pane.
#
# `worktree create` returns as soon as the pane exists, which is before its
# shell is accepting input; `agent start` rejects that with agent_pane_busy and
# its own --timeout does not cover the gap. Retrying is the only way to close
# it. /bin/sleep is addressed absolutely for the same reason as the interpreter:
# the environment Herdr hands to plugin commands has an unpredictable PATH.
# Local names are prefixed because Bash refuses to shadow a caller's readonly
# variable, and callers naturally hold `pane_id` and `slug` as readonly.
suberu::start_agent_when_ready() {
  local -r suberu_agent_name="$1"
  local -r suberu_target_pane="$2"
  local suberu_attempt=0

  while [[ "${suberu_attempt}" -lt 30 ]]; do
    if suberu::herdr agent start "${suberu_agent_name}" \
      --kind claude --pane "${suberu_target_pane}" >/dev/null 2>&1; then
      return 0
    fi
    suberu_attempt=$((suberu_attempt + 1))
    /bin/sleep 0.5
  done

  suberu::die "pane ${suberu_target_pane} was still not an interactive shell after ${suberu_attempt} attempts"
}

suberu::log() {
  printf 'suberu: %s\n' "$*" >&2
}

suberu::die() {
  suberu::log "$*"
  exit 1
}

# The directory worktrees belong in, asked of git rather than inferred from
# the shape of the path. It is the parent of the git common directory, which
# covers both layouts: `<root>/.git` yields `<root>` (worktrees inside the
# root) and `<base>/repo.git` yields `<base>` (worktrees beside the bare dir).
suberu::worktree_home() {
  local -r repo_path="$1"
  local common_dir

  common_dir="$(git -C "${repo_path}" rev-parse --git-common-dir 2>/dev/null)" ||
    suberu::die "${repo_path} is not a git repository"

  if [[ "${common_dir}" != /* ]]; then
    common_dir="${repo_path}/${common_dir}"
  fi

  cd "${common_dir}/.." && pwd
}

# Compose the flat worktree path for a slug, rejecting anything that would
# nest. Flat placement is what keeps one task equal to one worktree equal to
# one workspace; a nested path silently breaks that mapping.
suberu::flat_path() {
  local -r root="$1"
  local -r slug="${2:-}"

  if [[ -z "${slug}" ]]; then
    suberu::die "task slug must not be empty"
  fi
  if [[ "${slug}" == */* ]]; then
    suberu::die "task slug '${slug}' must not contain '/': worktrees sit flat under ${root}"
  fi
  if [[ "${slug}" == "." || "${slug}" == ".." ]]; then
    suberu::die "task slug '${slug}' is a directory reference, not a name"
  fi
  if [[ "${slug}" == .* ]]; then
    suberu::die "task slug '${slug}' must not start with a dot"
  fi

  printf '%s/%s' "${root}" "${slug}"
}

# Read a value out of a herdr JSON response without depending on jq, which is
# commonly installed through a version manager and therefore absent from the
# environment Herdr hands to plugin commands.
suberu::json_get() {
  local -r path="$1"
  /usr/bin/python3 -c 'import json,sys
value = json.load(sys.stdin)
for key in sys.argv[1].split("."):
    if value is None:
        break
    value = value[int(key)] if isinstance(value, list) else value.get(key)
print("" if value is None else value)' "${path}"
}
