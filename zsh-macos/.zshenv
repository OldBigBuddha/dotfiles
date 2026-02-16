# .zshenv - macOS

export PATH
export MANPATH
export WORK_DIR
export NPM_PACKAGES

work_dir=$HOME/work_dir
npm_packages=$HOME/.npm-packages

# -U: keep only the first occurrence of each duplicated value
typeset -U PATH path MANPATH manpath FPATH fpath

# ignore /etc/zprofile, /etc/zshrc, /etc/zlogin, and /etc/zlogout
unsetopt GLOBAL_RCS

# macOS path_helper
if [ -x /usr/libexec/path_helper ]; then
    eval $(/usr/libexec/path_helper -s)
fi

# Minimal PATH for non-interactive shells
# Interactive shells: overridden by path-macos.zsh
path=(
    $HOME/.local/bin(N-/)
    $HOME/.orbstack/bin(N-/)
    /usr/local/bin(N-/)
    /usr/local/sbin(N-/)
    ${path}
)

manpath=(
    /usr/local/share/man(N-/)
    ${npm_packages}/share/man(N-/)
    ${manpath}
)

# Homebrew command restrictions
export HOMEBREW_FORBIDDEN_FORMULAE="node python python3 pip npm pnpm yarn claude"
