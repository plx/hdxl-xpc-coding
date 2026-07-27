#!/usr/bin/env bash

set -euo pipefail

usage() {
  printf 'usage: %s {address|thread|undefined}\n' "${0##*/}" >&2
  exit 64
}

[[ $# -eq 1 ]] || usage

sanitizer=
case "$1" in
  address)
    export ASAN_OPTIONS="${ASAN_OPTIONS:+${ASAN_OPTIONS}:}halt_on_error=1"
    sanitizer="address"
    ;;
  thread)
    export TSAN_OPTIONS="${TSAN_OPTIONS:+${TSAN_OPTIONS}:}halt_on_error=1"
    sanitizer="thread"
    ;;
  undefined)
    export UBSAN_OPTIONS="${UBSAN_OPTIONS:-print_stacktrace=1}:halt_on_error=1"
    sanitizer="undefined"
    ;;
  *)
    usage
    ;;
esac
readonly sanitizer

scratch_directory="$(mktemp -d \
  "${TMPDIR:-/tmp}/hdxl-xpc-${sanitizer}-sanitizer.XXXXXX")"
readonly scratch_directory

cleanup() {
  rm -rf -- "${scratch_directory}"
}
trap cleanup EXIT

swift test \
  --scratch-path "${scratch_directory}/swiftpm" \
  --sanitize="${sanitizer}" \
  -Xswiftc -warnings-as-errors
