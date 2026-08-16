# .zshenv - Linux

# Keep user-installed tools available to login, interactive, and non-interactive
# shells. Non-interactive shells use mise shims because the prompt hook from
# `mise activate` only belongs in .zshrc.
typeset -U PATH path
path=(
  $HOME/.local/bin(N-/)
  $HOME/.cargo/bin(N-/)
  ${path}
)

if [[ ! -o interactive ]]; then
  dotfiles_mise_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/mise"
  path=(
    $dotfiles_mise_data_dir/shims(N-/)
    ${path}
  )
  unset dotfiles_mise_data_dir
fi
