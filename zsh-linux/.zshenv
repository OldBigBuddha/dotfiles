# .zshenv - Linux

# Keep user-installed tools available to login, interactive, and non-interactive
# shells. mise installs itself here before its shell activation is available.
typeset -U PATH path
path=(
  $HOME/.local/bin(N-/)
  $HOME/.cargo/bin(N-/)
  ${path}
)
