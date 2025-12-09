# Set PATH, MANPATH, etc., for Homebrew.
eval "$(/opt/homebrew/bin/brew shellenv)"

# Added by OrbStack: command-line tools and integration
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

# Added by `rbenv init` on Thu May 29 17:34:37 JST 2025
eval "$(rbenv init - --no-rehash zsh)"
