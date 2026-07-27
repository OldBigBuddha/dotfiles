---
name: delegate
description: Delegate a task to a fresh worker agent in its own worktree and workspace, or decide whether to delegate at all
---

# Delegating work as the orchestrator

You are the orchestrator. Your value is holding fleet state and making
decisions, not implementing. Every worker file you read costs context
permanently and buys nothing the worker could not have summarised.

## Decide the shape of the work first

| The work is | Do this | Why |
| --- | --- | --- |
| Building or changing something | Delegate to a worker (below) | It needs a worktree, a branch, and hours |
| A one-off investigation across many files | Spawn a **throwaway subagent** | You get the conclusion; the search never enters your context |
| Checking who is running and where | `fleet-status.sh` | Free, and already accurate |
| Reading raw agent output | Focus the pane and let the human read it | It has no business in your context |

Spawning a subagent for the investigation case is expected here, not an
exception to be justified. The alternative is reading the files yourself, which
is strictly worse.

Do **not** stand up a permanent per-workspace intermediary agent. Status
already arrives as a zero-token event, and a worker summarising its own work is
cheaper and more faithful than a second agent reconstructing it from logs.

## Starting a worker

```
~/dotfiles/suberu/herdr/bin/task-start.sh <slug> --goal "<what done looks like>" [--branch <name>] [--base <ref>]
```

This creates the worktree flat under the repository root, opens its own
workspace, seeds permissions, starts the agent, and hands it the delegation
brief. One task, one worktree, one workspace -- never two tasks in one
workspace, because Herdr rolls agent status up per workspace and merging them
destroys the signal.

## Writing the goal

The goal is the whole specification the worker gets, so it must carry:

- What done looks like, in terms a machine can check (tests green, types clean)
- The boundary of what may be touched
- Whether `terraform` is in play, and that destructive commands come back to
  the user rather than being run
- That reaching review quality means committing, pushing, and opening a PR
  **without waiting for approval** -- review happens on GitHub, so waiting only
  keeps the work invisible
- That ambiguity is resolved by recording an assumption and continuing, not by
  idling

The brief template covers the standing parts; the goal supplies the specifics.

## Receiving work

A worker that stops triggers a notification. Read its
report — `fleet-status.sh` prints where they live — and nothing else. Do not
read anything inside the worktree itself: that makes Claude Code load the tree's
`CLAUDE.md` and skill manifest, which costs more context than the report saves.
If the report is inadequate,
ask that worker to improve it -- do not go read its source to compensate, which
defeats the entire arrangement.

## Finishing

```
~/dotfiles/suberu/herdr/bin/task-finish.sh <workspace-id>
```

Closes the workspace and removes the checkout. The branch survives.
