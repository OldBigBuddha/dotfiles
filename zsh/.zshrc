# history
setopt share_history
setopt hist_ignore_all_dups
setopt hist_save_no_dups
export HISTFILE=~/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000
export MCFLY_FUZZY=true
export MCFLY_RESULTS=30
export MCFLY_HISTORY_LIMIT=10000

autoload -Uz colors && colors
export PNPM_HOME="/Users/pc0041/Library/pnpm"
typeset -U path PATH
path=(
  $HOME/.local/bin(N-/)
  $(go env GOPATH)/bin(N-/)
  $HOME/.cargo/bin(N-/)
  /usr/local/go/bin(N-/)
  /usr/local/opt/openjdk/bin(N-/)
  /usr/local/bin(N-/)
  /usr/local/sbin(N-/)
  /opt/homebrew/bin(N-/)
  /opt/homebrew/sbin(N-/)
  $PNPM_HOME(N-/)
  /usr/bin
  /usr/sbin
  /bin
  /sbin
  /Library/Apple/usr/bin
)
alias tf=terraform
alias awslocal="AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=ap-northeast-1 aws --endpoint-url=http://localhost:34566"
# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/pc0041/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/pc0041/google-cloud-sdk/path.zsh.inc'; fi
# The next line enables shell command completion for gcloud.
if [ -f '/Users/pc0041/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/pc0041/google-cloud-sdk/completion.zsh.inc'; fi
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  autoload -Uz compinit && compinit
fi
export NVM_DIR=$HOME/.nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
# nvm use default
eval "$(fzf --zsh)"
# eval "$(mcfly init zsh)"
eval "$(starship init zsh)"
### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
# export PATH="/Users/pc0041/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

source ~/.safe-chain/scripts/init-posix.sh # Safe-chain Zsh initialization script

eval "$(zoxide init zsh --cmd cd)"
eval "$(mcfly init zsh)"
