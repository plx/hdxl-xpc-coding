#!/usr/bin/env bash

set -euo pipefail

readonly expected_swift_format_version="6.3.0"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v xcrun >/dev/null || fail \
  "xcrun is required to select swift-format from the active Xcode toolchain."

swift_format_path="$(xcrun --find swift-format 2>/dev/null)" || fail \
  "swift-format ${expected_swift_format_version} was not found in the active Xcode toolchain."

[[ -x "${swift_format_path}" ]] || fail \
  "swift-format is not executable at ${swift_format_path}."

actual_swift_format_version="$("${swift_format_path}" --version 2>&1)" || fail \
  "swift-format could not report its version."

[[ "${actual_swift_format_version}" == "${expected_swift_format_version}" ]] || fail \
  "expected swift-format ${expected_swift_format_version}, found ${actual_swift_format_version} at ${swift_format_path}."

printf 'Verified swift-format %s at %s.\n' \
  "${actual_swift_format_version}" \
  "${swift_format_path}"
