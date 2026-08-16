# Dotfiles

Personal macOS and Ubuntu dotfiles managed with GNU Stow. This repository
configures the user environment; it does not provision a complete workstation.

## Packages

Common packages applied on both operating systems:

- `gh`: GitHub CLI configuration (never authentication state)
- `git`: Git identity, editor, ignores, and other portable defaults
- `mise`: language runtimes and portable userland tools
- `nvim`: AstroNvim-based Neovim configuration
- `starship`: prompt configuration
- `yazi`: file manager configuration
- `zsh`: shared history, aliases, and tool initialization

macOS-only packages and overlays:

- `aerospace`, `sketchybar`, `wezterm`
- `claude-macos`: Claude Code settings, hooks, and skills
- `git-macos`: Secure Enclave SSH commit signing
- `zsh-macos`: Homebrew, 1Password agent, OrbStack, and macOS paths
- `bin-macos`: Secure Enclave Git-signing helpers

Linux-specific packages:

- `zsh-linux`: minimal zsh startup files that load the shared configuration
- `git-linux`: optional 1Password SSH signing configuration; not applied by
  `setup.sh` because 1Password is an external prerequisite

## macOS setup

Install Homebrew first, then:

```bash
git clone https://github.com/OldBigBuddha/dotfiles.git ~/dotfiles
cd ~/dotfiles

brew bundle --file=Brewfile
./setup.sh

curl https://mise.run | sh
~/.local/bin/mise install
exec zsh
```

Create the per-machine Secure Enclave signing key after the new shell starts:

```bash
setup-git-signing-key
```

Register the printed public key on GitHub as a signing key and add the public
key to `git/.config/git/allowed_signers`, as instructed by the script.

## Ubuntu 24.04 setup

```bash
sudo apt update
sudo apt install -y git curl stow zsh

git clone https://github.com/OldBigBuddha/dotfiles.git ~/dotfiles
cd ~/dotfiles

./setup.sh

curl https://mise.run | sh
~/.local/bin/mise install

chsh -s "$(command -v zsh)"
exec zsh
```

After installation, authenticate tools locally as needed. For example,
`gh auth login` creates `~/.config/gh/hosts.yml`; that file is deliberately
ignored and is not managed by this repository.

### Optional Linux commit signing

The normal Ubuntu setup leaves Git commit signing disabled, so Git works before
any credential application is installed. To reuse the existing 1Password SSH
signing setup, install and configure 1Password for Linux, verify that
`/opt/1Password/op-ssh-sign` exists, then apply the optional overlay:

```bash
cd ~/dotfiles
stow -v --no-folding --target="$HOME" git-linux
```

The public signing key in `git-linux` is machine/account specific. Update it
only with a public key; never add a private key or authentication token.

## Tool ownership

`setup.sh` detects macOS versus Linux, rejects unsupported Linux distributions,
installs GNU Stow when it is missing (Homebrew on macOS, APT on Ubuntu/Debian),
and installs missing `git`, `curl`, `stow`, and `zsh` bootstrap prerequisites
through APT on Linux. It also requires zsh 5.9 or newer and verifies that an
APT-managed zsh is not older than the candidate in the currently configured
package indexes. It then applies the appropriate packages and copies small
helper scripts to `~/.local/bin`. It does not install a general software catalog.

Ubuntu 24.04's supported package is zsh 5.9. Upstream may publish newer patch
releases during the LTS lifetime; this repository intentionally follows the
Ubuntu package rather than compiling a login shell from source. Run `sudo apt
update` before `setup.sh` when you need the candidate-version check to reflect
the newest repository metadata.

`mise install` installs the portable tools declared in
`mise/.config/mise/config.toml`, including Node.js, Python, Go, Rust, Neovim,
GitHub CLI, ripgrep, fd, fzf, jq, bat, lsd, starship, yazi, and zoxide.

The macOS `Brewfile` is limited to bootstrap/system integration and macOS-only
applications. `mcfly`, `zsh-autosuggestions`, and `python-yq` remain Homebrew
packages because they are currently macOS-specific parts of this environment.

## Manual Stow usage

```bash
# Common packages
stow --no-folding --target="$HOME" gh git mise nvim starship yazi zsh

# macOS overlays
stow --no-folding --target="$HOME" claude-macos git-macos zsh-macos

# Linux shell overlay
stow --no-folding --target="$HOME" zsh-linux

# Remove or reapply one package
stow -D --target="$HOME" <package-name>
stow -R --no-folding --target="$HOME" <package-name>
```

Stow reports conflicts instead of overwriting existing files. Back up or merge
those files deliberately before rerunning setup.

## Scope and secrets

This repository owns shell, editor, Git, CLI, and userland runtime/tool
configuration. Hyper-V VM creation, Ubuntu desktop policy, kernel/eBPF tooling,
reversing tools, security-research workloads, and other machine roles belong in
separate provisioning layers.

Never commit generated credentials or authentication state, including:

- `gh/.config/gh/hosts.yml`
- SSH private keys
- Claude authentication/session data
- AWS, Cloudflare, Shodan, or other API credentials

The Claude package contains selected static macOS settings only. Dynamic Claude
directories such as history, debug data, session environments, and todos remain
outside the package and must stay untracked.

## Validation

The Linux E2E runs the repository twice in a clean Ubuntu 24.04 container. It
checks APT bootstrap, real Stow links, zsh startup, Git defaults, OS-specific
package isolation, and credential-file exclusions.

```bash
docker run --rm \
  --volume "$PWD:/dotfiles:ro" \
  ubuntu:24.04 \
  bash /dotfiles/tests/e2e-ubuntu.sh
```
