#!/usr/bin/env bash

# XPCCoding release rehearsal.
#
# A reproducible clean-clone dry run of the release *mechanics*. It clones a
# candidate revision into a throwaway directory, verifies the supported
# toolchain, runs the source API stability gate and the proportionate
# build/test evidence, and captures the metadata, source-archive checksum, and
# release-note inputs a release needs.
#
# This rehearsal deliberately CANNOT publish anything. It creates no tag, no
# GitHub Release, and no Package Index submission, and it never touches the
# existing lightweight tags. It is not a production-readiness audit and does not
# render a GO/NO-GO decision; that is the separate gate defined in
# reference/PostRemediationProductionReadinessAudit.md. See RELEASING.md for how
# this rehearsal fits into the release process.
#
# Usage:
#   bash Scripts/release-rehearsal.sh [candidate-revision] [output-directory]
#
#   candidate-revision  Git revision to rehearse (default: HEAD). Must be
#                       committed; uncommitted working-tree changes are not
#                       part of a clean clone and are intentionally excluded.
#   output-directory    Where to write the rehearsal report and artifacts
#                       (default: a fresh mktemp directory). When supplied, it
#                       must already exist, be empty, and be outside the repo.
#
# The report uses literal Markdown backticks in printf format strings.
# shellcheck disable=SC2016

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repository_root="$(cd -- "${script_directory}/.." && pwd -P)"

candidate_revision="${1:-HEAD}"
output_directory="${2:-}"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '\n=== %s ===\n' "$*"
}

cd "${repository_root}"

command -v shasum >/dev/null || fail "shasum is required to checksum the source archive."
command -v awk >/dev/null || fail "awk is required to read the archive checksum."
command -v find >/dev/null || fail "find is required to validate the output directory."
# Checked up front: xcodebuild only fails once it is actually invoked, which is
# after the clone and would waste the expensive part of the rehearsal.
command -v xcodebuild >/dev/null || fail "xcodebuild is required; select the supported toolchain via DEVELOPER_DIR."

candidate_sha="$(git rev-parse --verify "${candidate_revision}^{commit}" 2>/dev/null)" \
  || fail "Candidate revision '${candidate_revision}' does not resolve to a commit."
candidate_tree="$(git rev-parse "${candidate_sha}^{tree}")"

if ! git diff --quiet || ! git diff --cached --quiet; then
  printf 'warning: %s\n' \
    "The working tree has uncommitted changes; the rehearsal clones committed candidate ${candidate_sha} and excludes them." >&2
fi

