#!/usr/bin/env bash

set -euo pipefail

readonly expected_swiftlint_version="0.65.0"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v swiftlint >/dev/null || fail \
  "SwiftLint ${expected_swiftlint_version} is required but was not found."

actual_swiftlint_version="$(swiftlint version 2>&1)" || fail \
  "SwiftLint could not report its version."

[[ "${actual_swiftlint_version}" == "${expected_swiftlint_version}" ]] || fail \
  "expected SwiftLint ${expected_swiftlint_version}, found ${actual_swiftlint_version}."

printf 'Verified SwiftLint %s.\n' "${actual_swiftlint_version}"
