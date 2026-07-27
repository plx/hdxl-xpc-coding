#!/usr/bin/env bash

set -euo pipefail

# Fails when any public XPCCoding declaration lacks a documentation comment.
#
# This is the repository's single public-documentation completeness gate. It
# reads the same public symbol graphs that DocC consumes, so its notion of
# "public declaration" is the compiler's rather than a source-text
# approximation: extension members, protocol requirements, default
# implementations, conformance witnesses such as `description`, type aliases,
# and members of extensions on standard-library types are all covered.
#
# The only pinned tooling inputs are the supported toolchain itself (see
# reference/SupportPolicy.md) and `jq`, which the repository already requires
# for Scripts/verify-public-api.sh.
#
# Usage:
#
#   verify-public-documentation.sh [<symbol-graph-directory>]
#
# With no argument the script emits its own public symbol graphs into a
# temporary directory. Scripts/generate-api-documentation.sh instead passes the
# symbol graphs it has already emitted, so the documentation job builds once.
#
# Exemption: a public symbol that carries no source location is synthesized by
# the compiler (for example, the `init(from:)` of a synthesized `Codable`
# conformance). No doc comment can be attached to such a declaration, so the
# gate exempts it and lists every exemption by name rather than dropping it
# silently.

readonly module_name="XPCCoding"

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v jq >/dev/null || fail "jq is required to inspect the public symbol graphs."

(($# <= 1)) || fail "usage: verify-public-documentation.sh [<symbol-graph-directory>]"

scratch_directory=""
cleanup() {
  if [[ -n "${scratch_directory}" ]]; then
    rm -rf -- "${scratch_directory}"
  fi
}
trap cleanup EXIT

if (($# == 1)); then
  symbol_graph_directory="$1"
  [[ -d "${symbol_graph_directory}" ]] || fail \
    "the supplied symbol-graph directory does not exist: ${symbol_graph_directory}"
else
  scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/hdxl-xpc-public-documentation.XXXXXX")"
  symbol_graph_directory="${scratch_directory}/symbol-graphs"
  mkdir -p -- "${symbol_graph_directory}"

  swift build \
    --package-path "${repository_root}" \
    --scratch-path "${scratch_directory}/swiftpm" \
    --target "${module_name}" \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir \
    -Xswiftc "${symbol_graph_directory}" \
    -Xswiftc -symbol-graph-minimum-access-level \
    -Xswiftc public
fi

[[ -f "${symbol_graph_directory}/${module_name}.symbols.json" ]] || fail \
  "the symbol-graph directory contains no ${module_name}.symbols.json."

# The module's own symbols live in <module>.symbols.json; the members it adds to
# types from other modules live in <module>@<other>.symbols.json. Both are part
# of the public surface a consumer can call, so both are gated.
shopt -s nullglob
symbol_graphs=("${symbol_graph_directory}/${module_name}".symbols.json \
  "${symbol_graph_directory}/${module_name}@"*.symbols.json)
shopt -u nullglob

# The jq program is deliberately single-quoted: `$public` and friends are jq
# variables, not shell expansions.
# shellcheck disable=SC2016
readonly report_program='
def documented:
  [(.docComment.lines // [])[] | select(.text | test("\\S"))] | length > 0;

def source_path:
  (.location.uri // "") | sub("^file://"; "");

[inputs.symbols[] | select(.accessLevel == "public" or .accessLevel == "open")]
  as $public
| ($public | map(select(has("location") | not))) as $synthesized
| ($public | map(select(has("location")))) as $declared
| ($declared | map(select(documented | not))) as $undocumented
| [
    "total\t\($public | length)",
    "declared\t\($declared | length)",
    "exempt\t\($synthesized | length)"
  ]
  + ($synthesized
     | sort_by(.pathComponents | join("."))
     | map("exempt-symbol\t\(.pathComponents | join("."))\t\(.kind.identifier)"))
  + ($undocumented
     | sort_by([source_path, .location.position.line])
     | map("undocumented\t\(source_path)\t\(.location.position.line + 1)\t\(.pathComponents | join("."))\t\(.kind.identifier)"))
| .[]
'

report="$(jq -n -r "${report_program}" "${symbol_graphs[@]}")" || fail \
  "could not read the public symbol graphs."

total_count="$(awk -F'\t' '$1 == "total" { print $2 }' <<<"${report}")"
declared_count="$(awk -F'\t' '$1 == "declared" { print $2 }' <<<"${report}")"
exempt_count="$(awk -F'\t' '$1 == "exempt" { print $2 }' <<<"${report}")"

if ((exempt_count > 0)); then
  printf 'Exempt (compiler-synthesized, cannot carry a doc comment): %s\n' "${exempt_count}"
  awk -F'\t' '$1 == "exempt-symbol" { printf "  %s (%s)\n", $2, $3 }' <<<"${report}"
fi

undocumented="$(awk -F'\t' '$1 == "undocumented"' <<<"${report}")"

if [[ -n "${undocumented}" ]]; then
  undocumented_count="$(wc -l <<<"${undocumented}" | tr -d '[:space:]')"
  printf 'error: %s public declaration(s) are undocumented:\n' "${undocumented_count}" >&2
  awk -F'\t' -v root="${repository_root}/" \
    '{ path = $2; sub("^" root, "", path); printf "  %s:%s: %s (%s)\n", path, $3, $4, $5 }' \
    <<<"${undocumented}" >&2
  fail "every public XPCCoding declaration must carry a documentation comment."
fi

printf '%s\n' \
  "Verified that all ${declared_count} declared public ${module_name} symbols are documented (${total_count} public symbols total)."
