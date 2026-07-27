#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/.." && pwd)"
integration_root="${repository_root}/IntegrationTests/XPCProcessBoundary"
scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/hdxl-xpc-integration.XXXXXX")"
build_scratch="${scratch_directory}/swiftpm"
client_bundle="${scratch_directory}/XPCCodingXPCIntegration.app"
service_bundle_name="com.plx.hdxl-xpc-coding.integration.service.xpc"
service_bundle="${client_bundle}/Contents/XPCServices/${service_bundle_name}"

cleanup() {
  rm -rf -- "${scratch_directory}"
}
trap cleanup EXIT

swift build \
  --package-path "${integration_root}" \
  --scratch-path "${build_scratch}" \
  --configuration release \
  -Xswiftc -warnings-as-errors

binary_directory="$(
  swift build \
    --package-path "${integration_root}" \
    --scratch-path "${build_scratch}" \
    --configuration release \
    --show-bin-path
)"

install -d \
  "${client_bundle}/Contents/MacOS" \
  "${service_bundle}/Contents/MacOS"
install -m 0644 \
  "${integration_root}/Resources/Client-Info.plist" \
  "${client_bundle}/Contents/Info.plist"
install -m 0644 \
  "${integration_root}/Resources/Service-Info.plist" \
  "${service_bundle}/Contents/Info.plist"
install -m 0755 \
  "${binary_directory}/XPCCodingXPCIntegrationClient" \
  "${client_bundle}/Contents/MacOS/XPCCodingXPCIntegrationClient"
install -m 0755 \
  "${binary_directory}/XPCCodingXPCIntegrationService" \
  "${service_bundle}/Contents/MacOS/XPCCodingXPCIntegrationService"

plutil -lint \
  "${client_bundle}/Contents/Info.plist" \
  "${service_bundle}/Contents/Info.plist"

codesign \
  --force \
  --sign - \
  --timestamp=none \
  "${service_bundle}"
codesign \
  --force \
  --sign - \
  --timestamp=none \
  "${client_bundle}"
codesign --verify --strict --verbose=2 "${service_bundle}"
codesign --verify --strict --verbose=2 "${client_bundle}"

for iteration in 1 2 3; do
  XPCCODING_XPC_INTEGRATION_ITERATION="${iteration}" \
    "${client_bundle}/Contents/MacOS/XPCCodingXPCIntegrationClient"
done

printf '%s\n' \
  "Completed three deterministic same-host XPC request/reply integration runs."
