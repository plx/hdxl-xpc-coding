#!/usr/bin/env bash

set -euo pipefail

scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/hdxl-xpc-hostile-input.XXXXXX")"
cleanup() {
  rm -rf -- "${scratch_directory}"
}
trap cleanup EXIT

swift test \
  --scratch-path "${scratch_directory}/swiftpm" \
  -Xswiftc -warnings-as-errors \
  --filter \
  'UnalignedNumericDecodingTests|DecoderResourceLimitTests|ReferencingEncoderStateTests|UnsafePointerCountValidationTests'
