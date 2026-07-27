#!/usr/bin/env bash

# Long deterministic fuzzing campaign with durable artifacts.
#
# Intended for the scheduled and manually dispatched CI jobs. It explores far
# more of the generated and mutated space than the pull-request smoke campaign,
# and every finding it reports remains replayable from its persisted descriptor.

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"
fuzzing_root="${repository_root}/IntegrationTests/Fuzzing"
corpus_directory="${fuzzing_root}/Corpus"

# An unset seed means "explore new ground"; the harness prints and records the
# seed it chose, so any finding stays reproducible.
seed="${XPCCODING_FUZZING_SEED:-}"
duration_seconds="${XPCCODING_FUZZING_DURATION_SECONDS:-900}"
generated_case_count="${XPCCODING_FUZZING_CASES:-1024}"
mutated_case_count="${XPCCODING_FUZZING_MUTATIONS:-1024}"
timeout_seconds="${XPCCODING_FUZZING_TIMEOUT_SECONDS:-20}"
cpu_seconds="${XPCCODING_FUZZING_CPU_SECONDS:-10}"
memory_mebibytes="${XPCCODING_FUZZING_MEMORY_MIB:-1024}"
artifacts_directory="${XPCCODING_FUZZING_ARTIFACTS:-${repository_root}/.build/fuzzing/campaign}"

scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/hdxl-xpc-fuzzing-campaign.XXXXXX")"
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

"${harness}" corpus verify --corpus "${corpus_directory}"
"${harness}" verify-timeout \
  --corpus "${corpus_directory}" \
  --timeout-seconds 3
"${harness}" verify-memory \
  --corpus "${corpus_directory}"
"${harness}" verify-minimizer \
  --corpus "${corpus_directory}" \
  --artifacts "${artifacts_directory}"

campaign_arguments=(
  campaign
  --cases "${generated_case_count}"
  --mutations "${mutated_case_count}"
  --duration-seconds "${duration_seconds}"
  --timeout-seconds "${timeout_seconds}"
  --cpu-seconds "${cpu_seconds}"
  --memory-mib "${memory_mebibytes}"
  --corpus "${corpus_directory}"
  --artifacts "${artifacts_directory}"
)
if [[ -n "${seed}" ]]; then
  campaign_arguments+=(--seed "${seed}")
fi

"${harness}" "${campaign_arguments[@]}"

printf '%s\n' \
  "Completed the long fuzzing campaign; artifacts are in ${artifacts_directory}."
