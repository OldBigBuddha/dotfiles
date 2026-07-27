#!/usr/bin/env bash
# Real git repositories for the guard tests.
#
# The guards ask git where worktrees are rather than guessing from directory
# shape, so the fixtures have to be real repositories -- a directory tree that
# merely looks like one would test nothing. Both supported layouts are built,
# because they differ in exactly the way that used to break role detection:
#
#   normal    root/.git/            worktrees live inside root/
#   bare      base/classic.git/     worktrees live beside classic.git/
set -euo pipefail

# Create a conventional repository with one linked worktree.
# Echoes: <root> <linked-worktree>
fixture_normal_repo() {
  local -r root="$1"

  mkdir -p "${root}"
  git -C "${root}" init -q
  git -C "${root}" config user.email suberu@example.invalid
  git -C "${root}" config user.name Suberu
  git -C "${root}" commit -q --allow-empty -m init
  mkdir -p "${root}/wt"
  git -C "${root}" worktree add -q "${root}/wt" -b wt >/dev/null 2>&1
  mkdir -p "${root}/wt/src" "${root}/wt/.suberu"

  printf '%s %s' "${root}" "${root}/wt"
}

# Create a textbook bare repository whose worktrees are siblings of it.
# Echoes: <bare-dir> <linked-worktree>
fixture_bare_repo() {
  local -r base="$1"
  local -r bare="${base}/classic.git"

  mkdir -p "${base}"
  git -C "${base}" init -q --bare classic.git
  git -C "${bare}" commit-tree -m init "$(git -C "${bare}" mktree </dev/null)" >/dev/null 2>&1 || true
  git -C "${bare}" worktree add -q "${base}/wt-a" -b a >/dev/null 2>&1
  mkdir -p "${base}/wt-a/src" "${base}/wt-a/.suberu"

  printf '%s %s' "${bare}" "${base}/wt-a"
}
