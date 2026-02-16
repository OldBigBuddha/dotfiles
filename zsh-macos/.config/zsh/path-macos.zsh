# path-macos.zsh - macOS-specific PATH configuration

export PNPM_HOME="$HOME/Library/pnpm"

path=(
  $HOME/.local/bin(N-/)
  $(go env GOPATH 2>/dev/null)/bin(N-/)
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

# Google Cloud SDK
[ -f "$HOME/work_dir/google-cloud-sdk/path.zsh.inc" ] && source "$HOME/work_dir/google-cloud-sdk/path.zsh.inc"
[ -f "$HOME/work_dir/google-cloud-sdk/completion.zsh.inc" ] && source "$HOME/work_dir/google-cloud-sdk/completion.zsh.inc"

# Homebrew completions and plugins
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  autoload -Uz compinit && compinit
fi
