"""Keep worker material out of the orchestrator's context window.

Reads a PreToolUse payload on stdin. Prints a deny decision on stdout when the
orchestrator tries to pull worker material -- implementation files or raw agent
scrollback -- into its own context. Prints nothing otherwise. The exit status
is always 0; the decision travels in the JSON.

The orchestrator's value comes from holding fleet state, not implementation
detail: every worker file it reads costs context permanently and buys nothing
the worker could not summarise. So the orchestrator reads summaries and
delegates everything else. Workers own their worktree and are unrestricted.

Role is inferred from the payload's cwd, with no subprocess and no
configuration: the repository root keeps `.git` as a directory containing
`worktrees/`, while a linked worktree keeps `.git` as a file holding a gitdir
pointer. An `SUBERU_ROLE` environment variable overrides the inference.

Only the stock interpreter at /usr/bin/python3 is assumed, so this file must
stay compatible with Python 3.9 and import nothing outside the stdlib.
"""

import json
import os
import shlex
import sys

# Files that exist precisely to be read by the orchestrator. Everything else
# inside a worktree is the worker's business.
ALLOWED_BASENAMES = frozenset(("report.md", "CLAUDE.local.md", "CLAUDE.md"))
ALLOWED_SUFFIXES = (".plan.md",)
ALLOWED_DIR_MARKER = "/.suberu/"

# Tool inputs that name a filesystem path, by tool.
PATH_FIELDS = ("file_path", "path", "notebook_path")

# herdr subcommands that emit raw terminal scrollback.
SCROLL_READERS = (("agent", "read"), ("pane", "read"))

# Shell programs whose whole purpose is dumping file contents.
FILE_READERS = frozenset(
    ("cat", "head", "tail", "less", "more", "bat", "grep", "rg", "sed", "awk", "nl", "od")
)

SEGMENT_SEPARATORS = ("&&", "||", ";", "|", "\n")

DELEGATE_HINT = (
    "The orchestrator holds fleet state, not implementation detail. Ask that "
    "worktree's agent, read its .suberu/report.md, or spawn a throwaway subagent "
    "for a one-off investigation."
)


def is_orchestrator(cwd):
    """True when cwd is the repository root that owns the linked worktrees."""
    override = os.environ.get("SUBERU_ROLE")
    if override:
        return override == "orchestrator"
    if not cwd:
        return False
    return os.path.isdir(os.path.join(cwd, ".git", "worktrees"))


def resolve(cwd, path):
    """Absolutise and normalise a possibly-relative tool path."""
    if not os.path.isabs(path):
        path = os.path.join(cwd, path)
    return os.path.realpath(path)


def is_summary(path):
    """True for files written to be consumed by the orchestrator."""
    if os.path.basename(path) in ALLOWED_BASENAMES:
        return True
    if ALLOWED_DIR_MARKER in path + "/":
        return True
    return any(path.endswith(suffix) for suffix in ALLOWED_SUFFIXES)


def inside_worktree(root, path):
    """True when path sits inside one of root's worktrees rather than at root."""
    root = os.path.realpath(root)
    if path == root or not path.startswith(root + os.sep):
        return False
    remainder = path[len(root) + 1 :]
    if remainder.split(os.sep)[0] == ".git":
        return False
    return os.sep in remainder


def check_path(root, cwd, raw_path):
    """Return a deny reason for a forbidden path access, else None."""
    if not raw_path:
        return None
    path = resolve(cwd, raw_path)
    if not inside_worktree(root, path):
        return None
    if is_summary(path):
        return None
    return "`{}` belongs to a worker's worktree. {}".format(raw_path, DELEGATE_HINT)


def split_segments(command):
    segments = [command]
    for separator in SEGMENT_SEPARATORS:
        nxt = []
        for segment in segments:
            nxt.extend(segment.split(separator))
        segments = nxt
    return [s.strip() for s in segments if s.strip()]


def check_command(root, cwd, command):
    """Return a deny reason for a forbidden Bash command, else None."""
    for segment in split_segments(command):
        try:
            tokens = shlex.split(segment)
        except ValueError:
            continue
        if not tokens:
            continue
        program = tokens[0].rsplit("/", 1)[-1]

        if program == "herdr":
            positional = [token for token in tokens[1:] if not token.startswith("-")]
            for group, verb in SCROLL_READERS:
                if positional[:1] == [group] and verb in positional[1:2]:
                    return (
                        "`herdr {} {}` dumps raw scrollback into the orchestrator's "
                        "context. {}".format(group, verb, DELEGATE_HINT)
                    )
            continue

        if program in FILE_READERS:
            for token in tokens[1:]:
                if token.startswith("-"):
                    continue
                reason = check_path(root, cwd, token)
                if reason is not None:
                    return reason
    return None


def find_violation(payload):
    cwd = payload.get("cwd", "")
    if not is_orchestrator(cwd):
        return None
    tool_input = payload.get("tool_input", {}) or {}

    if payload.get("tool_name") == "Bash":
        return check_command(cwd, cwd, tool_input.get("command", ""))

    for field in PATH_FIELDS:
        reason = check_path(cwd, cwd, tool_input.get(field, ""))
        if reason is not None:
            return reason
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        return 0

    reason = find_violation(payload)
    if reason is None:
        return 0

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        },
        sys.stdout,
        separators=(",", ":"),
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
