#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Setting up dotfiles with GNU Stow..."

# Navigate to dotfiles directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Detect OS
OS="$(uname)"

case "$OS" in
    Darwin)
        suffix="macos"
        ;;
    Linux)
        if [[ ! -r /etc/os-release ]]; then
            echo "❌ Cannot identify this Linux distribution (/etc/os-release is missing)." >&2
            exit 1
        fi

        # shellcheck disable=SC1091
        source /etc/os-release
        distro_id="${ID:-unknown}"
        distro_like="${ID_LIKE:-}"
        case " $distro_id $distro_like " in
            *" ubuntu "*|*" debian "*) ;;
            *)
                echo "❌ Unsupported Linux distribution: ${PRETTY_NAME:-$distro_id}." >&2
                echo "   setup.sh currently supports Ubuntu/Debian (apt) only." >&2
                exit 1
                ;;
        esac
        suffix="linux"
        ;;
    *)
        echo "❌ Unsupported OS: $OS" >&2
        exit 1
        ;;
esac

# Install only prerequisites needed to apply and load this repository.
# Runtimes and portable userland tools remain mise's responsibility.
case "$OS" in
    Darwin)
        if ! command -v stow >/dev/null 2>&1; then
            echo "📦 GNU Stow not found. Installing..."
            if ! command -v brew >/dev/null 2>&1; then
                echo "❌ Homebrew is required to install GNU Stow on macOS." >&2
                echo "   Install Homebrew from https://brew.sh, then rerun setup.sh." >&2
                exit 1
            fi
            brew install stow
        fi
        ;;
    Linux)
        apt_packages=()
        command -v git >/dev/null 2>&1 || apt_packages+=(git)
        command -v curl >/dev/null 2>&1 || apt_packages+=(curl)
        command -v stow >/dev/null 2>&1 || apt_packages+=(stow)
        command -v zsh >/dev/null 2>&1 || apt_packages+=(zsh)

        if (( ${#apt_packages[@]} > 0 )); then
            echo "📦 Installing bootstrap prerequisites: ${apt_packages[*]}"
            if ! command -v apt-get >/dev/null 2>&1; then
                echo "❌ apt-get is unavailable on this Ubuntu/Debian system." >&2
                exit 1
            fi

            apt_prefix=()
            if (( EUID != 0 )); then
                if ! command -v sudo >/dev/null 2>&1; then
                    echo "❌ Installing GNU Stow requires root privileges or sudo." >&2
                    exit 1
                fi
                apt_prefix=(sudo)
            fi
            "${apt_prefix[@]}" apt-get update
            "${apt_prefix[@]}" apt-get install -y "${apt_packages[@]}"
        fi

        zsh_version="$(zsh -fc 'print -r -- $ZSH_VERSION')"
        installed_zsh_package="$(dpkg-query -W -f='${Version}' zsh 2>/dev/null || true)"
        candidate_zsh_package="$(apt-cache policy zsh | awk '/Candidate:/ { print $2; exit }')"
        if [[ -n "$installed_zsh_package" && -n "$candidate_zsh_package" && "$candidate_zsh_package" != "(none)" ]] && \
           dpkg --compare-versions "$installed_zsh_package" lt "$candidate_zsh_package"; then
            echo "❌ Installed zsh package $installed_zsh_package is older than APT candidate $candidate_zsh_package." >&2
            echo "   Run: sudo apt update && sudo apt install --only-upgrade zsh" >&2
            exit 1
        fi
        echo "✅ zsh $zsh_version is installed (APT package: ${installed_zsh_package:-non-APT})."
        ;;
esac

# Zsh plugins are plain Git checkouts pinned to reviewed commits. They live in
# the user data directory rather than being supplied by an OS package manager.
install_zsh_plugin() {
    local name="$1"
    local repository="$2"
    local commit="$3"
    local plugin_root="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
    local plugin_dir="$plugin_root/$name"
    local current_origin

    mkdir -p "$plugin_root"

    if [[ -e "$plugin_dir" && ! -d "$plugin_dir/.git" ]]; then
        echo "❌ Cannot manage $plugin_dir because it is not a Git checkout." >&2
        exit 1
    fi

    if [[ ! -d "$plugin_dir/.git" ]]; then
        echo "📦 Installing zsh plugin: $name"
        git clone --quiet "$repository" "$plugin_dir"
    fi

    current_origin="$(git -C "$plugin_dir" remote get-url origin 2>/dev/null || true)"
    if [[ "$current_origin" != "$repository" ]]; then
        echo "❌ Unexpected origin for $plugin_dir: ${current_origin:-missing}" >&2
        echo "   Expected: $repository" >&2
        exit 1
    fi

    if [[ -n "$(git -C "$plugin_dir" status --porcelain)" ]]; then
        echo "❌ Refusing to update modified zsh plugin checkout: $plugin_dir" >&2
        exit 1
    fi

    if ! git -C "$plugin_dir" cat-file -e "${commit}^{commit}" 2>/dev/null; then
        git -C "$plugin_dir" fetch --quiet --depth 1 origin "$commit"
    fi
    git -C "$plugin_dir" checkout --quiet --detach "$commit"
}

if ! command -v git >/dev/null 2>&1; then
    echo "❌ Git is required to install zsh plugins." >&2
    exit 1
fi

# zsh-autosuggestions v0.7.1
install_zsh_plugin \
    zsh-autosuggestions \
    https://github.com/zsh-users/zsh-autosuggestions.git \
    e52ee8ca55bcc56a17c828767a3f98f22a68d4eb

# Herdr is a portable userland tool, so install it through mise on both
# supported operating systems instead of adding it to APT or Homebrew.
mise_bin="$(command -v mise 2>/dev/null || true)"
if [[ -z "$mise_bin" && -x "$HOME/.local/bin/mise" ]]; then
    mise_bin="$HOME/.local/bin/mise"
fi
if [[ -z "$mise_bin" ]]; then
    echo "📦 mise not found. Installing..."
    curl --proto '=https' --tlsv1.2 -sSf https://mise.run | sh
    mise_bin="$HOME/.local/bin/mise"
fi
if [[ ! -x "$mise_bin" ]]; then
    echo "❌ mise installation did not create an executable at $mise_bin." >&2
    exit 1
fi

# macOS-only packages
MACOS_ONLY=(aerospace sketchybar wezterm)

# Common packages (no OS suffix)
COMMON=(gh git mise nvim starship yazi zsh)

# OS-specific overlays. Linux Git signing is opt-in because it requires the
# separately installed 1Password desktop application.
if [[ "$OS" == "Darwin" ]]; then
    OS_SPECIFIC=(claude git zsh)
else
    OS_SPECIFIC=(zsh)
fi

# Install common packages first.
# --no-folding keeps target directories real instead of symlinking a whole
# package subtree. Without it, `stow git` turns ~/.config/git into a symlink to
# the git package, and the later `stow git-macos` writes local.inc *inside* the
# git package rather than into ~/.config/git.
for package in "${COMMON[@]}"; do
    if [[ -d "$package" ]]; then
        echo "📝 Stowing $package..."
        stow -v --no-folding --target="$HOME" "$package"
    fi
done

# Install macOS-only packages
if [[ "$OS" == "Darwin" ]]; then
    for package in "${MACOS_ONLY[@]}"; do
        if [[ -d "$package" ]]; then
            echo "📝 Stowing $package..."
            stow -v --target="$HOME" "$package"
        fi
    done
fi

# Install cross-platform packages with OS suffix
for package in "${OS_SPECIFIC[@]}"; do
    pkg_name="${package}-${suffix}"
    if [[ -d "$pkg_name" ]]; then
        echo "📝 Stowing $pkg_name..."
        stow -v --no-folding --target="$HOME" "$pkg_name"
    fi
done

# Install standalone scripts into ~/.local/bin (copied, not symlinked).
# Stow is intentionally avoided here: $HOME/.local/bin commonly holds
# binaries from other installers (mise, claude, etc.), and a symlink farm
# would conflict with them.
script_dirs=(bin)
[[ -d "bin-${suffix}" ]] && script_dirs+=("bin-${suffix}")
if [[ -d "bin" ]]; then
    echo "📝 Installing scripts to ~/.local/bin..."
    mkdir -p "$HOME/.local/bin"
    for script_dir in "${script_dirs[@]}"; do
        for script in "$script_dir"/*; do
            [[ -f "$script" ]] || continue
            install -m 0755 "$script" "$HOME/.local/bin/$(basename "$script")"
        done
    done
fi

echo "📦 Installing Herdr through mise..."
"$mise_bin" install herdr
"$mise_bin" exec herdr -- herdr --version

echo ""
echo "✅ Dotfiles setup complete!"
echo ""
echo "Next steps:"
echo "  1. Install the remaining userland tools: $mise_bin install"
echo "  2. Install repository development dependencies: $mise_bin exec -- pnpm install --frozen-lockfile"
echo "  3. Restart your shell: exec zsh"
echo ""
