#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "E2E failure: $*" >&2
  exit 1
}

assert_link() {
  local link_path="$1"
  local expected_target="$2"

  [[ -L "$link_path" ]] || fail "$link_path is not a symlink"
  [[ "$(readlink -f "$link_path")" == "$expected_target" ]] || \
    fail "$link_path does not point to $expected_target"
}

source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ "$(id -u)" -eq 0 ]] || fail "run this test as root inside a disposable container"
[[ -r /etc/os-release ]] || fail "/etc/os-release is missing"

# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]] || \
  fail "expected Ubuntu 24.04, found ${PRETTY_NAME:-unknown}"

for prerequisite in git curl stow zsh; do
  command -v "$prerequisite" >/dev/null 2>&1 && \
    fail "the image already contains $prerequisite"
done

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
test_repo="$HOME/dotfiles"
mkdir -p "$HOME"
cp -R "$source_root" "$test_repo"
cd "$test_repo"

# The first run exercises APT bootstrap; the second proves the applied state is
# idempotent and does not require package installation again.
DEBIAN_FRONTEND=noninteractive ./setup.sh
DEBIAN_FRONTEND=noninteractive ./setup.sh

command -v stow >/dev/null 2>&1 || fail "GNU Stow was not installed"
command -v zsh >/dev/null 2>&1 || fail "zsh was not installed"
command -v git >/dev/null 2>&1 || fail "Git was not installed"
command -v curl >/dev/null 2>&1 || fail "curl was not installed"
[[ -x "$HOME/.local/bin/mise" ]] || fail "mise was not installed"
"$HOME/.local/bin/mise" exec herdr -- herdr --version >/dev/null || \
  fail "Herdr was not installed through mise"
installed_zsh_package="$(dpkg-query -W -f='${Version}' zsh 2>/dev/null || true)"
candidate_zsh_package="$(apt-cache policy zsh | awk '/Candidate:/ { print $2; exit }')"
[[ -n "$installed_zsh_package" && -n "$candidate_zsh_package" ]] || \
  fail "could not determine the installed and candidate zsh packages"
dpkg --compare-versions "$installed_zsh_package" ge "$candidate_zsh_package" || \
  fail "installed zsh is older than the APT candidate"

assert_link "$HOME/.zshenv" "$test_repo/zsh-linux/.zshenv"
assert_link "$HOME/.zshrc" "$test_repo/zsh-linux/.zshrc"
assert_link "$HOME/.gitconfig" "$test_repo/git/.gitconfig"
assert_link "$HOME/.config/gh/config.yml" "$test_repo/gh/.config/gh/config.yml"
assert_link "$HOME/.config/mise/config.toml" "$test_repo/mise/.config/mise/config.toml"
assert_link "$HOME/.config/nvim/init.lua" "$test_repo/nvim/.config/nvim/init.lua"
assert_link "$HOME/.config/starship.toml" "$test_repo/starship/.config/starship.toml"
assert_link "$HOME/.config/yazi/yazi.toml" "$test_repo/yazi/.config/yazi/yazi.toml"

[[ -x "$HOME/.local/bin/git-root" ]] || fail "git-root was not installed"
[[ -x "$HOME/.local/bin/git-pwd" ]] || fail "git-pwd was not installed"
[[ ! -e "$HOME/.local/bin/ssh-sign" ]] || fail "macOS ssh-sign was installed on Linux"
[[ ! -e "$HOME/.local/bin/setup-git-signing-key" ]] || \
  fail "macOS signing setup was installed on Linux"

[[ ! -e "$HOME/.config/git/local.inc" ]] || fail "optional git-linux signing was applied"
if git config --global --get commit.gpgsign >/dev/null; then
  fail "commit signing must remain disabled without an OS signing overlay"
fi

[[ ! -e "$HOME/.config/gh/hosts.yml" ]] || fail "GitHub authentication state was stowed"
git check-ignore -q gh/.config/gh/hosts.yml || fail "GitHub authentication state is not ignored"

DOTFILES_E2E_REPO="$test_repo" zsh -lic '
  [[ -o sharehistory ]] || exit 1
  (( $+functions[cdr] )) || exit 1
  command -v git-root >/dev/null || exit 1
  command -v herdr >/dev/null || exit 1
  cd "$DOTFILES_E2E_REPO/zsh/.config"
  cdr
  [[ "$PWD" == "$DOTFILES_E2E_REPO" ]]
' || fail "Linux zsh startup or shared functions failed"

echo "Ubuntu 24.04 E2E: PASS"
