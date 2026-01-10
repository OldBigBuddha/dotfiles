#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Setting up dotfiles with GNU Stow..."

# Check if GNU Stow is installed
if ! command -v stow &> /dev/null; then
    echo "📦 GNU Stow not found. Installing..."
    if command -v brew &> /dev/null; then
        brew install stow
    else
        echo "❌ Homebrew not found. Please install GNU Stow manually."
        exit 1
    fi
fi

# Navigate to dotfiles directory
cd "$(dirname "$0")"

# Detect OS
OS="$(uname)"

# macOS-only packages
MACOS_ONLY=(aerospace sketchybar wezterm)

# Common packages (no OS suffix)
COMMON=(gh git nvim starship zsh)

# Cross-platform packages (with OS suffix)
CROSS_PLATFORM=(claude git zsh)

# Install common packages first
for package in "${COMMON[@]}"; do
    if [[ -d "$package" ]]; then
        echo "📝 Stowing $package..."
        stow -v "$package"
    fi
done

# Install macOS-only packages
if [[ "$OS" == "Darwin" ]]; then
    for package in "${MACOS_ONLY[@]}"; do
        if [[ -d "$package" ]]; then
            echo "📝 Stowing $package..."
            stow -v "$package"
        fi
    done
fi

# Install cross-platform packages with OS suffix
case "$OS" in
    Darwin) suffix="macos" ;;
    Linux)  suffix="linux" ;;
    *)      echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

for package in "${CROSS_PLATFORM[@]}"; do
    pkg_name="${package}-${suffix}"
    if [[ -d "$pkg_name" ]]; then
        echo "📝 Stowing $pkg_name..."
        stow -v "$pkg_name"
    fi
done

echo ""
echo "✅ Dotfiles setup complete!"
echo ""
echo "Next steps:"
echo "  1. Restart your shell: exec zsh"
echo "  2. Verify configurations are working"
echo ""
