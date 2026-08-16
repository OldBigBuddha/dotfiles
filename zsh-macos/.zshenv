# .zshenv - macOS

export PATH
export MANPATH
export WORK_DIR="$HOME/work_dir"
export ANTIGRAVITY_ROOT="$HOME/.antigravity"
export NPM_PACKAGES="$HOME/.npm-packages"
# for microsandbox
export DYLD_LIBRARY_PATH="$HOME/.microsandbox/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"

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
    $HOME/.microsandbox/bin(N-/)
    $HOME/.orbstack/bin(N-/)
    $ANTIGRAVITY_ROOT/antigravity/bin
    /usr/local/bin(N-/)
    /usr/local/sbin(N-/)
    ${path}
)


manpath=(
    /usr/local/share/man(N-/)
    ${NPM_PACKAGES}/share/man(N-/)
    ${manpath}
)

# Homebrew command restrictions
export HOMEBREW_FORBIDDEN_FORMULAE="node python python3 pip npm pnpm yarn claude"
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
