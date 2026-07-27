"""Ask git about the repository instead of inferring it from directory shape.

Shared by both PreToolUse guards. Everything they need -- which role the
session is in, where the worktrees actually are, where a new one belongs -- is
something git already knows, so nothing here guesses from layout.

An earlier version inferred the role by looking for `<cwd>/.git/worktrees`.
That happens to hold for a repository whose root carries a `.git` directory,
and fails for a textbook bare repository (`repo.git/worktrees`, no `.git`
anywhere). The guards then decided the session was not an orchestrator and
disabled every rule without a word. Silence was the real defect: a guardrail
that cannot tell must say so, not wave the call through.

Only the stock interpreter at /usr/bin/python3 is assumed, so this file must
stay compatible with Python 3.9 and import nothing outside the stdlib.
"""

import os
import subprocess

ORCHESTRATOR = "orchestrator"
WORKER = "worker"


class Undetermined(Exception):
    """git could not be consulted, so no claim about the repository is safe."""


class Facts(object):
    """What the guards need to know about the repository at a given cwd.

    `home` is the directory new worktrees belong in, which is the parent of the
    git common directory in both supported layouts: `<root>/.git` yields
    `<root>` (worktrees inside the root) and `<base>/repo.git` yields `<base>`
    (worktrees beside the bare directory).
    """

    def __init__(self, role, home, linked_worktrees):
        self.role = role
        self.home = home
        self.linked_worktrees = linked_worktrees

    def contains_worker_material(self, path):
        """True when path sits inside a linked worktree owned by some worker."""
        for worktree in self.linked_worktrees:
            if path == worktree or path.startswith(worktree + os.sep):
                return True
        return False


def _git(cwd, args):
    try:
        return subprocess.run(
            ["git"] + args,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )
    except OSError as error:
        raise Undetermined("git could not be executed: {}".format(error))


def _resolve(cwd, path):
    if not os.path.isabs(path):
        path = os.path.join(cwd, path)
    return os.path.realpath(path)


def repo_facts(cwd):
    """Describe the repository at cwd, or None when cwd is not in one.

    Raises Undetermined when git exists but cannot answer, which callers must
    surface rather than treat as "no repository".
    """
    if not cwd or not os.path.isdir(cwd):
        return None

    revparse = _git(cwd, ["rev-parse", "--git-dir", "--git-common-dir"])
    if revparse.returncode != 0:
        if "not a git repository" in revparse.stderr.lower():
            return None
        raise Undetermined(revparse.stderr.strip() or "git rev-parse failed")

    parts = revparse.stdout.split()
    if len(parts) < 2:
        raise Undetermined("git rev-parse returned an unusable answer")

    git_dir = _resolve(cwd, parts[0])
    common_dir = _resolve(cwd, parts[1])

    # A linked worktree has its own git dir under the common one; the root's
    # git dir *is* the common one.
    role = ORCHESTRATOR if git_dir == common_dir else WORKER
    home = os.path.dirname(common_dir)

    override = os.environ.get("SUBERU_ROLE")
    if override:
        role = override

    linked = []
    if role == ORCHESTRATOR:
        listing = _git(cwd, ["worktree", "list", "--porcelain"])
        if listing.returncode != 0:
            raise Undetermined(listing.stderr.strip() or "git worktree list failed")
        paths = [
            os.path.realpath(line[len("worktree ") :])
            for line in listing.stdout.splitlines()
            if line.startswith("worktree ")
        ]
        # git lists the main checkout (or the bare directory) first; the rest
        # are the linked worktrees that belong to workers.
        linked = paths[1:]

    return Facts(role, home, linked)


def deny(reason):
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }


def warn(reason):
    """Surface an indeterminate result instead of failing open silently."""
    return {"systemMessage": "suberu: guard could not evaluate this call -- {}".format(reason)}
