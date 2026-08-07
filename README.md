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
- **mise**: mise tool versions (`~/.config/mise/config.toml`)
- **nvim**: Neovim editor configuration (AstroNvim setup)
- **starship**: Starship prompt configuration
- **yazi**: Yazi file manager configuration
- **zsh**: Shared shell settings (history, aliases, tool init)

### Cross-platform (macOS)

- **claude-macos**: Claude Code settings and custom commands
- **git-macos**: macOS-specific git settings (Secure Enclave SSH signing)
- **git-linux**: Linux-specific git settings (1Password SSH signing)
- **zsh-macos**: Shell configuration (.zshrc, .zshenv, .zprofile) - sources zsh

> **Note**: When OS-specific configuration is needed for a common package, create a new `xxx-macos` (or `xxx-linux`) package with only the OS-specific settings, following the git/git-macos pattern.

## Setup

### Bootstrap (new machine)

```bash
# 1. Install Homebrew, then clone this repo
git clone <repo-url> ~/dotfiles
cd ~/dotfiles

# 2. Install Homebrew packages (taps, brews, casks)
brew bundle --file=Brewfile

# 3. Stow all packages
./setup.sh

# 4. Install mise (manages language runtimes — node/python/go/rust)
curl https://mise.run | sh
mise install   # picks up ~/.config/mise/config.toml from the `mise` package

# 5. Install Claude Code
curl -fsSL https://claude.ai/install.sh | bash

# 6. Create the commit signing key (macOS only, once per machine)
setup-git-signing-key
```

> Step 6 generates a key inside the Secure Enclave and prints its public key. Register it on GitHub as a **Signing key**, then append it to `git/.config/git/allowed_signers` — the script prints both reminders. Secure Enclave keys cannot leave the machine, so every Mac has its own key. On Linux, signing goes through 1Password (`git-linux`) and no extra step is needed.

> Language runtimes (node, python, go, rust, etc.) are intentionally not in `Brewfile`. They are pinned to mise via `HOMEBREW_FORBIDDEN_FORMULAE` in `zsh-macos/.zshenv`.

### Manual installation

```bash
# Install all packages (macOS)
stow aerospace sketchybar wezterm
stow gh git mise nvim starship yazi zsh
stow claude-macos git-macos zsh-macos

# Or install individually
stow zsh-macos
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

