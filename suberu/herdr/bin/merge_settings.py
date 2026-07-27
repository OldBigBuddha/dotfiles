"""Seed a worktree's Claude Code settings with Suberu's permission baseline.

Usage: merge_settings.py <template.json> <target.json>

Claude Code plugins cannot ship `permissions`, so Suberu materialises them
instead: the herdr layer writes them into each new worktree and Claude Code's
own permission machinery enforces them.

The merge is additive and idempotent. A worktree may already carry settings a
human wrote, and silently replacing them would be a worse failure than missing
a guardrail: unknown keys are preserved, lists are unioned with the template's
entries appended in order, and re-running changes nothing.

Only the stock interpreter at /usr/bin/python3 is assumed.
"""

import json
import os
import sys


def merge(template, target):
    """Recursively merge template into target, preferring target's own values."""
    if isinstance(template, dict) and isinstance(target, dict):
        merged = dict(target)
        for key, value in template.items():
            merged[key] = merge(value, target[key]) if key in target else value
        return merged
    if isinstance(template, list) and isinstance(target, list):
        merged = list(target)
        for item in template:
            if item not in merged:
                merged.append(item)
        return merged
    # A scalar already chosen by the worktree wins over the template's default.
    return target


def load(path):
    if not os.path.exists(path):
        return {}
    with open(path) as handle:
        text = handle.read().strip()
    return json.loads(text) if text else {}


def main(argv):
    if len(argv) != 3:
        sys.stderr.write("usage: merge_settings.py <template.json> <target.json>\n")
        return 2

    template_path, target_path = argv[1], argv[2]
    merged = merge(load(template_path), load(target_path))

    os.makedirs(os.path.dirname(os.path.abspath(target_path)), exist_ok=True)
    with open(target_path, "w") as handle:
        json.dump(merged, handle, indent=2, sort_keys=True)
        handle.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
