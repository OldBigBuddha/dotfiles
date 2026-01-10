# common.zsh - Cross-platform zsh configuration

# keybinding
bindkey -v

# history
setopt share_history
setopt hist_ignore_all_dups
setopt hist_save_no_dups
export HISTFILE=~/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000

# mcfly
export MCFLY_FUZZY=true
export MCFLY_RESULTS=30
export MCFLY_HISTORY_LIMIT=10000

# colors
autoload -Uz colors && colors

# NVM
export NVM_DIR=$HOME/.nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Tool initialization (cross-platform)
command -v fzf >/dev/null 2>&1 && eval "$(fzf --zsh)"
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh --cmd cd)"
command -v mcfly >/dev/null 2>&1 && eval "$(mcfly init zsh)"

# safe-chain (if exists)
[ -f ~/.safe-chain/scripts/init-posix.sh ] && source ~/.safe-chain/scripts/init-posix.sh
