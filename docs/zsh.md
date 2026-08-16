# Zsh configuration policy

This document defines how this repository manages Zsh startup files on macOS
and Linux. It is a maintenance contract: new shell configuration should follow
these boundaries unless the policy is deliberately revised at the same time.

## Goals

The configuration must provide:

- predictable command resolution in interactive terminals;
- a minimal, silent environment for non-interactive Zsh processes;
- equivalent access to mise-managed CLI tools for local AI agents;
- explicit separation between portable settings and OS integration;
- repeatable startup without network access; and
- recovery behavior that still works when optional tools or plugins are absent.

Interactive and login are independent shell properties. Do not use “login
shell” as a synonym for “shell used by a person.” An AI agent command is
expected to run in a non-interactive, non-login shell unless its runner states
otherwise.

## Startup file boundaries

Zsh reads user startup files in the following order when the corresponding
conditions apply:

| File | Condition | Repository policy |
| --- | --- | --- |
| `.zshenv` | Every Zsh process, unless user startup files are disabled | Export essential environment variables and establish a minimal command path. It must be fast, silent, offline, and independent of a TTY. |
| `.zprofile` | Login shells | Perform session-level OS integration that must happen before interactive configuration. Do not put interactive features here. |
| `.zshrc` | Interactive shells | Configure history, completion, aliases, key bindings, plugins, prompts, and interactive tool activation. |
| `.zlogin` | Login shells, after `.zshrc` when interactive | Reserved for commands that specifically must run at the end of login initialization. This repository currently does not need one. |
| `.zlogout` | Exiting login shells | Reserved for login-session cleanup. This repository currently does not need one. |

`zsh -f` disables user startup files. Scripts requiring repository-managed
tools must not assume that `.zshenv` is available under that mode.

### `.zshenv`

`.zshenv` affects scripts as well as terminal sessions, so additions require a
higher bar than additions to `.zshrc`.

It may:

- export stable environment variables needed by child processes;
- use Zsh parameter expansion and builtins;
- update the tied `path` and `PATH` values with `typeset -U`; and
- add mise shims when `[[ ! -o interactive ]]`.

It must not:

- print output;
- assume stdin, stdout, or stderr is attached to a TTY;
- initialize completion, prompts, history, aliases, or the line editor;
- fetch from the network;
- run package installation or updates; or
- source `.zshrc` as a shortcut.

The mise shim directory must precede `~/.local/bin` in non-interactive Zsh.
This ensures that a mise-managed command wins over an older standalone binary.
Interactive shells do not add shims here; they receive direct tool paths from
`mise activate zsh` in `.zshrc`.

### `.zprofile`

`.zprofile` is for login-session initialization, not for making tools
available to non-interactive command runners. A normal `zsh -c` does not read
it.

The macOS overlay uses `.zprofile` for Homebrew environment integration and
OrbStack initialization. Linux currently requires no user `.zprofile`.

### `.zshrc`

`.zshrc` owns behavior intended for a person at a terminal. OS-specific files
load portable configuration rather than duplicating it.

The portable interactive configuration owns:

- history behavior;
- completion initialization;
- pinned Zsh plugins;
- mise prompt-hook activation;
- prompt and directory-navigation integrations; and
- shared aliases and functions.

Plugin checkout or update operations never belong in startup. `setup.sh`
installs plugins at commits declared in `plugins.toml`; startup only sources an
already-installed, readable checkout.

## Repository layout

Portable configuration lives in the `zsh` Stow package:

```text
zsh/.config/zsh/
├── aliases.zsh
├── common.zsh
└── plugins.toml
```

Operating-system entrypoints and overlays remain separate:

```text
zsh-linux/
├── .zshenv
└── .zshrc

zsh-macos/
├── .zprofile
├── .zshenv
├── .zshrc
└── .config/zsh/
    ├── aliases-macos.zsh
    └── path-macos.zsh
```

