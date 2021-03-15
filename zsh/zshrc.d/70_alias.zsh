### Alias ###
alias ls="lsd -F"
alias ll="lsd -Fl"      # 詳細情報付きでファイルサイズの単位整形
alias la="lsd -FAl" # 詳細情報付きすべてのファイルを表示、単位整形
alias cp="gcp -i -v"
alias mkdir="gmkdir -p -v"
alias cp="gcp -r -i -v"
alias rm="grm -v -i"
alias mv="gmv -i -v"
alias back="cd -"
alias home="cd $HOME"
alias wd="cd $work_dir"
alias tree='tree -a -I "\.DS_Store|\.git|node_modules|vendor\/bundle" -N'

# git
alias git="hub"
alias g="git add -A;git commit;git push"
alias ga="git add"
alias gb="git branch"
alias gc="git commit"
alias gco="git checkout"
alias gd="git diff"
alias gf="git fetch"
alias gm="git merge"
alias gnb="git checkout -b"
alias gp="git push"
alias gr="git rebase"
alias gs="git status"

# brew
alias bd="brew doctor"
alias bi="brew install"
alias bun="brew uninstall"
alias bl="brew list"
alias bcheck="brew list | grep"

# poetry
alias pdev="poety add -D black flake8 mypy pytest"

alias f="open ."

alias upzshrc="source $HOME/.zshrc"
alias upzshenv="source $HOME/.zshenv"

alias cat="bat"
alias g++="g++-10"

alias ...='cd ../..'
alias ....='cd ../../..'

# Global
abbrev-alias -g L="| less"
abbrev-alias -g G="| grep"
