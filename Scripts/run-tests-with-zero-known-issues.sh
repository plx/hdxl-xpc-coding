#!/usr/bin/env bash

# Canonical zero-known-issue unit-test runner.
#
# XPCCoding's release policy is that a passing test run reports *zero* known
# issues. Intentionally lossy behavior — notably the `.assumeAbsent` string
# strategies — has to be asserted exactly rather than parked behind
# `withKnownIssue`, because a suite that "passes with 69 known issues" is not a
# release signal anybody can read.
#
# This is the single implementation behind `just test debug`, `just test
# release`, and the corresponding CI jobs, so the policy cannot drift between a
# developer's machine and CI. It fails closed on every one of:
#
#   - `withKnownIssue` or `XCTExpectFailure` anywhere in first-party sources;
#   - a known-issue or expected-failure marker in the captured test output;
#   - a raw NUL byte in the captured test output; or
#   - a missing or non-passing test-run summary.
#
# It depends only on bash, coreutils-equivalent tools, and the Swift toolchain:
# no `just`, no `jq`, no ripgrep. CI runners get those tools for free.
#
# Usage:
#   Scripts/run-tests-with-zero-known-issues.sh debug
#   Scripts/run-tests-with-zero-known-issues.sh release
#   Scripts/run-tests-with-zero-known-issues.sh coverage
#   Scripts/run-tests-with-zero-known-issues.sh self-test

set -euo pipefail

# Source files must never reintroduce a known-issue escape hatch.
readonly SOURCE_MARKER_PATTERN='withKnownIssue|XCTExpectFailure'

# Test output must never report one, under either testing library.
readonly OUTPUT_MARKER_PATTERN='known issue|expected failure'

# A run that never reported a passing summary is not evidence of anything.
readonly SUMMARY_PATTERN='Test run with [0-9][0-9]* tests in [0-9][0-9]* suites passed'

# Directories that hold first-party Swift code, relative to the repository root.
readonly SOURCE_DIRECTORIES=(Sources Tests IntegrationTests Benchmarks)

usage() {
  printf 'usage: %s {debug|release|coverage|self-test}\n' "${0##*/}" >&2
  exit 64
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# Scratch state is global so the EXIT trap can still see it after the function
# that created it has returned.
scratch_directory=""

cleanup() {
  if [[ -n "${scratch_directory}" ]]; then
    rm -rf -- "${scratch_directory}"
  fi
}
trap cleanup EXIT

# MARK: - Checks
#
# Each `check_` function prints its own diagnostics and returns 0 (clean) or 1
# (violation), so the self-test can exercise both outcomes without exiting.

check_source_markers() {
  local root="$1"

  local -a directories=()
  local candidate
  for candidate in "${SOURCE_DIRECTORIES[@]}"; do
    if [[ -d "${root}/${candidate}" ]]; then
      directories+=("${root}/${candidate}")
    fi
  done

  if [[ ${#directories[@]} -eq 0 ]]; then
    printf 'No first-party source directories found under %s.\n' "${root}" >&2
    return 1
  fi

  local findings
  local status
  set +e
  findings="$(
    grep -R -n -E --include='*.swift' -e "${SOURCE_MARKER_PATTERN}" "${directories[@]}" 2>&1
  )"
  status=$?
  set -e

  case "${status}" in
    0)
      printf '%s\n' "${findings}" >&2
      printf 'Found a reintroduced known-issue escape hatch in first-party sources.\n' >&2
      return 1
      ;;
    1)
      return 0
      ;;
    *)
      printf '%s\n' "${findings}" >&2
      printf 'grep failed while scanning for known-issue markers.\n' >&2
      return 1
      ;;
  esac
}

check_output_markers() {
  local log_file="$1"

  local findings
  local status
  set +e
  findings="$(grep -a -n -i -E -e "${OUTPUT_MARKER_PATTERN}" -- "${log_file}" 2>&1)"
  status=$?
  set -e

  case "${status}" in
    0)
      printf '%s\n' "${findings}" >&2
      printf 'The test run reported known issues or expected failures.\n' >&2
      return 1
      ;;
    1)
      return 0
      ;;
    *)
      printf '%s\n' "${findings}" >&2
      printf 'grep failed while scanning the test output.\n' >&2
      return 1
      ;;
  esac
}

check_output_null_bytes() {
  local log_file="$1"

  local total_bytes
  local stripped_bytes
  total_bytes="$(wc -c <"${log_file}" | tr -d '[:space:]')"
  stripped_bytes="$(tr -d '\000' <"${log_file}" | wc -c | tr -d '[:space:]')"

  if [[ "${total_bytes}" != "${stripped_bytes}" ]]; then
    printf 'The test output contains %d raw NUL byte(s); embedded-null probes must report bytes, not raw values.\n' \
      "$((total_bytes - stripped_bytes))" \
      >&2
    return 1
  fi

  return 0
}

check_passing_summary() {
  local log_file="$1"

  local status
  set +e
  grep -a -q -E -e "${SUMMARY_PATTERN}" -- "${log_file}"
  status=$?
  set -e

  if [[ "${status}" -ne 0 ]]; then
    printf 'The test output has no passing test-run summary; refusing to report success.\n' >&2
    return 1
  fi

  return 0
}

# MARK: - Test Run

