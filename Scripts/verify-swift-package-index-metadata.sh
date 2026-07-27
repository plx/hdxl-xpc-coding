#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"
validator_directory="${repository_root}/Tools/SPIManifestValidator"
manifest_path="${repository_root}/.spi.yml"
package_description_file="$(mktemp)"
trap 'rm -f -- "${package_description_file}"' EXIT

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v swift >/dev/null || fail "swift is required to verify .spi.yml."
command -v jq >/dev/null || fail "jq is required to verify .spi.yml."
[[ -f "${manifest_path}" ]] || fail ".spi.yml is missing."
[[ -f "${validator_directory}/Package.resolved" ]] || fail \
  "Tools/SPIManifestValidator/Package.resolved is missing."

cd "${repository_root}"
swift package dump-package | jq -e . >"${package_description_file}"

swift run \
  --package-path "${validator_directory}" \
  --configuration release \
  --disable-automatic-resolution \
  SPIManifestValidator \
  "${manifest_path}" \
  "${package_description_file}" \
  "${repository_root}/README.md"
