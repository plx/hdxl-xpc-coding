#!/usr/bin/env bash

# Bounded deterministic fuzzing smoke campaign.
#
# Designed for every pull request: a fixed seed, a fixed case budget, and a firm
# wall-clock ceiling, so a green result means the same thing on every run. The
# unbounded exploration lives in Scripts/run-fuzzing-campaign.sh.

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"
fuzzing_root="${repository_root}/IntegrationTests/Fuzzing"
corpus_directory="${fuzzing_root}/Corpus"

seed="${XPCCODING_FUZZING_SEED:-0x5eed000000000001}"
generated_case_count="${XPCCODING_FUZZING_CASES:-192}"
mutated_case_count="${XPCCODING_FUZZING_MUTATIONS:-192}"
artifacts_directory="${XPCCODING_FUZZING_ARTIFACTS:-${repository_root}/.build/fuzzing/smoke}"

scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/hdxl-xpc-fuzzing-smoke.XXXXXX")"
cleanup() {
  rm -rf -- "${scratch_directory}"
}
trap cleanup EXIT

swift build \
  --package-path "${fuzzing_root}" \
  --scratch-path "${scratch_directory}/swiftpm" \
  --configuration release \
  -Xswiftc -warnings-as-errors

binary_directory="$(
  swift build \
    --package-path "${fuzzing_root}" \
    --scratch-path "${scratch_directory}/swiftpm" \
    --configuration release \
    --show-bin-path
)"
harness="${binary_directory}/XPCCodingFuzzing"

mkdir -p -- "${artifacts_directory}"

# 1. The checked-in corpus must still match its reviewed Swift inventory.
"${harness}" corpus verify --corpus "${corpus_directory}"

# 2. A fixed seed must generate identical cases across repeated runs.
"${harness}" determinism \
  --seed "${seed}" \
  --cases 64 \
  --repeats 3 \
  --execute 8

# 3. The wall-clock control must kill a deliberately hanging child and name its
#    seed. Without this, a broken timeout would report success forever.
"${harness}" verify-timeout \
  --corpus "${corpus_directory}" \
  --timeout-seconds 3

# 4. The footprint ceiling must kill a child, ahead of the wall clock. It is the
#    one bound no ordinary case ever reaches, so nothing else would notice it
#    silently failing.
"${harness}" verify-memory \
  --corpus "${corpus_directory}"

# 5. A failure must be detected, minimized, and persisted.
"${harness}" verify-minimizer \
  --corpus "${corpus_directory}" \
  --artifacts "${artifacts_directory}"

# 6. Every checked-in case plus a bounded generated and mutated population.
"${harness}" campaign \
  --smoke \
  --seed "${seed}" \
  --cases "${generated_case_count}" \
  --mutations "${mutated_case_count}" \
  --corpus "${corpus_directory}" \
  --artifacts "${artifacts_directory}"

printf '%s\n' \
  "Completed the bounded fuzzing smoke campaign; artifacts are in ${artifacts_directory}."
