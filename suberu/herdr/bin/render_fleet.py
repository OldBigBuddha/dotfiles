"""Render the fleet as a few lines the orchestrator can hold in context.

Usage: render_fleet.py [--max-lines N] < <herdr api snapshot output>

This is the orchestrator's whole view of the fleet, so it is deliberately
lossy. A summary that grows with the number of workers would reintroduce the
pollution it exists to prevent, hence the hard line budget: one line per
workspace, truncated with a count of what was dropped.

Only the stock interpreter at /usr/bin/python3 is assumed.
"""

import json
import sys

DEFAULT_MAX_LINES = 24
GOAL_WIDTH = 56


def workspaces_of(document):
    result = document.get("result", document)
    snapshot = result.get("snapshot", result)
    return snapshot.get("workspaces", []) or []


def describe(workspace):
    """One line per workspace: identity, status, and the task it carries."""
    tokens = workspace.get("tokens") or {}
    parts = [
        "{:4}".format(workspace.get("workspace_id", "?")),
        "{:20}".format(workspace.get("label", "?")[:20]),
        "{:8}".format(workspace.get("agent_status", "?")),
    ]
    branch = tokens.get("branch")
    if branch:
        parts.append(branch)
    goal = tokens.get("goal")
    if goal:
        # Budgeting lines is not enough: one workspace with a long goal can
        # outweigh the rest of the fleet, so each line is bounded too.
        goal = goal.replace("\n", " ")
        if len(goal) > GOAL_WIDTH:
            goal = goal[: GOAL_WIDTH - 1].rstrip() + "…"
        parts.append("-- {}".format(goal))
    if not branch and not goal:
        worktree = workspace.get("worktree") or {}
        if not worktree.get("is_linked_worktree", True):
            parts.append("(orchestrator)")
    return " ".join(parts).rstrip()


def main(argv):
    max_lines = DEFAULT_MAX_LINES
    if "--max-lines" in argv:
        max_lines = int(argv[argv.index("--max-lines") + 1])

    try:
        document = json.load(sys.stdin)
    except ValueError:
        sys.stderr.write("suberu: could not parse snapshot\n")
        return 1

    lines = [describe(workspace) for workspace in workspaces_of(document)]
    if len(lines) > max_lines:
        dropped = len(lines) - (max_lines - 1)
        lines = lines[: max_lines - 1] + ["... {} more workspace(s) omitted".format(dropped)]

    sys.stdout.write("\n".join(lines))
    if lines:
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
