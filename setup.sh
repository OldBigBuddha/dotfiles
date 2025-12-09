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

# List of packages to install
PACKAGES=(zsh git nvim starship gh claude)

# Install each package
for package in "${PACKAGES[@]}"; do
    echo "📝 Stowing $package..."
    stow -v "$package"
done

echo ""
echo "✅ Dotfiles setup complete!"
echo ""
echo "Next steps:"
echo "  1. Restart your shell: exec zsh"
echo "  2. Verify configurations are working"
echo ""
