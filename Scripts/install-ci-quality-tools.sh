#!/usr/bin/env bash

# Installs the non-Xcode command-line tools used by the composite CI quality
# gate. Each release archive is immutable and checked against its published
# SHA-256 digest before any executable is installed.

set -euo pipefail

readonly just_version="1.51.0"
readonly just_sha256="61e3f1b8a545ff064b091eab4b6e14f8cc743ff15549be293b1e92f5b1467002"
readonly ripgrep_version="15.1.0"
readonly ripgrep_sha256="378e973289176ca0c6054054ee7f631a065874a352bf43f0fa60ef079b6ba715"
readonly swiftlint_version="0.65.0"
readonly swiftlint_sha256="d6cb0aa7a2f5f1ef306fc9e37bcb54dc9a26facc8f7784ac0c3dd3eccf5c6ba6"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

(($# == 1)) || fail "usage: ${0##*/} <installation-directory>"

installation_directory="$1"
[[ -n "${installation_directory}" ]] || fail "the installation directory must not be empty"

command -v curl >/dev/null || fail "curl is required to install CI quality tools"
command -v shasum >/dev/null || fail "shasum is required to verify CI quality tools"
command -v tar >/dev/null || fail "tar is required to unpack CI quality tools"
command -v unzip >/dev/null || fail "unzip is required to unpack SwiftLint"

[[ "$(uname -m)" == "arm64" ]] || fail "the pinned quality-tool archives require arm64"

scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/hdxl-xpc-quality-tools.XXXXXX")"
cleanup() {
  rm -rf -- "${scratch_directory}"
}
trap cleanup EXIT

download_and_verify() {
  local url="$1"
  local sha256="$2"
  local destination="$3"

  curl \
    --proto '=https' \
    --tlsv1.2 \
    --fail \
    --location \
    --retry 3 \
    --output "${destination}" \
    "${url}"

  printf '%s  %s\n' "${sha256}" "${destination}" | shasum -a 256 --check
}

just_archive="${scratch_directory}/just.tar.gz"
download_and_verify \
  "https://github.com/casey/just/releases/download/${just_version}/just-${just_version}-aarch64-apple-darwin.tar.gz" \
  "${just_sha256}" \
  "${just_archive}"
mkdir -p -- "${scratch_directory}/just"
tar -xzf "${just_archive}" -C "${scratch_directory}/just"

ripgrep_archive="${scratch_directory}/ripgrep.tar.gz"
download_and_verify \
  "https://github.com/BurntSushi/ripgrep/releases/download/${ripgrep_version}/ripgrep-${ripgrep_version}-aarch64-apple-darwin.tar.gz" \
  "${ripgrep_sha256}" \
  "${ripgrep_archive}"
mkdir -p -- "${scratch_directory}/ripgrep"
tar -xzf "${ripgrep_archive}" -C "${scratch_directory}/ripgrep"

swiftlint_archive="${scratch_directory}/swiftlint.zip"
download_and_verify \
  "https://github.com/realm/SwiftLint/releases/download/${swiftlint_version}/portable_swiftlint.zip" \
  "${swiftlint_sha256}" \
  "${swiftlint_archive}"
mkdir -p -- "${scratch_directory}/swiftlint"
unzip -q "${swiftlint_archive}" -d "${scratch_directory}/swiftlint"

just_binary="$(find "${scratch_directory}/just" -type f -name just -print -quit)"
ripgrep_binary="$(find "${scratch_directory}/ripgrep" -type f -name rg -print -quit)"
swiftlint_binary="$(find "${scratch_directory}/swiftlint" -type f -name swiftlint -print -quit)"

[[ -n "${just_binary}" ]] || fail "the just archive did not contain the just executable"
[[ -n "${ripgrep_binary}" ]] || fail "the ripgrep archive did not contain the rg executable"
[[ -n "${swiftlint_binary}" ]] || fail "the SwiftLint archive did not contain the swiftlint executable"

mkdir -p -- "${installation_directory}"
install -m 0755 "${just_binary}" "${installation_directory}/just"
install -m 0755 "${ripgrep_binary}" "${installation_directory}/rg"
install -m 0755 "${swiftlint_binary}" "${installation_directory}/swiftlint"

actual_just_version="$("${installation_directory}/just" --version)"
actual_ripgrep_version="$("${installation_directory}/rg" --version | sed -n '1p')"
actual_swiftlint_version="$("${installation_directory}/swiftlint" version)"

[[ "${actual_just_version}" == "just ${just_version}" ]] \
  || fail "expected just ${just_version}, found ${actual_just_version}"
[[ "${actual_ripgrep_version}" == "ripgrep ${ripgrep_version}"* ]] \
  || fail "expected ripgrep ${ripgrep_version}, found ${actual_ripgrep_version}"
[[ "${actual_swiftlint_version}" == "${swiftlint_version}" ]] \
  || fail "expected SwiftLint ${swiftlint_version}, found ${actual_swiftlint_version}"

printf 'Installed just %s, ripgrep %s, and SwiftLint %s in %s.\n' \
  "${just_version}" \
  "${ripgrep_version}" \
  "${swiftlint_version}" \
  "${installation_directory}"
