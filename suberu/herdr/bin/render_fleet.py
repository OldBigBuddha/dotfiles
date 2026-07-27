"""Render the fleet as a few lines the orchestrator can hold in context.

Usage: render_fleet.py [--max-lines N] [--repo-key PATH] < <herdr api snapshot output>

This is the orchestrator's whole view of the fleet, so it is deliberately
lossy. A summary that grows with the number of workers would reintroduce the
pollution it exists to prevent, hence the hard line budget: one line per
workspace, truncated with a count of what was dropped.

An orchestrator manages one repository, so `--repo-key` narrows the fleet to
the workspaces belonging to it. Without the option nothing is filtered: a
session outside any repository has no project to scope to, and showing it an
empty fleet would be a worse answer than showing it everything.

Only the stock interpreter at /usr/bin/python3 is assumed, so this file must
stay compatible with Python 3.9 and import nothing outside the stdlib.
"""

import json
import os
import subprocess
import sys

DEFAULT_MAX_LINES = 24
GOAL_WIDTH = 56


def workspaces_of(document):
    result = document.get("result", document)
    snapshot = result.get("snapshot", result)
    return snapshot.get("workspaces", []) or []


def agents_of(document):
    result = document.get("result", document)
    snapshot = result.get("snapshot", result)
    return snapshot.get("agents", []) or []


def repo_key_of_checkout(path):
    """The git common directory a checkout belongs to, or None.

    Asking git is the only reliable answer: worktrees of one repository sit in
    unrelated-looking directories, and two sibling directories can belong to
    different repositories entirely.
    """
    try:
        completed = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            cwd=path,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )
    except OSError:
        # A cwd that no longer exists takes this branch, which is a workspace
        # whose pane has outlived its directory -- unattributable, not fatal.
        return None
    if completed.returncode != 0:
        return None
    answer = completed.stdout.strip()
    if not answer:
        return None
    if not os.path.isabs(answer):
        answer = os.path.join(path, answer)
    return os.path.realpath(answer)


def repo_key_of(workspace, agents, cache):
    """Which repository a workspace belongs to, or None when it cannot be told.

    Herdr fills in `worktree` for the workspaces it created, and leaves it out
    for a workspace someone opened by hand. Trusting that field alone would
    therefore drop precisely the hand-opened workspaces -- the ones most likely
    to carry an owner marker asking that they be left alone -- so the panes'
    working directory is consulted as a second source.
    """
    worktree = workspace.get("worktree") or {}
    recorded = worktree.get("repo_key")
    if recorded:
        return os.path.realpath(recorded)

    workspace_id = workspace.get("workspace_id")
    for agent in agents:
        if agent.get("workspace_id") != workspace_id:
            continue
        cwd = agent.get("cwd") or agent.get("foreground_cwd")
        if not cwd:
            continue
        # Panes of one workspace usually share a directory, and this runs
        # inside a hook with a ten-second budget.
        if cwd not in cache:
            cache[cwd] = repo_key_of_checkout(cwd)
        if cache[cwd]:
            return cache[cwd]
    return None


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
    repo_key = None
    if "--repo-key" in argv:
        repo_key = os.path.realpath(argv[argv.index("--repo-key") + 1])

    try:
        document = json.load(sys.stdin)
    except ValueError:
        sys.stderr.write("suberu: could not parse snapshot\n")
        return 1

    workspaces = workspaces_of(document)
    if repo_key is not None:
        agents = agents_of(document)
        cache = {}
        workspaces = [
            workspace
            for workspace in workspaces
            if repo_key_of(workspace, agents, cache) == repo_key
        ]

    lines = [describe(workspace) for workspace in workspaces]
    if len(lines) > max_lines:
        dropped = len(lines) - (max_lines - 1)
        lines = lines[: max_lines - 1] + ["... {} more workspace(s) omitted".format(dropped)]

    sys.stdout.write("\n".join(lines))
    if lines:
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
