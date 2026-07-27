#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"
allowlist_path="${repository_root}/.inlining-annotations.allowlist"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[[ -f "${allowlist_path}" ]] || fail "missing allowlist: ${allowlist_path}"

scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/hdxl-xpc-inlining.XXXXXX")"
cleanup() {
  rm -rf -- "${scratch_directory}"
}
trap cleanup EXIT

actual_path="${scratch_directory}/actual"
allowed_path="${scratch_directory}/allowed"
unreviewed_path="${scratch_directory}/unreviewed"
stale_path="${scratch_directory}/stale"

(
  cd "${repository_root}"
  find Sources/XPCCoding -type f -name '*.swift' -print0 \
    | LC_ALL=C sort -z \
    | while IFS= read -r -d '' source_path; do
        awk '
          /^[[:space:]]*@/ {
            remainder = $0
            while (match(remainder, /@(inlinable|usableFromInline|inline\(__always\))/)) {
              print FILENAME ":" FNR ":" substr(remainder, RSTART, RLENGTH)
              remainder = substr(remainder, RSTART + RLENGTH)
            }
          }
        ' "${source_path}"
      done
) | LC_ALL=C sort -u >"${actual_path}"

awk -F '\t' '
  /^[[:space:]]*($|#)/ {
    next
  }

  NF != 2 || $1 == "" || $2 !~ /[^[:space:]]/ {
    printf "error: malformed allowlist entry on line %d; expected location<TAB>rationale\n", NR > "/dev/stderr"
    invalid = 1
    next
  }

  $1 !~ /^Sources\/XPCCoding\/.*\.swift:[1-9][0-9]*:@(inlinable|usableFromInline|inline\(__always\))$/ {
    printf "error: unsupported allowlist location on line %d: %s\n", NR, $1 > "/dev/stderr"
    invalid = 1
    next
  }

  {
    print $1
  }

  END {
    if (invalid) {
      exit 1
    }
  }
' "${allowlist_path}" | LC_ALL=C sort >"${allowed_path}"

if [[ -n "$(uniq -d "${allowed_path}")" ]]; then
  uniq -d "${allowed_path}" >&2
  fail "duplicate inlining-annotation allowlist entries"
fi

comm -23 "${actual_path}" "${allowed_path}" >"${unreviewed_path}"
comm -13 "${actual_path}" "${allowed_path}" >"${stale_path}"

if [[ -s "${unreviewed_path}" ]]; then
  printf '%s\n' "Unreviewed inlining annotations:" >&2
  sed 's/^/  /' "${unreviewed_path}" >&2
fi

if [[ -s "${stale_path}" ]]; then
  printf '%s\n' "Stale inlining-annotation allowlist entries:" >&2
  sed 's/^/  /' "${stale_path}" >&2
fi

if [[ -s "${unreviewed_path}" || -s "${stale_path}" ]]; then
  fail "inlining annotations and their measured-rationale allowlist differ"
fi

annotation_count="$(wc -l <"${actual_path}" | tr -d '[:space:]')"
printf 'Verified %s reviewed inlining annotation(s).\n' "${annotation_count}"
