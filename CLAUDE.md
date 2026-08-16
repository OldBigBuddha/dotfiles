# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository managed with **GNU Stow**, a symlink farm manager. The architecture uses a package-based approach where each application's configuration is isolated in its own directory, then symlinked to the home directory.

## Key Architecture Concepts

### GNU Stow Package Structure

Each package directory mirrors the target filesystem structure from `$HOME`. Plain package names contain common configuration; `xxx-macos` and `xxx-linux` contain only operating-system-specific overlays. A few macOS-only applications retain plain historical package names.

```
package-name/
└── .config/
    └── app/
        └── config-file
```

When you run `stow package-name`, files are symlinked: `~/dotfiles/package-name/.config/app/config-file` → `~/.config/app/config-file`

### Package List

**macOS Only:**
- **aerospace**: Tiling window manager configuration
- **sketchybar**: macOS status bar customization
- **wezterm**: Terminal emulator configuration

**Cross-platform (common):**
- **gh**: GitHub CLI configuration (config.yml only, NOT hosts.yml)
- **git**: Git configuration (.gitconfig, .config/git/ignore)
- **mise**: mise global tool versions (`~/.config/mise/config.toml`)
- **nvim**: Neovim editor configuration (AstroNvim setup)
- **starship**: Starship prompt configuration
- **yazi**: Yazi file manager configuration
- **zsh**: Shared shell settings (history, keybindings, aliases, tool init)

**OS-specific overlays:**
- **claude-macos**: Claude Code settings and custom commands
- **git-macos**: macOS-specific git settings (Secure Enclave SSH signing)
- **git-linux**: optional Linux-specific git settings (1Password SSH signing)
- **zsh-macos**: Shell configuration (.zshrc, .zshenv, .zprofile) - sources zsh
- **zsh-linux**: Minimal Linux startup files - sources zsh
- **bin-macos**: macOS Secure Enclave signing helpers

> **Adding OS-specific config**: When a common package needs OS-specific settings, create `xxx-macos` (or `xxx-linux`) with only the OS-specific parts. Use include/source to load them. See git/git-macos as reference.

## Common Commands

### Setup and Installation

```bash
# Install all Homebrew packages (taps, brews, casks)
brew bundle --file=Brewfile

# Automated setup (installs stow and Linux zsh if needed, then applies packages)
./setup.sh

# mise (language runtimes and portable userland tools). Brew is blocked from
# installing language runtimes via HOMEBREW_FORBIDDEN_FORMULAE.
curl https://mise.run | sh
~/.local/bin/mise install

# Claude Code
curl -fsSL https://claude.ai/install.sh | bash
```

### Package Management

```bash
# Install a package (create symlinks)
stow <package-name>

# Install all packages (macOS)
stow aerospace sketchybar wezterm
stow gh git mise nvim starship yazi zsh
stow claude-macos git-macos zsh-macos

# Uninstall a package (remove symlinks)
stow -D <package-name>

# Reinstall a package (remove then recreate symlinks)
stow -R <package-name>

# Verbose mode (see what stow is doing)
stow -v <package-name>
```

### Development Workflow

When adding or modifying dotfiles:

1. Create/edit files in `~/dotfiles/<package-name>/` matching home directory structure
2. Run `stow -R <package-name>` to update symlinks
3. Test the configuration
4. Commit changes following conventional commit format: `feat(package): description`

### Linux E2E

```bash
docker run --rm \
  --volume "$PWD:/dotfiles:ro" \
  ubuntu:24.04 \
  bash /dotfiles/tests/e2e-ubuntu.sh
```

## Critical Constraints

### Security Exclusions

**NEVER** commit these files (they contain secrets):
- `gh/.config/gh/hosts.yml` - GitHub authentication tokens
- Any Claude Code dynamic data (history.jsonl, debug/, session-env/, todos/)

GitHub CLI authentication state is explicitly ignored by `.gitignore`. Claude dynamic files are excluded by keeping only selected static files in the Stow package.

### Stow Conflicts

If stow reports conflicts, existing files must be removed or backed up before stowing. The setup script does NOT handle conflicts automatically.

## Package-Specific Notes

### claude-macos Package

Contains global Claude Code configuration that applies to ALL projects:
- `CLAUDE.md` - Global workflow and coding standards
- `settings.json` - Claude Code settings
- `claude_desktop_config.json` - Claude Desktop configuration
- `commands/` - Custom slash commands

This dotfiles repository should have its own CLAUDE.md (this file) for repository-specific guidance.

### Git packages

- `git`: Core `.gitconfig`, `.config/git/ignore` and `.config/git/allowed_signers`
- `git-macos`: `.config/git/local.inc` — signs with a Secure Enclave key via `~/.local/bin/ssh-sign`
- `git-linux`: optional `.config/git/local.inc` — signs with the 1Password-managed key via `op-ssh-sign`

The `.gitconfig` includes `~/.config/git/local.inc` when an OS-specific signing package provides it. Signing keys, programs, and the enablement flags stay out of the shared config so a fresh Ubuntu installation can use Git before an optional signing provider is installed.

Run `setup-git-signing-key` once per Mac to create the Secure Enclave key, then register its public key on GitHub as a **Signing key** and append it to `git/.config/git/allowed_signers`.

### nvim Package

Uses AstroNvim. Configuration includes `init.lua` and Lua modules. Lock file (`lazy-lock.json`) is version-controlled for reproducible plugin versions.
