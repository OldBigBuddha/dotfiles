# aliases.zsh - Cross-platform aliases

# Terraform
alias tf=terraform

# AWS LocalStack
alias awslocal="AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=ap-northeast-1 aws --endpoint-url=http://localhost:34566"

# neovim
alias vim="nvim"

# git-root
alias cdr="cd $(git-root)"

# yazi shell wrapper
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}
