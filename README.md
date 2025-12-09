# Dotfiles

Personal dotfiles managed with GNU Stow.

## Packages

- **zsh**: Shell configuration (.zshrc, .zshenv, .zprofile)
- **git**: Git configuration (.gitconfig, .config/git/ignore)
- **nvim**: Neovim editor configuration (AstroNvim setup)
- **starship**: Starship prompt configuration
- **gh**: GitHub CLI configuration (config.yml only)
- **claude**: Claude Code settings and custom commands

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
stow zsh git nvim starship gh claude

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

## Structure

```
~/dotfiles/
├── zsh/
│   ├── .zshrc
│   ├── .zshenv
│   └── .zprofile
├── git/
│   ├── .gitconfig
│   └── .config/git/ignore
├── nvim/
│   └── .config/nvim/
│       ├── init.lua
│       ├── lazy-lock.json
│       └── lua/
├── starship/
│   └── .config/starship.toml
├── gh/
│   └── .config/gh/config.yml
└── claude/
    └── .claude/
        ├── CLAUDE.md
        ├── settings.json
        ├── claude_desktop_config.json
        └── commands/
```

## Notes

### Excluded Files

The following files are intentionally excluded from version control:

- **gh**: `~/.config/gh/hosts.yml` - Contains GitHub authentication tokens
- **claude**: Dynamic data files (history.jsonl, debug/, session-env/, todos/, etc.)

These files remain in their original locations and are not managed by Stow.

### Backup

Backups are stored in `~/dotfiles_backup/` before initial migration.
