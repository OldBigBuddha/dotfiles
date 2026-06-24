# .zshrc - macOS

# Load PATH first (needed by tool initialization in common.zsh)
[ -f ~/.config/zsh/path-macos.zsh ] && source ~/.config/zsh/path-macos.zsh

# Load common configuration
[ -f ~/.config/zsh/common.zsh ] && source ~/.config/zsh/common.zsh
[ -f ~/.config/zsh/aliases.zsh ] && source ~/.config/zsh/aliases.zsh
[ -f ~/.config/zsh/aliases-macos.zsh ] && source ~/.config/zsh/aliases-macos.zsh

# Load macOS-specific runtime
eval "$(~/.local/bin/mise activate zsh)"
eval "$(mcfly init zsh)"

# >>> microsandbox >>>
export PATH="$HOME/.microsandbox/bin:$PATH"
export DYLD_LIBRARY_PATH="$HOME/.microsandbox/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
# <<< microsandbox <<<
