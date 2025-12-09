# Dotfiles

Personal dotfiles managed with GNU Stow.

## Packages

- **zsh**: Shell configuration (.zshrc, .zshenv, .zprofile)
- **git**: Git configuration (.gitconfig, .config/git/ignore)

## Setup

### Prerequisites

```bash
brew install stow
```

### Installation

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
stow zsh
stow git
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
└── git/
    ├── .gitconfig
    └── .config/
        └── git/
            └── ignore
```

## Backup

Backups are stored in `~/dotfiles_backup/` before initial migration.
