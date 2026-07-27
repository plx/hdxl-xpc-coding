#!/usr/bin/env bash

# Source API stability gate for XPCCoding.
#
# Diffs the working tree's public API against the pinned hardened baseline in
# `Scripts/api-baseline.env` using SwiftPM's api-digester:
#
#   swift package diagnose-api-breaking-changes <baseline> --products XPCCoding
#
# The tool exits nonzero when it detects a breaking change, so this script is
# fail-closed by construction: an unrecorded public API break fails CI. A
# deliberate pre-1.0 break is recorded by advancing the baseline in the same
# change (see reference/ApiStabilityPolicy.md); that makes the diff clean again
# and keeps every break reviewed.
#
# The baseline revision must be resolvable from the local object database, which
# a shallow clone does not provide. CI checks out with fetch-depth 0.

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"
baseline_file="${script_directory}/api-baseline.env"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[[ -f "${baseline_file}" ]] || fail "Missing API baseline file: ${baseline_file}"

# The sourced path is computed from BASH_SOURCE; ShellCheck cannot resolve that
# runtime absolute path even with a source annotation.
# shellcheck disable=SC1090,SC1091
. "${baseline_file}"

: "${XPCCODING_BASELINE_REVISION:?api-baseline.env must set XPCCODING_BASELINE_REVISION}"
: "${XPCCODING_BASELINE_TREE:?api-baseline.env must set XPCCODING_BASELINE_TREE}"
: "${XPCCODING_BASELINE_PRODUCT:?api-baseline.env must set XPCCODING_BASELINE_PRODUCT}"

cd "${repository_root}"

# The baseline is a commit and its tree must be exactly what was reviewed. This
# rejects a mistyped, rewritten, or repointed pin before the digester runs.
git rev-parse --quiet --verify "${XPCCODING_BASELINE_REVISION}^{commit}" >/dev/null \
  || fail "Baseline revision ${XPCCODING_BASELINE_REVISION} is unavailable; fetch the full history (fetch-depth 0)."

resolved_tree="$(git rev-parse "${XPCCODING_BASELINE_REVISION}^{tree}")"
[[ "${resolved_tree}" == "${XPCCODING_BASELINE_TREE}" ]] \
  || fail "Baseline revision ${XPCCODING_BASELINE_REVISION} resolved to tree ${resolved_tree}, expected ${XPCCODING_BASELINE_TREE}."

printf '%s\n' \
  "Diffing the working tree's public API for product ${XPCCODING_BASELINE_PRODUCT} against baseline ${XPCCODING_BASELINE_REVISION} (tree ${XPCCODING_BASELINE_TREE})."

if swift package diagnose-api-breaking-changes \
  "${XPCCODING_BASELINE_REVISION}" \
  --products "${XPCCODING_BASELINE_PRODUCT}"
then
  printf '%s\n' \
    "Verified source API stability: no breaking change relative to the pinned hardened baseline."
else
  # `status=$?` must stay the first statement in this branch: any command before
  # it would clobber the digester's exit status.
  status=$?
  printf 'error: %s\n' \
    "The source API stability gate failed (exit ${status}). If the digester reported a public API break and it is intentional, record it in CHANGELOG.md and advance the baseline per reference/ApiStabilityPolicy.md; if the break is unintentional, revert it. A nonzero exit with no reported break means the gate itself failed to run (build, toolchain, or baseline-checkout failure) and must be fixed before this result is trusted." >&2
  exit "${status}"
fi
