"""Collect what every pane of a workspace is currently running.

Usage: pane_report.py <workspace-id> < <herdr pane list output>
Emits a JSON list of {"pane_id", "foreground_processes"} for busy_check.py.

Split from busy_check so the judgement about what counts as busy stays a pure
function of its input and can be tested without a running Herdr server.

Only the stock interpreter at /usr/bin/python3 is assumed.
"""

import json
import os
import subprocess
import sys


def pane_ids(document, workspace_id):
    panes = document.get("result", document).get("panes", []) or []
    return [pane["pane_id"] for pane in panes if pane.get("workspace_id") == workspace_id]


def process_info(herdr, pane_id):
    result = subprocess.run(
        [herdr, "pane", "process-info", "--pane", pane_id],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "pane process-info failed")
    info = json.loads(result.stdout)["result"]["process_info"]
    return info.get("foreground_processes") or []


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("usage: pane_report.py <workspace-id>\n")
        return 2

    herdr = os.environ.get("HERDR_BIN_PATH", "herdr")
    try:
        document = json.load(sys.stdin)
        report = [
            {"pane_id": pane_id, "foreground_processes": process_info(herdr, pane_id)}
            for pane_id in pane_ids(document, argv[1])
        ]
    except (ValueError, KeyError, OSError, RuntimeError) as error:
        # Reporting "nothing is running" because the query failed is exactly the
        # blind teardown this check exists to prevent.
        sys.stderr.write("suberu: could not inspect panes: {}\n".format(error))
        return 1

    json.dump(report, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