run_tests() {
  local configuration="$1"
  local root="$2"
  local run_name="$3"
  shift 3

  scratch_directory="$(mktemp -d \
    "${TMPDIR:-/tmp}/hdxl-xpc-zero-known-issues.XXXXXX")"

  local log_file="${scratch_directory}/test-output.log"

  check_source_markers "${root}" \
    || fail "first-party sources must not contain withKnownIssue or XCTExpectFailure"

  printf 'Running the %s unit suite under the zero-known-issue policy.\n' "${run_name}"

  # `set -o pipefail` is already in effect, so a failing `swift test` still
  # fails the script even though its output flows through `tee`.
  (
    cd -- "${root}"
    swift test \
      --configuration "${configuration}" \
      -Xswiftc -warnings-as-errors \
      "$@" \
      2>&1
  ) | tee "${log_file}"

  check_passing_summary "${log_file}" \
    || fail "the ${run_name} run produced no passing summary"
  check_output_markers "${log_file}" \
    || fail "the ${run_name} run reported known issues"
  check_output_null_bytes "${log_file}" \
    || fail "the ${run_name} run emitted raw NUL bytes"

  printf '\nVerified: %s run passed with zero known issues and no raw NUL bytes in its output.\n' \
    "${run_name}"
}

# MARK: - Self-Test
#
# Positive and negative controls for every detector above. This runs in about a
# second and builds nothing, so a broken gate is caught before it silently
# starts passing everything.

expect_clean() {
  local description="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    printf '  ok: %s\n' "${description}"
  else
    fail "positive control failed: ${description}"
  fi
}

expect_violation() {
  local description="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    fail "negative control failed: ${description}"
  else
    printf '  ok: %s\n' "${description}"
  fi
}

run_self_test() {
  local root="$1"

  scratch_directory="$(mktemp -d \
    "${TMPDIR:-/tmp}/hdxl-xpc-zero-known-issues-self-test.XXXXXX")"

  printf 'Running zero-known-issue gate controls.\n'

  # Source-marker controls.
  mkdir -p "${scratch_directory}/clean-tree/Tests"
  printf '@Test func example() { #expect(1 == 1) }\n' \
    >"${scratch_directory}/clean-tree/Tests/Example.swift"
  expect_clean \
    'a marker-free source tree is accepted' \
    check_source_markers "${scratch_directory}/clean-tree"

  mkdir -p "${scratch_directory}/known-issue-tree/Tests"
  printf '@Test func example() { withKnownIssue { #expect(1 == 2) } }\n' \
    >"${scratch_directory}/known-issue-tree/Tests/Example.swift"
  expect_violation \
    'a reintroduced withKnownIssue is rejected' \
    check_source_markers "${scratch_directory}/known-issue-tree"

  mkdir -p "${scratch_directory}/expect-failure-tree/Tests"
  printf 'func testExample() { XCTExpectFailure { XCTAssertTrue(false) } }\n' \
    >"${scratch_directory}/expect-failure-tree/Tests/Example.swift"
  expect_violation \
    'a reintroduced XCTExpectFailure is rejected' \
    check_source_markers "${scratch_directory}/expect-failure-tree"

  expect_violation \
    'a source tree with no first-party directories is rejected' \
    check_source_markers "${scratch_directory}/known-issue-tree/Tests"

  # Output controls.
  local clean_log="${scratch_directory}/clean.log"
  printf 'Test run with 284 tests in 33 suites passed after 0.1 seconds.\n' >"${clean_log}"
  expect_clean 'a clean passing transcript is accepted' check_output_markers "${clean_log}"
  expect_clean 'a clean passing transcript has a summary' check_passing_summary "${clean_log}"
  expect_clean 'a clean passing transcript has no NUL bytes' check_output_null_bytes "${clean_log}"

  local known_issue_log="${scratch_directory}/known-issue.log"
  printf 'Test run with 284 tests in 33 suites passed after 0.1 seconds with 69 known issues.\n' \
    >"${known_issue_log}"
  expect_violation \
    'a transcript reporting known issues is rejected' \
    check_output_markers "${known_issue_log}"

  local expected_failure_log="${scratch_directory}/expected-failure.log"
  printf 'Test case example passed with 1 expected failure.\n' >"${expected_failure_log}"
  expect_violation \
    'a transcript reporting an expected failure is rejected' \
    check_output_markers "${expected_failure_log}"

  local summary_free_log="${scratch_directory}/summary-free.log"
  printf 'error: could not build the test target\n' >"${summary_free_log}"
  expect_violation \
    'a transcript with no passing summary is rejected' \
    check_passing_summary "${summary_free_log}"

  local null_byte_log="${scratch_directory}/null-byte.log"
  {
    printf 'Test case passing 1 argument probe -> "Hello'
    head -c 1 /dev/zero
    printf 'world" started.\n'
    printf 'Test run with 1 tests in 1 suites passed after 0.1 seconds.\n'
  } >"${null_byte_log}"
  expect_violation \
    'a transcript containing a raw NUL byte is rejected' \
    check_output_null_bytes "${null_byte_log}"

  # The real tree has to satisfy the same source gate the controls exercise.
  expect_clean \
    'this repository is free of known-issue markers' \
    check_source_markers "${root}"

  printf 'All zero-known-issue gate controls behaved as expected.\n'
}

# MARK: - Entry Point

[[ $# -eq 1 ]] || usage

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly script_directory

repository_root="$(cd -- "${script_directory}/.." && pwd)"
readonly repository_root

case "$1" in
  debug | release)
    run_tests "$1" "${repository_root}" "$1"
    ;;
  coverage)
    run_tests debug "${repository_root}" coverage --enable-code-coverage
    ;;
  self-test)
    run_self_test "${repository_root}"
    ;;
  *)
    usage
    ;;
esac
