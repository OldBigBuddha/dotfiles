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

# mise is installed in ~/.local/bin on both supported operating systems.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
elif [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh)"
fi

# Tool initialization (cross-platform)
command -v fzf >/dev/null 2>&1 && eval "$(fzf --zsh)"
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v mcfly >/dev/null 2>&1 && eval "$(mcfly init zsh)"
