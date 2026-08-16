---
name: relabel-herdr-session
description: "Rename the current Herdr workspace, tab, and agent so the sidebar shows at a glance what this session is doing. Use when the user asks to refresh, rename, or clean up the session name, tab title, or agent name, or complains that the sidebar label is truncated or stale. Requires HERDR_ENV=1."
---

# Relabel a Herdr session

The Herdr sidebar shows two stacked lines per session — the workspace label above,
the tab label below — and truncates each to the sidebar width. A session whose
labels are defaults (the repo name, `1`) or a single long phrase is unidentifiable
at a glance.

Goal: after this skill runs, the sidebar identifies **what the session is for** and
**what it is doing right now**, with neither line truncated.

For the full Herdr CLI (layout, starting agents, reading panes), see the `herdr`
skill.

## The rule that makes labels readable

Truncation is a sidebar-width constraint and cannot be turned off. What you control
is the information density of the two lines, so split the roles:

| Line | Carries | Example |
|---|---|---|
| workspace label | what the session is for — stable for the session's life | `intel-slots` |
| tab label | what it is doing now — changes as work moves on | `drain` |

Two failure modes to avoid:

- **A label that carries no information.** The repo name is the usual offender: if
  every workspace is the same repo, that line identifies nothing and wastes the
  wider of the two lines. Replace it.
- **Duplicating the same text on both lines.** Halves the available information for
  no benefit.

Keep each label short enough to survive truncation. Around ten characters is safe;
prefer a compact slug over a descriptive phrase, and front-load the distinguishing
word so a truncated label is still recognisable.

## Procedure

Confirm the session is Herdr-managed, then read the identifiers Herdr injected —
never guess them:

```bash
env | grep -i herdr
```

`HERDR_WORKSPACE_ID`, `HERDR_TAB_ID`, and `HERDR_PANE_ID` are the targets. Read the
current labels before changing them, so the summary can report what actually
changed:

```bash
herdr workspace get "$HERDR_WORKSPACE_ID"
herdr tab get "$HERDR_TAB_ID"
herdr agent list
```

Derive the labels from what the session has actually been doing, not from its
opening request — those diverge in a long session, and the opening request is
usually the stale thing the user is complaining about. Then apply:

```bash
herdr workspace rename "$HERDR_WORKSPACE_ID" "<what the session is for>"
herdr tab rename "$HERDR_TAB_ID" "<what it is doing now>"
herdr agent rename "$HERDR_PANE_ID" <agent-name>
```

Each command returns the updated object; confirm the new label from that response
rather than re-reading.

## Constraints

- **Agent names must match `[a-z][a-z0-9_-]{0,31}`** and be unique among live
  agents. Workspace and tab labels are free-form.
- **An agent name is bound to the pane's current occupant**, not to the pane. It is
  cleared when that agent exits, is released, or is replaced — it is not a durable
  label. `--clear` removes it explicitly.
- **Agent commands accept a live agent name or a pane ID only** — not a terminal ID,
  not an agent-kind label such as `claude`.
- **`terminal_title` cannot be changed from Herdr.** The agent harness owns it, so
  it keeps showing the session's opening request. It appears in `herdr agent list`
  alongside the labels you did set, so state plainly that this one line stays stale
  rather than letting the user think the rename failed.

## Renaming other sessions

The same commands work on any workspace, tab, or pane ID from `herdr workspace list`
/ `herdr agent list`. Before relabelling a session you do not own, check whether
anything else keys off its label — a fleet-management layer may display or reference
it. Labels are display-only, but confirm with the user first.

## Reporting

Report a before/after table of the three targets, and say explicitly that
`terminal_title` was not changed and why. If a label may still truncate, say so and
offer a shorter alternative rather than assuming it fit.
