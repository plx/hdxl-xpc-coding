#!/usr/bin/env bash

set -euo pipefail

readonly expected_xcode_version="26.6"
readonly expected_xcode_build="17F113"
readonly expected_swift_version="6.3.3"
readonly expected_tools_version="6.3.0"
readonly expected_architecture="arm64"

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"
cd "${repository_root}"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v jq >/dev/null || fail "jq is required to verify Package.swift."

xcode_version_output="$(xcodebuild -version 2>&1)"
swift_version_output="$(swift --version 2>&1)"
actual_architecture="$(uname -m)"

printf '%s\n' "${xcode_version_output}"
printf '%s\n' "${swift_version_output}"

actual_xcode_version="$(sed -n 's/^Xcode //p' <<<"${xcode_version_output}")"
actual_xcode_build="$(sed -n 's/^Build version //p' <<<"${xcode_version_output}")"
actual_swift_version="$(
  sed -n 's/.*Apple Swift version \([^ ]*\).*/\1/p' <<<"${swift_version_output}"
)"

[[ "${actual_xcode_version}" == "${expected_xcode_version}" ]] || fail \
  "expected Xcode ${expected_xcode_version}, found ${actual_xcode_version:-unknown}."
[[ "${actual_xcode_build}" == "${expected_xcode_build}" ]] || fail \
  "expected Xcode build ${expected_xcode_build}, found ${actual_xcode_build:-unknown}."
[[ "${actual_swift_version}" == "${expected_swift_version}" ]] || fail \
  "expected Apple Swift ${expected_swift_version}, found ${actual_swift_version:-unknown}."
[[ "${actual_architecture}" == "${expected_architecture}" ]] || fail \
  "expected host architecture ${expected_architecture}, found ${actual_architecture:-unknown}."

package_description="$(swift package dump-package)"

jq -e \
  --arg tools_version "${expected_tools_version}" \
  '
    .toolsVersion._version == $tools_version
    and .swiftLanguageVersions == ["6"]
    and .platforms == [
      {
        "options": [],
        "platformName": "macos",
        "version": "26.0"
      },
      {
        "options": [],
        "platformName": "ios",
        "version": "26.0"
      },
      {
        "options": [],
        "platformName": "maccatalyst",
        "version": "26.0"
      }
    ]
  ' <<<"${package_description}" >/dev/null || fail \
  "Package.swift must use Swift tools 6.3, Swift language mode 6, and exactly macOS/iOS/Mac Catalyst 26.0."

printf '%s\n' \
  "Verified support policy: Xcode ${expected_xcode_version} (${expected_xcode_build}), Apple Swift ${expected_swift_version}, Swift 6 language mode, and arm64 Apple platforms 26.0."
