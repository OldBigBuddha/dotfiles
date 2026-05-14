#!/bin/sh
# Claude Code status line - Starship-flavored

input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(printf '%s' "$input" | jq -r '.model.display_name // ""')
ctx_used=$(printf '%s' "$input" | jq -r '.context_window.used // empty')
ctx_total=$(printf '%s' "$input" | jq -r '.context_window.total // empty')

# Directory: ~ for home, else basename
case "$cwd" in
  "$HOME") dir="~" ;;
  "$HOME"/*) dir="~/${cwd#$HOME/}" ;;
  *) dir="$cwd" ;;
esac

# Git info
branch=""
git_status=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
    git_status="*"
  fi
fi

# Colors (bold cyan dir, purple branch like Starship default)
C_DIR='\033[1;36m'
C_BRANCH='\033[1;35m'
C_DIRTY='\033[1;33m'
C_MODEL='\033[2m'
C_CTX='\033[2m'
C_CTX_LOW='\033[33m'
C_RESET='\033[0m'

out=$(printf "${C_DIR}%s${C_RESET}" "$dir")
if [ -n "$branch" ]; then
  out="$out$(printf " ${C_BRANCH}(%s)${C_RESET}" "$branch")"
  if [ -n "$git_status" ]; then
    out="$out$(printf "${C_DIRTY}%s${C_RESET}" "$git_status")"
  fi
fi
if [ -n "$model" ]; then
  out="$out$(printf "\n${C_MODEL}%s${C_RESET}" "$model")"
fi
if [ -n "$ctx_used" ] && [ -n "$ctx_total" ] && [ "$ctx_total" -gt 0 ]; then
  pct=$(( ctx_used * 100 / ctx_total ))
  if [ "$ctx_total" -ge 1000 ]; then
    total_h="$(( ctx_total / 1000 ))k"
  else
    total_h="$ctx_total"
  fi
  if [ "$pct" -ge 80 ]; then
    out="$out$(printf " ${C_CTX_LOW}ctx:%s%%/%s${C_RESET}" "$pct" "$total_h")"
  else
    out="$out$(printf " ${C_CTX}ctx:%s%%/%s${C_RESET}" "$pct" "$total_h")"
  fi
fi

printf '%b' "$out"
