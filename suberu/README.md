# Suberu (統べる)

A harness for running many Claude Code agents in parallel under Herdr, from one
orchestrator session.

The orchestrator delegates, decides, and reports. It does not implement. Suberu
exists to make that arrangement hold mechanically instead of by good intentions.

## The two layers

Suberu is two plugins for two different systems, because the two jobs have
different scopes.

| Layer | Plugin | Scope | Responsibilities |
| --- | --- | --- | --- |
| Fleet | `herdr/` (a Herdr plugin) | The whole fleet | Create worktrees and workspaces, seed permissions, launch agents, aggregate state, notify |
| Agent | `claude/` (a Claude Code plugin) | One agent's own behaviour | Block boundary-breaking commands, keep worker material out of the orchestrator's context, restore fleet state into a session |

The split is forced by a real constraint: **Claude Code plugins cannot ship
`permissions`.** Suberu works around it by separating distribution from
enforcement. The Herdr layer writes `.claude/settings.local.json` into every new
worktree on the `worktree.created` event; Claude Code's own permission machinery
enforces it from there.

## Invariants

**One task = one worktree = one workspace.** Herdr rolls agent status up per
workspace, so two tasks sharing a workspace collapse the one signal the
orchestrator depends on: which task needs attention. Worktrees are placed flat
directly under the repository root; nesting is rejected structurally, not
discouraged by convention.

**Fleet state lives in Herdr, not in the orchestrator's context.** That is what
makes a polluted orchestrator disposable. Restarting it, or having it compacted,
costs nothing because `SessionStart` and `PostCompact` re-inject the fleet.

**Status arrives as an event, never by polling.** `pane.agent_status_changed`
runs a shell script on the Herdr server. It costs no tokens and cannot hit a
tool timeout, which polling did.

## Context pollution

The orchestrator's job is holding fleet state. Every worker file it reads costs
context permanently and buys nothing the worker could not have summarised. Four
routes in, four closures:

| Route | Closure |
| --- | --- |
| Reading worker source | `guard-context.sh` denies reads into any worktree, except files written as summaries |
| Reading raw agent scrollback | Same guard denies `herdr agent read` and `herdr pane read`; workers report through `.suberu/report.md` instead |
| Polling for status | Replaced by the `pane.agent_status_changed` event |
| Losing state and re-deriving it from logs | `inject-fleet-status.sh` restores it on session start and after compaction |

Investigations that a report cannot answer go to a **throwaway subagent**: the
orchestrator gets the conclusion and none of the search. The axis is routine
versus one-off, not permanent versus temporary — a standing per-workspace
intermediary agent is explicitly rejected, because it would replace a zero-token
event with model calls and make a second agent reconstruct from logs what the
worker already knows.

## Repository layout independence

Nothing infers the repository from directory shape; everything the guards need
is asked of git.

- **Role**: the repository root's git directory *is* the common directory, while
  a linked worktree's sits underneath it. Comparing `git rev-parse --git-dir`
  with `--git-common-dir` therefore separates the two. `SUBERU_ROLE` overrides.
- **Which paths are worker material**: `git worktree list --porcelain`, so
  worktrees are recognised wherever they actually live.
- **Where a new worktree belongs**: the parent of the git common directory —
  `<root>/.git` yields `<root>` (worktrees inside the root), `<base>/repo.git`
  yields `<base>` (worktrees beside the bare directory).

Both a conventional repository and a textbook bare one are covered, and both are
exercised by the test suite against real repositories.

When git cannot be consulted at all, the guards emit a `systemMessage` warning
rather than staying silent. A guardrail that cannot tell must say so: an earlier
version inferred the role from `<cwd>/.git/worktrees`, quietly decided a bare
repository was "not an orchestrator", and disabled every rule without a word.
For the same reason the hook entrypoints resolve their own directory with shell
builtins only — hooks inherit an unpredictable `PATH`, and a guard that fails to
start is indistinguishable from a guard that is not there.

## Install

Suberu is not a stow package. Both halves register themselves.

```
herdr plugin link ~/dotfiles/suberu/herdr
herdr plugin enable suberu
```

In Claude Code:

```
/plugin marketplace add ~/dotfiles/suberu/claude
/plugin install suberu@suberu
/reload-plugins
```

The Claude Code plugin is copied into a cache on install, so it cannot reference
the Herdr half by relative path. It resolves it as `~/dotfiles/suberu/herdr`,
overridable with `SUBERU_HERDR_ROOT`.

## Use

```
herdr/bin/task-start.sh <slug> --goal "<what done looks like>" [--branch <name>] [--base <ref>]
herdr/bin/fleet-status.sh [--max-lines N]
herdr/bin/task-finish.sh <workspace-id>
```

`task-start.sh` is invoked directly rather than as a Herdr action because Herdr
actions receive no argv — they see only `HERDR_PLUGIN_CONTEXT_JSON`, which
cannot carry a goal. `fleet-status` is also exposed as an action, since it needs
no arguments.

`task-finish.sh` removes the checkout and keeps the branch. A checkout is
reproducible; commits that exist only in one are not.

## Tests

```
tests/run.sh
```

Plain Bash, because the units are plain Bash and this machine has no `bats`. The
runner also shellchecks everything shipped. Logic that touches JSON lives in
small Python files invoked through `/usr/bin/python3`: the stock interpreter is
always present, whereas `jq` is usually installed through a version manager and
is therefore missing from the environment Herdr and Claude Code hand to hooks.

Only pure logic is unit-tested — path validation, settings merging, transition
detection, fleet rendering. The thin CLI orchestration around it is verified
live against a throwaway task instead of being mocked.

## Facts established against Herdr 0.7.5

Behaviour the documentation does not state, measured rather than assumed:

- Plugin commands run with the plugin root as the working directory, so relative
  `command` paths in `herdr-plugin.toml` resolve correctly.
- Actions receive no argv. Context arrives only through
  `HERDR_PLUGIN_CONTEXT_JSON`.
- `worktree.created` carries the checkout path at
  `HERDR_PLUGIN_EVENT_JSON.data.worktree.path`.
- `pane.agent_status_changed` carries `{pane_id, workspace_id, agent_status,
  agent}` and **no previous status**, which is why transitions are tracked on
  disk.
- `herdr worktree create` must be given the workspace that holds the bare
  repository; it refuses to run from a linked worktree's workspace.
- Workspace metadata (`workspace report-metadata`) is display-only and carries a
  TTL, so durable task state is kept in `HERDR_PLUGIN_STATE_DIR` and metadata is
  only a mirror.
