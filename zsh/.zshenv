export PATH
export MANPATH
export WORK_DIR
export NPM_PACKAGES

work_dir=$HOME/work_dir
npm_packages=$HOME/.npm-packages

# -U: keep only the first occurrence of each duplicated value
# ref. http://zsh.sourceforge.net/Doc/Release/Shell-Builtin-Commands.html#index-typeset
typeset -U PATH path MANPATH manpath FPATH fpath

# ignore /etc/zprofile, /etc/zshrc, /etc/zlogin, and /etc/zlogout
# ref. http://zsh.sourceforge.net/Doc/Release/Files.html
# ref. http://zsh.sourceforge.net/Doc/Release/Options.html#index-GLOBALRCS
unsetopt GLOBAL_RCS

# copied from /etc/zprofile
# system-wide environment settings for zsh(1)
if [ -x /usr/libexec/path_helper ]; then
    eval `/usr/libexec/path_helper -s`
fi

path=(
    $HOME/.local/bin(N-/)
    ${npm_packages}/bin(N-/)
    /usr/local/bin(N-/)
    /usr/local/sbin(N-/)
    ${path}
)

manpath=(
    /usr/local/share/man(N-/)
    ${npm_packages}/share/man(N-/)
    ${manpath}
)

. "$HOME/.cargo/env"


