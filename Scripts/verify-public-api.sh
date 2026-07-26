#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"
consumer_directory="${repository_root}/IntegrationTests/PublicAPIConsumer"
public_test_directory="${repository_root}/Tests/XPCCodingPublicAPITests"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v jq >/dev/null || fail "jq is required to inspect the Swift target."

if grep -R -n -E '@testable[[:space:]]+import[[:space:]]+XPCCoding' \
  "${public_test_directory}" \
  "${consumer_directory}"
then
  fail "The public API target and consumer fixture must not use @testable import XPCCoding."
fi

if grep -R -n -E '@_spi(\([^)]*\))?[[:space:]]+import[[:space:]]+XPCCoding' \
  "${public_test_directory}" \
  "${consumer_directory}/Sources"
then
  fail "The public API target and consumer fixture must not import XPCCoding SPI."
fi

swift test \
  --package-path "${repository_root}" \
  --filter PublicAPITests

scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/hdxl-xpc-public-api.XXXXXX")"
cleanup() {
  rm -rf -- "${scratch_directory}"
}
trap cleanup EXIT

swift run \
  --package-path "${consumer_directory}" \
  --scratch-path "${scratch_directory}" \
  XPCCodingPublicAPIConsumer

binary_directory="$(
  swift build \
    --package-path "${consumer_directory}" \
    --scratch-path "${scratch_directory}" \
    --show-bin-path
)"
module_directory="${binary_directory}/Modules"
target_triple="$(swift -print-target-info | jq -r '.target.triple')"

[[ -d "${module_directory}" ]] || fail \
  "SwiftPM did not produce the expected module directory at ${module_directory}."

expect_typecheck_failure() {
  local source_file="$1"
  local expectation="$2"
  shift 2

  local compiler_output
  if compiler_output="$(
    xcrun swiftc \
      -typecheck \
      -swift-version 6 \
      -target "${target_triple}" \
      -I "${module_directory}" \
      "${source_file}" \
      2>&1
  )"
  then
    fail "${expectation} unexpectedly compiled: ${source_file}"
  fi

  local primary_diagnostic="$1"
  local expected_diagnostic
  for expected_diagnostic in "$@"; do
    grep -F -q "${expected_diagnostic}" <<<"${compiler_output}" || {
      printf '%s\n' "${compiler_output}" >&2
      fail "${expectation} did not emit the expected diagnostic: ${expected_diagnostic}"
    }
  done

  printf 'Verified expected compile failure: %s (%s)\n' \
    "${expectation}" \
    "${primary_diagnostic}"
}

expect_typecheck_failure \
  "${consumer_directory}/CompileFailProbes/UnavailableStandardDefaults.swift" \
  "issue #30 standard/default visibility gap" \
  "'standard' is inaccessible due to 'internal' protection level" \
  "type 'XPCCodec.Configuration' has no member 'standard'" \
  "missing argument for parameter 'configuration' in call" \
  "type 'XPCCodec' has no member 'standard'"

expect_typecheck_failure \
  "${consumer_directory}/CompileFailProbes/InternalEncoder.swift" \
  "internal encoder module boundary" \
  "cannot find '_XPCEncoder' in scope"

expect_typecheck_failure \
  "${consumer_directory}/CompileFailProbes/MutableFacadesAreNotSendable.swift" \
  "mutable facade task confinement" \
  "type 'XPCEncoder' does not conform to the 'Sendable' protocol" \
  "type 'XPCDecoder' does not conform to the 'Sendable' protocol"

printf '%s\n' \
  "Verified plain-import tests, external consumer execution, expected issue #30 failures, mutable facade task confinement, and internal API rejection."
