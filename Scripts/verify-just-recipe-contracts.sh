#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"
build_justfile="${repository_root}/commands/build.just"
test_justfile="${repository_root}/commands/test.just"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v just >/dev/null || fail "just is required to verify recipe contracts."
command -v jq >/dev/null || fail "jq is required to verify recipe contracts."
command -v rg >/dev/null || fail "rg is required to verify recipe contracts."

assert_pattern_absent() {
  local pattern="$1"
  shift

  local findings
  local status
  set +e
  findings="$(rg -n -- "${pattern}" "$@" 2>&1)"
  status=$?
  set -e

  case "${status}" in
    0)
      printf '%s\n' "${findings}" >&2
      fail "unexpected '${pattern}' reference"
      ;;
    1)
      ;;
    *)
      printf '%s\n' "${findings}" >&2
      fail "rg failed while checking for '${pattern}'"
      ;;
  esac
}

assert_dependencies() {
  local dump="$1"
  local recipe="$2"
  shift 2

  local actual
  actual="$(
    jq -r \
      --arg recipe "${recipe}" \
      '.recipes[$recipe].dependencies[]?.recipe' \
      <<<"${dump}" \
      | LC_ALL=C sort
  )"

  local expected
  expected="$(printf '%s\n' "$@" | LC_ALL=C sort)"

  if [[ "${actual}" != "${expected}" ]]; then
    printf 'Recipe dependency mismatch for %s.\nExpected:\n%s\nActual:\n%s\n' \
      "${recipe}" \
      "${expected}" \
      "${actual}" \
      >&2
    exit 1
  fi
}

assert_recipe_absent() {
  local dump="$1"
  local recipe="$2"

  if jq -e --arg recipe "${recipe}" '.recipes | has($recipe)' <<<"${dump}" >/dev/null; then
    fail "obsolete recipe '${recipe}' is still declared"
  fi
}

assert_body_mentions() {
  local dump="$1"
  local recipe="$2"
  local fragment="$3"

  jq -e \
    --arg recipe "${recipe}" \
    --arg fragment "${fragment}" \
    '(.recipes[$recipe].body | tostring | contains($fragment))' \
    <<<"${dump}" \
    >/dev/null \
    || fail "recipe '${recipe}' does not invoke '${fragment}'"
}

build_dump="$(just --justfile "${build_justfile}" --dump --dump-format json)"
test_dump="$(just --justfile "${test_justfile}" --dump --dump-format json)"

assert_pattern_absent \
  'HEAVY_VALIDATION' \
  "${repository_root}/Sources" \
  "${repository_root}/Tests" \
  "${build_justfile}" \
  "${test_justfile}"

for obsolete_recipe in \
  debug-with-validation \
  release-with-validation \
  all-with-validation \
  all-debug \
  all-release; do
  assert_recipe_absent "${build_dump}" "${obsolete_recipe}"
  assert_recipe_absent "${test_dump}" "${obsolete_recipe}"
done

assert_dependencies "${build_dump}" all debug release

assert_dependencies "${test_dump}" all all-standard all-validation
assert_dependencies "${test_dump}" all-standard debug release
assert_dependencies \
  "${test_dump}" \
  all-sanitizers \
  address-sanitizer \
  thread-sanitizer \
  undefined-behavior-sanitizer
assert_dependencies \
  "${test_dump}" \
  all-validation \
  all-sanitizers \
  coverage \
  fuzz-smoke \
  hostile-input \
  recipe-contracts \
  xpc-integration \
  zero-known-issue-controls

# The standard unit-test recipes must go through the canonical zero-known-issue
# wrapper, not a bare `swift test`: that wrapper is what CI runs, and sharing it
# is what keeps the release policy from drifting between local and CI runs.
assert_body_mentions "${test_dump}" debug 'run-tests-with-zero-known-issues.sh debug'
assert_body_mentions "${test_dump}" release 'run-tests-with-zero-known-issues.sh release'
assert_body_mentions \
  "${test_dump}" \
  zero-known-issue-controls \
  'run-tests-with-zero-known-issues.sh self-test'
assert_body_mentions "${test_dump}" coverage 'generate-source-coverage.sh'

assert_body_mentions "${test_dump}" address-sanitizer 'run-sanitizer-tests.sh address'
assert_body_mentions "${test_dump}" thread-sanitizer 'run-sanitizer-tests.sh thread'
assert_body_mentions "${test_dump}" undefined-behavior-sanitizer 'run-sanitizer-tests.sh undefined'
assert_body_mentions "${test_dump}" fuzz-smoke 'run-fuzzing-smoke.sh'
assert_body_mentions "${test_dump}" hostile-input 'run-hostile-input-tests.sh'
assert_body_mentions "${test_dump}" recipe-contracts 'verify-just-recipe-contracts.sh'
assert_body_mentions "${test_dump}" xpc-integration 'run-xpc-integration.sh'

printf '%s\n' \
  "Verified build/test aggregate dependencies and distinct real validation commands."
