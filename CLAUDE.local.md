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

### Repository layout independence (follow-up)

The first cut inferred the role from `<cwd>/.git/worktrees` being a directory.
That holds for this monorepo — which is `core.bare = true` yet still carries a
`.git/` directory — and fails for a textbook bare repository, where worktrees
live at `repo.git/worktrees` and no `.git` exists. Verified by building one:
the guards decided the session was not an orchestrator and **disabled every
rule silently**.

Replaced by asking git. Role comes from `git rev-parse --git-dir` versus
`--git-common-dir`; worker material comes from `git worktree list --porcelain`,
so worktrees are found wherever they live; placement comes from the parent of
the git common directory, which yields `<root>` for `<root>/.git` and `<base>`
for `<base>/repo.git` under one rule. Indeterminate cases now emit a
`systemMessage` instead of failing open.

Two related lessons: the hook entrypoints must resolve their own directory with
shell builtins only, because a stripped `PATH` cost them `dirname` and a guard
that cannot start looks exactly like a guard that is not installed. And the
accidental `git worktree add ../wt-a` made during this work is precisely what
the guard denies — the old component-counting check would have let it through.

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

Unit suite green plus shellcheck clean, and a full live run: a
throwaway task was started, its worktree seeded, its agent briefed, its report
written in the required format, its completion notified through the event
handler, and its teardown refused while the worktree was dirty and completed
with `--force`.

### Review findings and their fixes (2026-07-27, later)

A review of the branch found six defects, all reproduced against real
repositories before being fixed and all now covered by the suite (93
assertions, up from 67). Two were the same failure the previous commit set out
to end, arriving by new routes.

**A space in the repository path disabled every guard.** `suberu_git` read
`git rev-parse --git-dir --git-common-dir` with `.split()`, which splits on all
whitespace rather than on lines. From a subdirectory git answers `--git-dir`
absolutely and `--git-common-dir` relatively, so `/home/me/my repo/.git` tore
into fragments that paired the wrong halves; the two "paths" differed, the role
read as `worker`, and the context guard returned nothing for every call. The
control case without a space denied correctly, which is why nothing noticed.
`splitlines()` fixes it, and the fixture now builds a repository named
`my repo` — note it cannot use the `read -r` idiom the other fixtures use, for
precisely the reason the bug existed.

**`git worktree add -b <branch> <path>` skipped the placement check.** The
destination was taken as the first word not starting with `-`, but `-b`, `-B`
and `--reason` each consume the word after them, so the branch name was
measured instead. It resolved under the cwd, matched `home`, and passed — while
the real destination was never examined. Naming a branch is the common case and
`task-start.sh` always does it, so the guard was mostly inert in practice.

The remaining four: `--git-dir`/`--work-tree` did what `-C` is denied for and
were allowed, so they now share its rule and its message; a `cd` earlier in a
command line was ignored, so `cd <worktree> && cat src.py` read worker material
and `cd /tmp && git worktree add x` escaped placement, now tracked by
`suberu_git.apply_cd` in both guards; `merge_settings` discarded the permission
baseline in silence when a worktree held an incompatible type there
(`"permissions": null`, a `deny` written as a string) and now keeps the
worktree's value but says loudly what was not applied; and `SUBERU_ROLE` was
unvalidated, so a typo matched no role and stood every rule down — it is now an
`Undetermined`, as is a payload carrying no cwd.

The pattern across all six is worth keeping: each was a guard producing no
decision and no warning. Only the two that had a passing control case nearby
were invisible; the rest were simply never asked. Confirmed sound and left
alone: repositories with no commits, detached-HEAD worktrees, the bare layout,
and `git worktree list --porcelain` ordering, whose line-based parsing already
survived spaces. `merge_settings` was already correct about the thing it was
most suspected of — malformed JSON aborts and leaves the file byte-identical.
