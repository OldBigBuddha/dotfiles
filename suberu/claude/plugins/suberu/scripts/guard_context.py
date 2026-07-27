"""Keep worker material out of the orchestrator's context window.

Reads a PreToolUse payload on stdin. Prints a deny decision on stdout when the
orchestrator tries to pull worker material -- implementation files or raw agent
scrollback -- into its own context. Prints nothing when the call is fine, and a
warning when it cannot tell. The exit status is always 0; the decision travels
in the JSON.

The orchestrator's value comes from holding fleet state, not implementation
detail: every worker file it reads costs context permanently and buys nothing
the worker could not summarise. So the orchestrator reads summaries and
delegates everything else. Workers own their worktree and are unrestricted.

Role and worktree locations come from git (see suberu_git), so no repository
layout is assumed.

Only the stock interpreter at /usr/bin/python3 is assumed, so this file must
stay compatible with Python 3.9 and import nothing outside the stdlib.
"""

import json
import os
import shlex
import sys

import suberu_git

# Files that exist precisely to be read by the orchestrator. Everything else
# inside a worktree is the worker's business.
ALLOWED_BASENAMES = frozenset(("report.md", "CLAUDE.local.md", "CLAUDE.md"))
ALLOWED_SUFFIXES = (".plan.md",)
ALLOWED_DIR_MARKER = "/.suberu/"

# Tool inputs that name a filesystem path.
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


def is_summary(path):
    """True for files written to be consumed by the orchestrator."""
    if os.path.basename(path) in ALLOWED_BASENAMES:
        return True
    if ALLOWED_DIR_MARKER in path + "/":
        return True
    return any(path.endswith(suffix) for suffix in ALLOWED_SUFFIXES)


def check_path(facts, cwd, raw_path):
    """Return a deny reason for a forbidden path access, else None."""
    if not raw_path:
        return None
    path = suberu_git.resolve(cwd, raw_path)
    if not facts.contains_worker_material(path):
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


def check_command(facts, cwd, command):
    """Return a deny reason for a forbidden Bash command, else None."""
    current = cwd
    for segment in split_segments(command):
        try:
            tokens = shlex.split(segment)
        except ValueError:
            continue
        if not tokens:
            continue
        program = tokens[0].rsplit("/", 1)[-1]

        # `cd <worktree> && cat src.py` names no worktree in the read itself;
        # the `cd` is the only thing that says where `src.py` lives.
        if program == "cd":
            current = suberu_git.apply_cd(current, tokens)
            continue

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
                reason = check_path(facts, current, token)
                if reason is not None:
                    return reason
    return None


def evaluate(payload):
    """Return the JSON decision for a payload, or None to stay silent."""
    cwd = payload.get("cwd", "")
    try:
        facts = suberu_git.repo_facts(cwd)
    except suberu_git.Undetermined as error:
        return suberu_git.warn(str(error))

    if facts is None or facts.role != suberu_git.ORCHESTRATOR:
        return None

    tool_input = payload.get("tool_input", {}) or {}

    if payload.get("tool_name") == "Bash":
        reason = check_command(facts, cwd, tool_input.get("command", ""))
    else:
        reason = None
        for field in PATH_FIELDS:
            reason = check_path(facts, cwd, tool_input.get(field, ""))
            if reason is not None:
                break

    return suberu_git.deny(reason) if reason is not None else None


def main():
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        return 0

    decision = evaluate(payload)
    if decision is not None:
        json.dump(decision, sys.stdout, separators=(",", ":"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
