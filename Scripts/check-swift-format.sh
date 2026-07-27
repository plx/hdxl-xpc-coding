#!/usr/bin/env bash

set -euo pipefail

script_directory="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
  pwd
)"
readonly script_directory

repository_root="$(cd -- "${script_directory}/.." && pwd)"
readonly repository_root

bash "${script_directory}/verify-swift-format-version.sh"

exec xcrun swift-format lint \
  --configuration "${repository_root}/.swift-format" \
  --strict \
  --recursive \
  --parallel \
  "${repository_root}/Sources" \
  "${repository_root}/Tests"
