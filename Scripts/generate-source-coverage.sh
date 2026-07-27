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

run_and_tee() {
  local log_file="$1"
  shift

  local pipeline_status
  set +e
  "$@" 2>&1 | tee "${log_file}"
  pipeline_status=$?
  set -e

  return "${pipeline_status}"
}

verify_pipeline_status_propagation() {
  local scratch_directory
  scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/hdxl-xpc-coverage-pipeline.XXXXXX")"

  local passing_log="${scratch_directory}/passing.log"
  run_and_tee "${passing_log}" printf '%s\n' "coverage transcript control" >/dev/null
  if ! grep -Fxq "coverage transcript control" "${passing_log}"; then
    rm -rf -- "${scratch_directory}"
    fail "coverage transcript positive control did not retain output"
  fi

  if run_and_tee "${scratch_directory}" printf '%s\n' "must not pass" >/dev/null 2>&1; then
    rm -rf -- "${scratch_directory}"
    fail "coverage transcript write failure unexpectedly passed"
  fi

  rm -rf -- "${scratch_directory}"
}

(($# == 1)) || fail "usage: ${0##*/} <output-directory>"

output_directory="$1"
[[ -n "${output_directory}" ]] || fail "the output directory must not be empty"
mkdir -p -- "${output_directory}"

verify_pipeline_status_propagation
bash "${script_directory}/verify-support-policy.sh"
bash "${script_directory}/verify-source-coverage.sh" self-test

test_log="${output_directory}/coverage-tests.log"
run_and_tee \
  "${test_log}" \
  bash "${script_directory}/run-tests-with-zero-known-issues.sh" coverage \
  || exit "$?"

coverage_path="$(cd -- "${repository_root}" && swift test --show-codecov-path)"
[[ -f "${coverage_path}" ]] || fail "SwiftPM did not produce a coverage JSON report"

raw_report="${output_directory}/llvm-cov.json"
summary_report="${output_directory}/coverage-summary.json"
policy_log="${output_directory}/coverage-policy.log"

cp -- "${coverage_path}" "${raw_report}"

run_and_tee \
  "${policy_log}" \
  bash "${script_directory}/verify-source-coverage.sh" \
  verify \
  "${raw_report}" \
  "${summary_report}" \
  || exit "$?"

printf 'Retained source-coverage reports in %s.\n' "${output_directory}"
