# Dotfiles

Personal dotfiles managed with GNU Stow.

## Packages

### macOS Only

- **aerospace**: Tiling window manager configuration
- **sketchybar**: macOS status bar customization
- **wezterm**: Terminal emulator configuration

### Cross-platform (common)

- **gh**: GitHub CLI configuration
- **git**: Git configuration (.gitconfig, .config/git/ignore)
- **nvim**: Neovim editor configuration (AstroNvim setup)
- **starship**: Starship prompt configuration
- **zsh**: Shared shell settings (history, aliases, tool init)

### Cross-platform (macOS)

- **claude-macos**: Claude Code settings and custom commands
- **git-macos**: macOS-specific git settings (1Password SSH signing)
- **zsh-macos**: Shell configuration (.zshrc, .zshenv, .zprofile) - sources zsh

> **Note**: When OS-specific configuration is needed for a common package, create a new `xxx-macos` (or `xxx-linux`) package with only the OS-specific settings, following the git/git-macos pattern.

## Setup

### Prerequisites

```bash
brew install stow
```

### Installation

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles

# Install all packages (macOS)
stow aerospace sketchybar wezterm
stow gh git nvim starship zsh
stow claude-macos git-macos zsh-macos

# Or install individually
stow zsh-macos
stow git-macos
```

## Usage

### Install a package

```bash
stow <package-name>
```

### Uninstall a package

```bash
stow -D <package-name>
```

### Reinstall a package

```bash
stow -R <package-name>
```

## Notes

### Excluded Files

The following files are intentionally excluded from version control:

- **gh**: `~/.config/gh/hosts.yml` - Contains GitHub authentication tokens
- **claude-macos**: Dynamic data files (history.jsonl, debug/, session-env/, todos/, etc.)

These files remain in their original locations and are not managed by Stow.