if [[ -z "${output_directory}" ]]; then
  temporary_parent="$(cd -- "${TMPDIR:-/tmp}" && pwd -P)" \
    || fail "Temporary directory parent ${TMPDIR:-/tmp} is unavailable."
  if [[ "${temporary_parent}" == "${repository_root}" || "${temporary_parent}" == "${repository_root}"/* ]]; then
    fail "Temporary directory parent ${temporary_parent} is inside the repository; pass an empty output directory outside ${repository_root}."
  fi
  output_directory="$(mktemp -d "${temporary_parent}/hdxl-xpc-release-rehearsal.XXXXXX")"
else
  [[ -d "${output_directory}" ]] \
    || fail "Explicit output directory ${output_directory} must already exist."
  [[ -z "$(find "${output_directory}" -mindepth 1 -maxdepth 1 -print -quit)" ]] \
    || fail "Output directory ${output_directory} is not empty; choose an empty destination."
fi

output_directory="$(cd -- "${output_directory}" && pwd -P)"

# The rehearsal writes a full clone and several artifacts into the output
# directory. Refusing an in-repository destination keeps it from dirtying the
# very working tree it warns about above. Apply this check to both explicit and
# TMPDIR-derived destinations.
if [[ "${output_directory}" == "${repository_root}" || "${output_directory}" == "${repository_root}"/* ]]; then
  fail "Output directory ${output_directory} is inside the repository; choose a destination outside ${repository_root}."
fi

clone_directory="${output_directory}/clean-clone"
report_file="${output_directory}/release-rehearsal-report.md"
metadata_log="${output_directory}/candidate-metadata.txt"
archive_file="${output_directory}/XPCCoding-${candidate_sha}.tar"

printf '%s\n' \
  "Release rehearsal for candidate ${candidate_sha}" \
  "Output directory: ${output_directory}"

# 1. Clean clone. `git clone` from the local repository materializes a pristine
#    working tree from committed history only; nothing in the developer's
#    checkout is reused, and the full history is present so the API baseline
#    revision resolves.
note "Clean clone of ${candidate_sha}"
git clone --no-local --quiet "file://${repository_root}" "${clone_directory}"
git -C "${clone_directory}" checkout --quiet --detach "${candidate_sha}"

# The clone must materialize exactly the reviewed tree; the report presents this
# hash as release-record evidence, so assert it rather than merely printing it.
cloned_tree="$(git -C "${clone_directory}" rev-parse 'HEAD^{tree}')"
[[ "${cloned_tree}" == "${candidate_tree}" ]] \
  || fail "Clean clone of ${candidate_sha} resolved to tree ${cloned_tree}, expected ${candidate_tree}."

# 2. Candidate metadata, recorded verbatim for the release record.
note "Recording candidate metadata"
{
  printf '# Candidate metadata\n\n'
  printf 'candidate revision request: %s\n' "${candidate_revision}"
  printf 'candidate SHA: %s\n' "${candidate_sha}"
  printf 'candidate tree: %s\n' "${candidate_tree}"
  printf '\n## git status --short\n'
  git -C "${clone_directory}" status --short || true
  printf '\n## git rev-parse HEAD\n'
  git -C "${clone_directory}" rev-parse HEAD
  printf '\n## git describe --tags --always --dirty\n'
  git -C "${clone_directory}" describe --tags --always --dirty || true
  printf '\n## swift --version\n'
  swift --version
  printf '\n## xcodebuild -version\n'
  xcodebuild -version
  printf '\n## uname -a\n'
  uname -a
} | tee "${metadata_log}"

run_in_clone() {
  note "$1"
  shift
  ( cd "${clone_directory}" && "$@" )
}

# 3. Proportionate evidence, all in the clean clone under the supported
#    toolchain. Each step is fail-closed.
run_in_clone "Verify the supported toolchain and manifest" \
  bash Scripts/verify-support-policy.sh
run_in_clone "Source API stability gate" \
  bash Scripts/verify-api-stability.sh
run_in_clone "Verify reviewed inlining annotations" \
  bash Scripts/verify-inlining-annotations.sh
run_in_clone "Build in debug with warnings as errors" \
  swift build -Xswiftc -warnings-as-errors
run_in_clone "Test in debug with warnings as errors" \
  swift test -Xswiftc -warnings-as-errors
run_in_clone "Build in release with warnings as errors" \
  swift build --configuration release -Xswiftc -warnings-as-errors
run_in_clone "Verify the external public API boundary" \
  bash Scripts/verify-public-api.sh

# 4. Reproducible source-archive checksum: a release-note input tied to the
#    exact candidate tree. `git archive` is deterministic for a fixed tree, and
#    hashing the uncompressed tar avoids gzip timestamp nondeterminism.
#
#    This checksum is rehearsal-internal. It is NOT comparable to the tarball
#    GitHub generates for a release, which is gzipped and carries a
#    `<name>-<version>/` path prefix. Use it to confirm that two rehearsals of
#    the same candidate agree, not to validate a GitHub download.
note "Source-archive checksum"
git -C "${clone_directory}" archive --format=tar "${candidate_sha}" >"${archive_file}"
archive_checksum="$(shasum -a 256 "${archive_file}" | awk '{print $1}')"
printf 'source archive: %s\nsha256: %s\n' "${archive_file}" "${archive_checksum}"

swift_version_line="$(swift --version 2>&1 | sed -n 's/.*Apple Swift version \([^ ]*\).*/\1/p')"
xcode_version_line="$(xcodebuild -version 2>&1 | tr '\n' ' ')"

# 5. Rehearsal report and release-note inputs. No tag or release is created.
note "Writing rehearsal report"
{
  printf '# XPCCoding release rehearsal\n\n'
  printf 'This is a clean-clone rehearsal of release mechanics. It publishes '
  printf 'nothing: no tag, no GitHub Release, no Package Index submission.\n\n'
  printf '## Candidate\n\n'
  printf -- '- candidate revision request: `%s`\n' "${candidate_revision}"
  printf -- '- candidate SHA: `%s`\n' "${candidate_sha}"
  printf -- '- candidate tree: `%s`\n' "${candidate_tree}"
  printf '\n## Toolchain\n\n'
  printf -- '- Apple Swift version: `%s`\n' "${swift_version_line:-unknown}"
  printf -- '- Xcode: `%s`\n' "${xcode_version_line}"
  printf -- '- host: `%s`\n' "$(uname -mrs)"
  printf '\n## Evidence executed in the clean clone\n\n'
  printf -- '- support-policy verification\n'
  printf -- '- source API stability gate (diagnose-api-breaking-changes vs pinned baseline)\n'
  printf -- '- reviewed inlining-annotation verification\n'
  printf -- '- debug build + test, release build (all `-warnings-as-errors`)\n'
  printf -- '- external public API boundary verification\n'
  printf '\nThis is the release-mechanics subset, not the full CI matrix: the\n'
  printf 'sanitizer, fuzzing, documentation, cross-platform-compile, and XPC\n'
  printf 'process-boundary lanes run in CI and are not repeated here.\n'
  printf '\n## Release-note inputs\n\n'
  printf -- '- source archive: `%s`\n' "$(basename "${archive_file}")"
  printf -- '- source archive SHA-256: `%s` (rehearsal-internal; uncompressed\n' "${archive_checksum}"
  printf -- '  `git archive` tar with no path prefix, so it does NOT match the\n'
  printf -- '  gzipped, prefixed tarball GitHub generates for a release)\n'
  printf -- '- dependencies: none (dependency-free package; no `Package.resolved` to pin)\n'
  printf '\n## Not performed (by design)\n\n'
  printf -- '- no annotated/signed tag created\n'
  printf -- '- no GitHub Release created\n'
  printf -- '- no Swift Package Index submission\n'
  printf -- '- existing lightweight tags 0.0.1/0.0.2/0.0.3 untouched\n'
  printf '\nProduction suitability is decided separately by the '
  printf 'post-remediation production-readiness audit, not by this rehearsal.\n'
} | tee "${report_file}"

note "Rehearsal complete"
printf '%s\n' \
  "Wrote rehearsal report to ${report_file}." \
  "This rehearsal created no tag and no release."
