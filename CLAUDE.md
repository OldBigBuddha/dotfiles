# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository managed with **GNU Stow**, a symlink farm manager. The architecture uses a package-based approach where each application's configuration is isolated in its own directory, then symlinked to the home directory.

## Key Architecture Concepts

### GNU Stow Package Structure

Each package directory mirrors the target filesystem structure from `$HOME`. Packages follow a naming convention: `xxx-macos` for cross-platform configs (with future `xxx-linux` or `xxx-common` variants), and plain names for macOS-only tools:

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
- **nvim**: Neovim editor configuration (AstroNvim setup)
- **starship**: Starship prompt configuration
- **zsh**: Shared shell settings (history, keybindings, aliases, tool init)

**Cross-platform (macOS):**
- **claude-macos**: Claude Code settings and custom commands
- **git-macos**: macOS-specific git settings (1Password SSH signing)
- **zsh-macos**: Shell configuration (.zshrc, .zshenv, .zprofile) - sources zsh

> **Adding OS-specific config**: When a common package needs OS-specific settings, create `xxx-macos` (or `xxx-linux`) with only the OS-specific parts. Use include/source to load them. See git/git-macos as reference.

## Common Commands

### Setup and Installation

```bash
# Automated setup (installs stow if needed, then all packages)
./setup.sh

# Manual stow installation
brew install stow
```

### Package Management

```bash
# Install a package (create symlinks)
stow <package-name>

# Install all packages (macOS)
stow aerospace sketchybar wezterm
stow gh git nvim starship zsh
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

## Critical Constraints

### Security Exclusions

**NEVER** commit these files (they contain secrets):
- `gh/hosts.yml` - GitHub authentication tokens
- Any Claude Code dynamic data (history.jsonl, debug/, session-env/, todos/)

These files are excluded via package structure, not .gitignore, and remain in their original locations.

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

### git + git-macos Packages

- `git`: Core `.gitconfig` and `.config/git/ignore`
- `git-macos`: macOS-specific settings in `.config/git/local.inc` (1Password SSH signing)

The `.gitconfig` includes `~/.config/git/local.inc` which is provided by the OS-specific package.

### nvim Package

Uses AstroNvim. Configuration includes `init.lua` and Lua modules. Lock file (`lazy-lock.json`) is version-controlled for reproducible plugin versions.
