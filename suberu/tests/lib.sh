#!/usr/bin/env bash
# Assertion helpers shared by every test_*.sh file.
#
# Tests are plain Bash because Suberu's units are plain Bash and the machine
# has no bats. Each test file sources this, calls assert_* freely, and exits
# non-zero if any assertion failed.
#
# Trace mode is deliberately off here: assertion output is the readable
# contract of a test run, and `set -x` would bury it.
set -euo pipefail

TESTS_RUN=0
TESTS_FAILED=0

# Report a passing or failing assertion and keep the tally.
_record() {
  local -r ok="$1"
  local -r label="$2"
  local -r detail="${3:-}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "${ok}" == "yes" ]]; then
    printf '  ok   %s\n' "${label}"
    return 0
  fi
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  FAIL %s\n' "${label}"
  if [[ -n "${detail}" ]]; then
    printf '       %s\n' "${detail}"
  fi
  return 0
}

assert_equals() {
  local -r expected="$1"
  local -r actual="$2"
  local -r label="$3"
  if [[ "${expected}" == "${actual}" ]]; then
    _record yes "${label}"
  else
    _record no "${label}" "expected [${expected}] got [${actual}]"
  fi
}

assert_contains() {
  local -r haystack="$1"
  local -r needle="$2"
  local -r label="$3"
  if [[ "${haystack}" == *"${needle}"* ]]; then
    _record yes "${label}"
  else
    _record no "${label}" "[${needle}] not found in [${haystack}]"
  fi
}

assert_exit_code() {
  local -r expected="$1"
  local -r actual="$2"
  local -r label="$3"
  assert_equals "${expected}" "${actual}" "${label}"
}

# Print the tally and exit non-zero when anything failed.
finish_tests() {
  printf '  -- %d assertions, %d failed\n' "${TESTS_RUN}" "${TESTS_FAILED}"
  if [[ "${TESTS_FAILED}" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}
