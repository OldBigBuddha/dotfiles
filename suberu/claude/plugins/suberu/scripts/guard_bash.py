"""Decide whether a Bash command must be blocked before it runs.

Reads a PreToolUse payload on stdin. Prints a deny decision on stdout when the
command violates a Suberu invariant; prints nothing when it is allowed. The
exit status is always 0 -- the decision travels in the JSON, so a crash here
is distinguishable from a denial.

Command text is tokenised with shlex rather than matched with regexes because
the invariants are about argument positions ("-C before the git subcommand",
"the terraform subcommand"), which substring matching cannot express: it both
misses `cd x && terraform apply` and wrongly flags `git log -C50`.

Only the stock interpreter at /usr/bin/python3 is assumed, so this file must
stay compatible with Python 3.9 and import nothing outside the stdlib.
"""

import json
import os
import shlex
import sys

import suberu_git

# git's global options that take a separate value argument. Needed so the
# scan for `-C` does not mistake an option's value for the subcommand.
GIT_GLOBAL_OPTS_WITH_VALUE = frozenset(
    ("-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env")
)

# Options that point git at a repository other than the one the cwd is in.
# `-C` is the short spelling of the same move and is handled alongside them.
GIT_REDIRECT_OPTS = frozenset(("--git-dir", "--work-tree"))

# `git worktree add` options that consume a following word. Without these the
# scan for the destination stops at a branch name and checks the wrong thing.
WORKTREE_ADD_OPTS_WITH_VALUE = frozenset(("-b", "-B", "--reason"))

# terraform subcommands that change real infrastructure or state. Everything
# else (plan, show, output, validate, fmt, init, state list, state show) is
# read-only enough to run unattended.
TERRAFORM_DESTRUCTIVE = frozenset(
    ("apply", "destroy", "import", "taint", "untaint", "force-unlock")
)
TERRAFORM_DESTRUCTIVE_SUBSUB = {
    "state": frozenset(("mv", "rm", "push", "replace-provider")),
    "workspace": frozenset(("delete",)),
}

# Shell operators that start a fresh command. Splitting on these is what makes
# `cd /tmp && terraform apply` visible as a terraform invocation.
SEGMENT_SEPARATORS = ("&&", "||", ";", "|", "\n")


def split_segments(command):
    """Split a command line into individually-executed command segments."""
    segments = [command]
    for separator in SEGMENT_SEPARATORS:
        nxt = []
        for segment in segments:
            nxt.extend(segment.split(separator))
        segments = nxt
    return [s.strip() for s in segments if s.strip()]


def tokenize(segment):
    """Tokenise one segment, returning [] when it cannot be parsed."""
    try:
        return shlex.split(segment)
    except ValueError:
        return []


def strip_env_prefix(tokens):
    """Drop leading `VAR=value` assignments and a leading `env`."""
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token == "env":
            index += 1
            continue
        if "=" in token and not token.startswith("-") and "/" not in token.split("=")[0]:
            index += 1
            continue
        break
    return tokens[index:]


def check_git(tokens, cwd, facts):
    """Return a deny reason for a forbidden git invocation, else None."""
    index = 1
    while index < len(tokens) and tokens[index].startswith("-"):
        option = tokens[index]
        # `--git-dir=x` and `--git-dir x` are the same instruction to git.
        name = option.split("=", 1)[0]
        if option.startswith("-C") or name in GIT_REDIRECT_OPTS:
            return (
                "`git {}` crosses worktree boundaries, which makes the working "
                "directory meaningless and is how worktrees get mixed up. Run git "
                "from inside the worktree you mean, or delegate to that worktree's "
                "agent.".format(name)
            )
        if option in GIT_GLOBAL_OPTS_WITH_VALUE:
            index += 2
            continue
        index += 1

    if index + 1 < len(tokens) and tokens[index] == "worktree" and tokens[index + 1] == "add":
        return check_worktree_add(tokens[index + 2 :], cwd, facts)
    return None


def check_worktree_add(args, cwd, facts):
    """Enforce flat worktree placement in the directory git worktrees belong in.

    That directory is derived from git rather than from the shape of the path,
    so both layouts are handled: worktrees sit inside the root of a repository
    with a `.git` directory, and beside a bare `repo.git`.
    """
    if facts is None:
        return None

    # The destination is the first positional word, but `-b`/`-B`/`--reason`
    # each swallow the word after them: in `worktree add -b feat ../outside`
    # the first non-option word is the branch, and checking it instead lets the
    # real destination through unexamined.
    path = None
    index = 0
    while index < len(args):
        arg = args[index]
        if arg in WORKTREE_ADD_OPTS_WITH_VALUE:
            index += 2
            continue
        if arg.startswith("-"):
            index += 1
            continue
        path = arg
        break
    if path is None:
        return None

    resolved = suberu_git.resolve(cwd, path)

    if os.path.dirname(resolved) != facts.home:
        return (
            "Worktree `{}` would land in {}, but worktrees belong flat in {}. One "
            "task is one worktree is one workspace, and nesting breaks that "
            "mapping.".format(path, os.path.dirname(resolved), facts.home)
        )
    return None


def check_terraform(tokens):
    """Return a deny reason for a destructive terraform invocation, else None."""
    args = [token for token in tokens[1:] if not token.startswith("-")]
    if not args:
        return None
    subcommand = args[0]
    if subcommand in TERRAFORM_DESTRUCTIVE:
        return (
            "`terraform {}` changes real infrastructure. Suberu never runs it "
            "unattended: hand the full command to the user instead.".format(subcommand)
        )
    nested = TERRAFORM_DESTRUCTIVE_SUBSUB.get(subcommand)
    if nested and len(args) > 1 and args[1] in nested:
        return (
            "`terraform {} {}` mutates Terraform state. Hand the full command to "
            "the user instead.".format(subcommand, args[1])
        )
    return None


def find_violation(command, cwd, facts):
    """Return the first deny reason across all segments of a command line."""
    current = cwd
    for segment in split_segments(command):
        tokens = strip_env_prefix(tokenize(segment))
        if not tokens:
            continue
        program = tokens[0].rsplit("/", 1)[-1]
        # `cd elsewhere && git worktree add feature-x` places the worktree
        # under `elsewhere`, so the destination has to be measured from there.
        if program == "cd":
            current = suberu_git.apply_cd(current, tokens)
            continue
        if program == "git":
            reason = check_git(tokens, current, facts)
        elif program == "terraform":
            reason = check_terraform(tokens)
        else:
            reason = None
        if reason is not None:
            return reason
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        return 0
    if payload.get("tool_name") != "Bash":
        return 0

    command = payload.get("tool_input", {}).get("command", "")
    cwd = payload.get("cwd", "")

    try:
        facts = suberu_git.repo_facts(cwd)
    except suberu_git.Undetermined as error:
        json.dump(suberu_git.warn(str(error)), sys.stdout, separators=(",", ":"))
        return 0

    reason = find_violation(command, cwd, facts)
    if reason is None:
        return 0

    json.dump(suberu_git.deny(reason), sys.stdout, separators=(",", ":"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
