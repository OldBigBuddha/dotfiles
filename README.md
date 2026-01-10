# Dotfiles

Personal dotfiles managed with GNU Stow.

## Packages

- **aerospace**: Tiling window manager configuration
- **claude**: Claude Code settings and custom commands
- **gh**: GitHub CLI configuration (config.yml only)
- **git**: Git configuration (.gitconfig, .config/git/ignore)
- **nvim**: Neovim editor configuration (AstroNvim setup)
- **sketchybar**: macOS status bar customization
- **starship**: Starship prompt configuration
- **wezterm**: Terminal emulator configuration
- **zsh**: Shell configuration (.zshrc, .zshenv, .zprofile)

## Setup

### Prerequisites

```bash
brew install stow
```

### Installation

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles

# Install all packages
stow aerospace claude gh git nvim sketchybar starship wezterm zsh

# Or install individually
stow zsh
stow git
stow nvim
stow starship
stow gh
stow claude
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
- **claude**: Dynamic data files (history.jsonl, debug/, session-env/, todos/, etc.)

These files remain in their original locations and are not managed by Stow.

