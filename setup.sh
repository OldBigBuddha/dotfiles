#!/bin/sh
set -eu

# This file is the portable bootstrap boundary. It installs only the commands
# required by the Zsh setup and then replaces itself with that setup process.
cd "$(CDPATH= cd -P "$(dirname "$0")" && pwd)"

os="$(uname -s)"

case "$os" in
    Darwin)
        missing_packages=""
        for package in git stow zsh; do
            if ! command -v "$package" >/dev/null 2>&1; then
                missing_packages="$missing_packages $package"
            fi
        done

        if [ -n "$missing_packages" ]; then
            if ! command -v brew >/dev/null 2>&1; then
                echo "❌ Homebrew is required to install macOS bootstrap prerequisites:$missing_packages" >&2
                echo "   Install Homebrew from https://brew.sh, then rerun setup.sh." >&2
                exit 1
            fi
            echo "📦 Installing bootstrap prerequisites:$missing_packages"
            # Package names are selected from the fixed list above.
            # shellcheck disable=SC2086
            brew install $missing_packages
        fi
        ;;
    Linux)
        if [ ! -r /etc/os-release ]; then
            echo "❌ Cannot identify this Linux distribution (/etc/os-release is missing)." >&2
            exit 1
        fi

        # shellcheck disable=SC1091
        . /etc/os-release
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

        missing_packages=""
        for package in git curl stow zsh; do
            if ! command -v "$package" >/dev/null 2>&1; then
                missing_packages="$missing_packages $package"
            fi
        done

        if [ -n "$missing_packages" ]; then
            if ! command -v apt-get >/dev/null 2>&1; then
                echo "❌ apt-get is unavailable on this Ubuntu/Debian system." >&2
                exit 1
            fi

            if [ "$(id -u)" -eq 0 ]; then
                apt_get() {
                    apt-get "$@"
                }
            elif command -v sudo >/dev/null 2>&1; then
                apt_get() {
                    sudo apt-get "$@"
                }
            else
                echo "❌ Installing bootstrap prerequisites requires root privileges or sudo." >&2
                exit 1
            fi

            echo "📦 Installing bootstrap prerequisites:$missing_packages"
            apt_get update
            # Package and command names are selected from the fixed lists above.
            # shellcheck disable=SC2086
            apt_get install -y $missing_packages
        fi
        ;;
    *)
        echo "❌ Unsupported OS: $os" >&2
        exit 1
        ;;
esac

if ! command -v zsh >/dev/null 2>&1; then
    echo "❌ zsh is unavailable after bootstrap installation." >&2
    exit 1
fi

exec zsh scripts/setup.zsh
