"""Decide whether an agent status change is worth the orchestrator's attention.

Usage: status_transition.py <state_dir> <event_json>
Prints "notify" when the orchestrator should be told, nothing otherwise.

`pane.agent_status_changed` reports the new status only -- there is no previous
value in the payload -- so the interesting fact ("a worker just stopped
working") is not directly observable. This keeps the last status per pane on
disk and reports the transition itself.

Only a working -> not-working edge matters. Every other edge is noise: a worker
going back to work, or a status re-reported at the same value, tells the
orchestrator nothing it can act on.

Only the stock interpreter at /usr/bin/python3 is assumed.
"""

import json
import os
import sys

WORKING = "working"


def state_path(state_dir, pane_id):
    return os.path.join(state_dir, "status", pane_id.replace(":", "_") + ".status")


def read_previous(path):
    try:
        with open(path) as handle:
            return handle.read().strip()
    except OSError:
        return ""


def write_current(path, status):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as handle:
        handle.write(status)


def main(argv):
    if len(argv) != 3:
        sys.stderr.write("usage: status_transition.py <state_dir> <event_json>\n")
        return 2

    state_dir = argv[1]
    try:
        event = json.loads(argv[2])
    except ValueError:
        return 0

    data = event.get("data", event) or {}
    pane_id = data.get("pane_id")
    status = data.get("agent_status", "")
    if not pane_id or not status:
        return 0

    path = state_path(state_dir, pane_id)
    previous = read_previous(path)
    write_current(path, status)

    if previous == WORKING and status != WORKING:
        sys.stdout.write("notify")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
