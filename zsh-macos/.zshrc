# .zshrc - macOS

# Load PATH first (needed by tool initialization in common.zsh)
[ -f ~/.config/zsh/path-macos.zsh ] && source ~/.config/zsh/path-macos.zsh

# Load common configuration
[ -f ~/.config/zsh/common.zsh ] && source ~/.config/zsh/common.zsh
[ -f ~/.config/zsh/aliases.zsh ] && source ~/.config/zsh/aliases.zsh

# Load macOS-specific runtime
eval "$(~/.local/bin/mise activate zsh)"
