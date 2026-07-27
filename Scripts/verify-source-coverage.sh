#!/usr/bin/env bash

# Aggregates llvm-cov's SwiftPM JSON report over production XPCCoding sources
# and rejects a line, region, or function ratio below the reviewed baseline.

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"
default_policy_file="${script_directory}/source-coverage-policy.json"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

verify_report() {
  local coverage_file="$1"
  local summary_file="$2"
  local policy_file="${XPCCODING_COVERAGE_POLICY_FILE:-${default_policy_file}}"

  [[ -f "${coverage_file}" ]] || fail "coverage report not found: ${coverage_file}"
  [[ -f "${policy_file}" ]] || fail "coverage policy not found: ${policy_file}"

  local scope
  scope="$(jq -er '.scope | select(type == "string" and length > 0)' "${policy_file}")" \
    || fail "coverage policy must define a nonempty scope"
  local scope_prefix="${repository_root}/${scope}/"

  local metrics
  metrics="$(
    jq -e \
      --arg scope_prefix "${scope_prefix}" \
      '
        [
          .data[]?.files[]?
          | select(.filename | startswith($scope_prefix))
          | .summary
        ] as $summaries
        | if ($summaries | length) == 0 then
            error("coverage report contains no files in the configured source scope")
          else
            reduce $summaries[] as $summary (
              {
                "lines": {"count": 0, "covered": 0},
                "regions": {"count": 0, "covered": 0},
                "functions": {"count": 0, "covered": 0}
              };
              .lines.count += $summary.lines.count
              | .lines.covered += $summary.lines.covered
              | .regions.count += $summary.regions.count
              | .regions.covered += $summary.regions.covered
              | .functions.count += $summary.functions.count
              | .functions.covered += $summary.functions.covered
            )
          end
        | with_entries(
            .value.percent = (
              if .value.count == 0 then 0
              else (.value.covered * 100 / .value.count)
              end
            )
          )
      ' \
      "${coverage_file}"
  )" || fail "could not aggregate XPCCoding source coverage"

  mkdir -p -- "$(dirname -- "${summary_file}")"
  local candidate_revision
  local candidate_dirty
  candidate_revision="$(git -C "${repository_root}" rev-parse HEAD)"
  if [[ -n "$(git -C "${repository_root}" status --porcelain --untracked-files=no)" ]]; then
    candidate_dirty=true
  else
    candidate_dirty=false
  fi

  jq -n \
    --arg repository "https://github.com/plx/hdxl-xpc-coding" \
    --arg revision "${candidate_revision}" \
    --argjson dirty "${candidate_dirty}" \
    --argjson metrics "${metrics}" \
    --slurpfile policy "${policy_file}" \
    '{
      "schemaVersion": 1,
      "repository": $repository,
      "candidate": {
        "revision": $revision,
        "dirty": $dirty
      },
      "policy": $policy[0],
      "metrics": $metrics
    }' >"${summary_file}"

  local status=0
  local metric
  for metric in lines regions functions; do
    local actual_count
    local actual_covered
    local baseline_count
    local baseline_covered
    local actual_percent
    local baseline_percent

    actual_count="$(jq -er --arg metric "${metric}" '.[$metric].count' <<<"${metrics}")"
    actual_covered="$(jq -er --arg metric "${metric}" '.[$metric].covered' <<<"${metrics}")"
    baseline_count="$(
      jq -er \
        --arg metric "${metric}" \
        '.baseline.metrics[$metric].count | select(type == "number" and . > 0)' \
        "${policy_file}"
    )" || fail "coverage policy has no valid ${metric} baseline count"
    baseline_covered="$(
      jq -er \
        --arg metric "${metric}" \
        '.baseline.metrics[$metric].covered | select(type == "number" and . >= 0)' \
        "${policy_file}"
    )" || fail "coverage policy has no valid ${metric} baseline covered count"

    if ((actual_count <= 0 || actual_covered < 0 || actual_covered > actual_count)); then
      fail "coverage report has invalid ${metric} counts"
    fi
    if ((baseline_covered > baseline_count)); then
      fail "coverage policy has invalid ${metric} counts"
    fi

    actual_percent="$(jq -r --arg metric "${metric}" '.[$metric].percent' <<<"${metrics}")"
    baseline_percent="$(
      jq -nr \
        --argjson covered "${baseline_covered}" \
        --argjson count "${baseline_count}" \
        '$covered * 100 / $count'
    )"

    printf '%-9s %d/%d (%0.3f%%); baseline %d/%d (%0.3f%%)\n' \
      "${metric}" \
      "${actual_covered}" \
      "${actual_count}" \
      "${actual_percent}" \
      "${baseline_covered}" \
      "${baseline_count}" \
      "${baseline_percent}"

    if ((actual_covered * baseline_count < baseline_covered * actual_count)); then
      printf 'error: %s coverage regressed below the reviewed baseline ratio.\n' \
        "${metric}" \
        >&2
      status=1
    fi
  done

  ((status == 0)) || return "${status}"
  printf 'Verified XPCCoding source coverage against %s.\n' "${policy_file}"
}

