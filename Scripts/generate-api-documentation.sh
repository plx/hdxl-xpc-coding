#!/usr/bin/env bash

set -euo pipefail

# Generates the XPCCoding API documentation archive into a caller-supplied
# output directory.
#
# The only pinned tooling input is the supported toolchain itself (see
# reference/SupportPolicy.md): SwiftPM emits the module's public symbol graphs
# and that toolchain's DocC compiles them. There is no package dependency, no
# separately-versioned plugin, and nothing to resolve, so a clean clone
# reproduces this output offline.
#
# Every DocC warning, including an unresolved symbol link, fails the run, and
# Scripts/verify-public-documentation.sh fails the run when any public
# declaration in those symbol graphs lacks a documentation comment. That gate
# reuses the symbol graphs emitted here, so completeness and strict DocC are
# enforced by one build rather than by two drifting recipes.

readonly module_name="XPCCoding"
readonly bundle_identifier="com.plx.hdxl-xpc-coding.XPCCoding"

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

(($# == 1)) || fail "usage: generate-api-documentation.sh <output-directory>"

output_directory="$1"
documentation_archive="${output_directory}/${module_name}.doccarchive"
scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/hdxl-xpc-documentation.XXXXXX")"
symbol_graph_directory="${scratch_directory}/symbol-graphs"

cleanup() {
  rm -rf -- "${scratch_directory}"
}
trap cleanup EXIT

mkdir -p -- "${output_directory}" "${symbol_graph_directory}"
rm -rf -- "${documentation_archive}"

swift build \
  --package-path "${repository_root}" \
  --scratch-path "${scratch_directory}/swiftpm" \
  --target "${module_name}" \
  -Xswiftc -emit-symbol-graph \
  -Xswiftc -emit-symbol-graph-dir \
  -Xswiftc "${symbol_graph_directory}" \
  -Xswiftc -symbol-graph-minimum-access-level \
  -Xswiftc public

[[ -f "${symbol_graph_directory}/${module_name}.symbols.json" ]] || fail \
  "the build did not emit a symbol graph for ${module_name}."

bash "${script_directory}/verify-public-documentation.sh" "${symbol_graph_directory}"

xcrun docc convert \
  --additional-symbol-graph-dir "${symbol_graph_directory}" \
  --output-path "${documentation_archive}" \
  --fallback-display-name "${module_name}" \
  --fallback-bundle-identifier "${bundle_identifier}" \
  --warnings-as-errors

[[ -f "${documentation_archive}/data/documentation/xpccoding.json" ]] || fail \
  "the documentation archive does not contain the ${module_name} module."

printf '%s\n' \
  "Generated the ${module_name} documentation archive at ${documentation_archive}."
