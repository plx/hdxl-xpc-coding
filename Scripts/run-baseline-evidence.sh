#!/usr/bin/env bash

# Regression-first evidence for the production-readiness audit.
#
# Builds one set of probe sources twice — against the pinned audit revision and
# against the working tree — and requires each build to produce the outcomes its
# revision is supposed to produce. The probe drives only public API that existed
# at the audit revision, so the sources never change between the two halves;
# only the library behind them does.
#
# Every check runs in a bounded child process, because three of the historical
# defects end the process at the audit revision.

set -euo pipefail

readonly baseline_revision="813c52e0aab258a185aa6d5e8c1a241d419ce589"
readonly baseline_tree_hash="aaaec2f0c1d3057e72eb512938afec6f98fa365c"

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"
probe_root="${repository_root}/IntegrationTests/BaselineProbe"

timeout_seconds="${XPCCODING_BASELINE_TIMEOUT_SECONDS:-15}"
cpu_seconds="${XPCCODING_BASELINE_CPU_SECONDS:-8}"
memory_mebibytes="${XPCCODING_BASELINE_MEMORY_MIB:-1024}"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/hdxl-xpc-baseline.XXXXXX")"
cleanup() {
  rm -rf -- "${scratch_directory}"
}
trap cleanup EXIT

# Both halves build in debug, and the configuration is load-bearing rather than
# incidental. One historical defect is an unaligned `load(as:)`: undefined
# behavior that an optimized arm64 build may complete silently, and that the
# checked build turns into the observable trap the audit recorded. Building both
# halves the same way also keeps the comparison honest, since the only thing
# that differs between them is the library revision.
probe_binary() {
  local package_path="$1"
  local build_scratch="$2"
  shift 2
  swift build \
    --package-path "${package_path}" \
    --scratch-path "${build_scratch}" \
    --configuration debug \
    "$@" \
    >&2
  printf '%s/XPCCodingBaselineProbe\n' "$(
    swift build \
      --package-path "${package_path}" \
      --scratch-path "${build_scratch}" \
      --configuration debug \
      "$@" \
      --show-bin-path
  )"
}

# 1. The working-tree half. This build carries warnings-as-errors because the
#    probe sources are ours; the audit-revision half below does not, because its
#    library is a historical artifact and is not ours to keep warning-free.
printf '%s\n' \
  "=== Working tree: every historical defect must be absent ==="
current_probe="$(
  probe_binary \
    "${probe_root}" \
    "${scratch_directory}/current" \
    -Xswiftc -warnings-as-errors
)"
"${current_probe}" evidence \
  --expect current \
  --revision-label "the working tree at $(git -C "${repository_root}" rev-parse --short HEAD)" \
  --timeout-seconds "${timeout_seconds}" \
  --cpu-seconds "${cpu_seconds}" \
  --memory-mib "${memory_mebibytes}"

# 2. Materialize the audit revision. `git archive` writes a pristine tree out of
#    the object database, so nothing in the checkout is switched, stashed, or
#    otherwise disturbed, and a shallow clone fails loudly instead of silently
#    testing the wrong source.
git -C "${repository_root}" rev-parse --quiet --verify \
  "${baseline_revision}^{commit}" >/dev/null \
  || fail "Revision ${baseline_revision} is unavailable; fetch the full history."

resolved_tree="$(
  git -C "${repository_root}" rev-parse "${baseline_revision}^{tree}"
)"
[[ "${resolved_tree}" == "${baseline_tree_hash}" ]] \
  || fail "Revision ${baseline_revision} resolved to tree ${resolved_tree}, expected ${baseline_tree_hash}."

baseline_library="${scratch_directory}/library"
baseline_probe_root="${baseline_library}/IntegrationTests/BaselineProbe"
mkdir -p -- "${baseline_probe_root}"
git -C "${repository_root}" archive --format=tar "${baseline_revision}" \
  | tar -x -C "${baseline_library}"

# The probe package resolves its dependency at `../..`, so a copy placed here
# builds against the extracted revision using the same manifest, unedited.
cp -- "${probe_root}/Package.swift" "${baseline_probe_root}/Package.swift"
cp -R -- "${probe_root}/Sources" "${baseline_probe_root}/Sources"

printf '\n%s\n' \
  "=== Audit revision ${baseline_revision}: every historical defect must be present ==="
baseline_probe="$(
  probe_binary \
    "${baseline_probe_root}" \
    "${scratch_directory}/baseline"
)"
"${baseline_probe}" evidence \
  --expect baseline \
  --revision-label "the audit revision ${baseline_revision}" \
  --timeout-seconds "${timeout_seconds}" \
  --cpu-seconds "${cpu_seconds}" \
  --memory-mib "${memory_mebibytes}"

printf '\n%s\n' \
  "Verified regression-first evidence: every checked defect reproduces at ${baseline_revision} and none reproduces in the working tree."