run_self_test() {
  local scratch_directory
  scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/hdxl-xpc-coverage-policy.XXXXXX")"
  cleanup_self_test() {
    rm -rf -- "${scratch_directory}"
  }
  trap cleanup_self_test RETURN

  local synthetic_coverage="${scratch_directory}/coverage.json"
  jq -n \
    --arg filename "${repository_root}/Sources/XPCCoding/Synthetic.swift" \
    '{
      "data": [{
        "files": [{
          "filename": $filename,
          "summary": {
            "lines": {"count": 10, "covered": 9},
            "regions": {"count": 8, "covered": 7},
            "functions": {"count": 6, "covered": 5}
          }
        }]
      }]
    }' >"${synthetic_coverage}"

  local passing_policy="${scratch_directory}/passing-policy.json"
  jq -n \
    '{
      "scope": "Sources/XPCCoding",
      "baseline": {
        "metrics": {
          "lines": {"count": 10, "covered": 9},
          "regions": {"count": 8, "covered": 7},
          "functions": {"count": 6, "covered": 5}
        }
      }
    }' >"${passing_policy}"

  XPCCODING_COVERAGE_POLICY_FILE="${passing_policy}" \
    verify_report "${synthetic_coverage}" "${scratch_directory}/passing-summary.json" \
    >/dev/null \
    || fail "coverage policy positive control failed"

  local strict_policy="${scratch_directory}/strict-policy.json"
  jq \
    '.baseline.metrics.lines = {"count": 10, "covered": 10}' \
    "${passing_policy}" >"${strict_policy}"

  if XPCCODING_COVERAGE_POLICY_FILE="${strict_policy}" \
    bash "${script_directory}/verify-source-coverage.sh" \
    verify \
    "${synthetic_coverage}" \
    "${scratch_directory}/failing-summary.json" \
    >/dev/null 2>&1
  then
    fail "coverage policy negative control unexpectedly passed"
  fi

  local out_of_scope_coverage="${scratch_directory}/out-of-scope.json"
  jq \
    '.data[0].files[0].filename = "/tmp/Tests/Synthetic.swift"' \
    "${synthetic_coverage}" >"${out_of_scope_coverage}"

  if XPCCODING_COVERAGE_POLICY_FILE="${passing_policy}" \
    bash "${script_directory}/verify-source-coverage.sh" \
    verify \
    "${out_of_scope_coverage}" \
    "${scratch_directory}/empty-summary.json" \
    >/dev/null 2>&1
  then
    fail "out-of-scope coverage negative control unexpectedly passed"
  fi

  printf 'All source-coverage policy controls behaved as expected.\n'
}

command -v jq >/dev/null || fail "jq is required to verify source coverage"

case "${1:-}" in
  verify)
    (($# == 3)) || fail "usage: ${0##*/} verify <coverage-json> <summary-json>"
    verify_report "$2" "$3"
    ;;
  self-test)
    (($# == 1)) || fail "usage: ${0##*/} self-test"
    run_self_test
    ;;
  *)
    fail "usage: ${0##*/} {verify <coverage-json> <summary-json>|self-test}"
    ;;
esac
