#!/usr/bin/env bash

# Runs the complete debug suite with SwiftPM coverage instrumentation under the
# zero-known-issue policy, retains the raw llvm-cov report, and enforces the
# reviewed XPCCoding source-coverage baseline.

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

(($# == 1)) || fail "usage: ${0##*/} <output-directory>"

output_directory="$1"
[[ -n "${output_directory}" ]] || fail "the output directory must not be empty"
mkdir -p -- "${output_directory}"

bash "${script_directory}/verify-support-policy.sh"
bash "${script_directory}/verify-source-coverage.sh" self-test

test_log="${output_directory}/coverage-tests.log"
set +e
set -o pipefail
bash "${script_directory}/run-tests-with-zero-known-issues.sh" coverage \
  2>&1 | tee "${test_log}"
test_status=${PIPESTATUS[0]}
set -e

((test_status == 0)) || exit "${test_status}"

coverage_path="$(cd -- "${repository_root}" && swift test --show-codecov-path)"
[[ -f "${coverage_path}" ]] || fail "SwiftPM did not produce a coverage JSON report"

raw_report="${output_directory}/llvm-cov.json"
summary_report="${output_directory}/coverage-summary.json"
policy_log="${output_directory}/coverage-policy.log"

cp -- "${coverage_path}" "${raw_report}"

set +e
set -o pipefail
bash "${script_directory}/verify-source-coverage.sh" \
  verify \
  "${raw_report}" \
  "${summary_report}" \
  2>&1 | tee "${policy_log}"
policy_status=${PIPESTATUS[0]}
set -e

((policy_status == 0)) || exit "${policy_status}"

printf 'Retained source-coverage reports in %s.\n' "${output_directory}"
