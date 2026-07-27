#!/usr/bin/env bash
# Run every test_*.sh in this directory, then shellcheck every shipped script.
#
# Trace mode is off deliberately; see tests/lib.sh for the reason.
set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly tests_dir
suberu_root="$(dirname "${tests_dir}")"
readonly suberu_root

failed=0

for test_file in "${tests_dir}"/test_*.sh; do
  printf '\n== %s\n' "$(basename "${test_file}")"
  if ! bash "${test_file}"; then
    failed=$((failed + 1))
  fi
done

printf '\n== shellcheck\n'
if command -v shellcheck >/dev/null 2>&1; then
  # SC1091: sourced helpers are resolved at runtime, not by shellcheck.
  if shellcheck --exclude=SC1091 --shell=bash \
    "${suberu_root}"/herdr/bin/*.sh \
    "${suberu_root}"/claude/plugins/suberu/scripts/*.sh \
    "${suberu_root}"/tests/*.sh; then
    printf '  ok   shellcheck clean\n'
  else
    printf '  FAIL shellcheck reported findings\n'
    failed=$((failed + 1))
  fi
else
  printf '  SKIP shellcheck not installed\n'
fi

printf '\n'
if [[ "${failed}" -gt 0 ]]; then
  printf 'FAILED: %d suite(s)\n' "${failed}"
  exit 1
fi
printf 'All suites passed.\n'