Common behavior must go in `zsh/.config/zsh`. An OS overlay should contain
only the integration or path entries that cannot be shared.

On macOS, `.zshenv` disables `GLOBAL_RCS` and invokes `path_helper` explicitly.
This prevents later global Zsh startup files from changing the repository's
environment unexpectedly. Required macOS system integration must therefore be
explicit in the macOS overlay.

## Command-path ownership

Command paths have distinct owners:

- `~/.local/bin` contains the mise bootstrap executable and small scripts
  copied by this repository.
- `${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims` exposes mise-managed tools
  to non-interactive Zsh.
- `mise activate zsh` supplies direct tool installation paths and environment
  hooks to interactive Zsh.
- Homebrew owns bootstrap, system-integration, and macOS-only commands; it does
  not own portable language runtimes.
- OS package managers own the login shell and bootstrap commands such as Git,
  curl, and GNU Stow.

Do not solve a missing command by adding the same tool through another package
manager. Fix the appropriate path boundary or installation step instead.

## AI agent execution contract

Local AI agents may execute each command in a fresh non-interactive,
non-login shell. Their parent process may have been launched from a terminal,
a GUI, an IDE, or a service, so an inherited interactive `PATH` is not a valid
dependency.

After `setup.sh` installs a mise-managed tool, a clean non-interactive Zsh must
resolve that tool through the mise shim directory without loading interactive
functions. Aliases, shell functions, completion definitions, prompt state, and
ZLE configuration are not part of the agent command contract.

This contract covers command runners that actually invoke Zsh. A runner using
`sh`, Bash, direct process execution, a remote container, or a cloud agent does
not read Zsh startup files. Those environments must use one of these explicit
interfaces:

- inherit a known `PATH` when the agent process starts;
- run a project or agent environment setup script;
- invoke a command with `mise exec -- ...`; or
- invoke a repository task that owns its runtime environment.

Repository automation should prefer explicit task entrypoints over depending
on aliases or interactive shell initialization.

## Change rules

When changing Zsh configuration:

1. Put the setting in the narrowest startup file that satisfies its consumers.
2. Keep `.zshenv` silent, offline, and limited to environment construction.
3. Keep interactive behavior in `.zshrc` even when it is harmless elsewhere.
4. Add portable behavior once under `zsh/.config/zsh` and source it from OS
   entrypoints.
5. Keep plugins pinned and install them only through the setup workflow.
6. Preserve startup when optional integrations are missing.
7. Add an acceptance check whenever command availability or startup-file
   routing changes.

Do not add `.profile` as an alternative Zsh startup path. Zsh does not normally
read it when invoked as Zsh, and maintaining two environment authorities would
make agent behavior dependent on how the parent process was launched.

## Validation

At minimum, configuration changes must pass syntax and repository checks:

```bash
sh -n setup.sh tests/e2e-ubuntu.sh
zsh -n zsh-linux/.zshenv zsh-macos/.zshenv zsh/.config/zsh/common.zsh
git diff --check
mise exec -- pnpm secretlint
```

The clean non-interactive contract must be tested without an inherited user
path:

```bash
env -i \
  HOME="$HOME" \
  PATH=/usr/bin:/bin \
  TERM=dumb \
  zsh -c 'command -v herdr && herdr --version'
```

Linux changes must also pass the disposable Ubuntu 24.04 E2E, which applies the
repository twice and verifies both non-interactive and interactive startup:

```bash
docker run --rm \
  --volume "$PWD:/dotfiles:ro" \
  ubuntu:24.04 \
  bash /dotfiles/tests/e2e-ubuntu.sh
```

## References

- [ArchWiki: Zsh startup and shutdown files](https://wiki.archlinux.org/title/Zsh#Startup/Shutdown_files)
- [A User's Guide to the Z-Shell: What to put in your startup files](https://zsh.sourceforge.io/Guide/zshguide02.html)
- [mise: Shims](https://mise.jdx.dev/dev-tools/shims.html)
