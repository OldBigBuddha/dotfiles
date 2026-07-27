# Local work log

## Suberu — multi-agent orchestration harness (2026-07-27)

Added `suberu/`: a harness for running many Claude Code workers in parallel
under Herdr from one orchestrator session. Design and usage live in
`suberu/README.md`; this entry records why it is shaped the way it is.

### Why two plugins

Claude Code plugins cannot ship `permissions` — the manifest has no field for
it. That blocked packaging the guardrails as one unit. Herdr 0.7.5 turned out
to have its own plugin system, which resolves it: the Herdr layer writes
`.claude/settings.local.json` into each new worktree on `worktree.created`, and
Claude Code's permission machinery enforces it from there. Distribution and
enforcement deliberately live in different systems.

### Why workspaces, not tabs

Herdr's docs assign `task` to the workspace level, and `herdr worktree` is
literally "Manage Git worktree-backed workspaces". The decisive detail is that
`agent_status` rolls up per workspace: with three tasks as tabs inside one
workspace, `workspace list` returned a single collapsed `working` and the
orchestrator could not see which task needed attention. One task = one worktree
= one workspace.

### Context pollution

The harness's actual motivation. Four routes in, each closed rather than
mitigated: reading worker source (denied by hook), reading raw scrollback
(denied; workers report through `.suberu/report.md`), polling (replaced by the
`pane.agent_status_changed` event, which costs zero tokens), and losing state
then rebuilding it from logs (`SessionStart`/`PostCompact` re-inject fleet
state from Herdr).

A per-workspace standing "primary contractor" subagent was considered and
rejected: it would replace a zero-token event with model calls, make a second
agent reconstruct from logs what the worker already knows, and die with the
orchestrator session — which conflicts with restarting the orchestrator as the
recovery path. One-off investigations still go to throwaway subagents; the axis
is routine versus one-off, not permanent versus temporary.

### Facts measured against Herdr 0.7.5

Undocumented behaviour, established with a probe plugin rather than assumed:

- Plugin commands run with the plugin root as cwd, so relative `command` paths
  work.
- Actions receive **no argv**; only `HERDR_PLUGIN_CONTEXT_JSON`. This is why
  `task-start.sh` is a plain CLI script — an action could not carry a goal.
- `worktree.created` exposes the checkout at
  `HERDR_PLUGIN_EVENT_JSON.data.worktree.path`.
- `pane.agent_status_changed` carries no previous status, so transitions are
  tracked on disk.
- `worktree create` must run against the workspace holding the bare repo; it
  refuses from a linked worktree's workspace.
- Workspace metadata is display-only with a TTL, so durable state is kept in
  `HERDR_PLUGIN_STATE_DIR` and metadata is only a mirror.
- A pane returned by `worktree create` is not yet an interactive shell;
  `agent start` needs a retry loop, and its own `--timeout` does not cover it.

### Verification performed

Unit suite green (20 assertions) plus shellcheck clean, and a full live run: a
throwaway task was started, its worktree seeded, its agent briefed, its report
written in the required format, its completion notified through the event
handler, and its teardown refused while the worktree was dirty and completed
with `--force`.
