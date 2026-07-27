"""Report work that a teardown would kill.

Reads a JSON list of {"pane_id", "foreground_processes"} on stdin and prints
one line per pane that is running something. Prints nothing when every pane is
merely sitting at a prompt or holding an idle agent.

This exists because closing a workspace once interrupted a fourteen-minute
production image build at its last step. Nothing warned: teardown looked only
at git state, and a long-running process leaves no trace there. Refusing to act
on what it cannot see is the same failure the guards were fixed for.

The judgement is deliberately inverted -- anything not recognised as idle counts
as work. A new build tool must not be silently safe to kill just because nobody
added it to a list.

Only the stock interpreter at /usr/bin/python3 is assumed.
"""

import json
import sys

# Processes that mean "this pane is waiting for input", not "this pane is busy".
# `caffeinate` and the agent binary are how Suberu starts an agent in the first
# place, and a shell at a prompt is the resting state of every pane.
IDLE_PROGRAMS = frozenset(
    (
        "claude",
        "caffeinate",
        "zsh",
        "-zsh",
        "bash",
        "-bash",
        "sh",
        "-sh",
        "dash",
        "fish",
        "login",
        "tmux",
        "nvim",
        "vim",
    )
)


def busy_processes(pane):
    """The commands in one pane that would be lost if it were torn down."""
    return [
        process.get("cmdline") or process.get("argv0", "?")
        for process in pane.get("foreground_processes") or []
        if process.get("argv0") not in IDLE_PROGRAMS
    ]


def main():
    try:
        panes = json.load(sys.stdin)
    except ValueError:
        # Being unable to tell is not evidence of idleness; say so and let the
        # caller decide, rather than reporting an all-clear.
        sys.stderr.write("suberu: could not read pane process information\n")
        return 1

    for pane in panes:
        for command in busy_processes(pane):
            sys.stdout.write("{}: {}\n".format(pane.get("pane_id", "?"), command))
    return 0


if __name__ == "__main__":
    sys.exit(main())
