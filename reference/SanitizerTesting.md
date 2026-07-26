# Sanitizer Testing

XPCCoding runs three independent dynamic-analysis lanes on the one supported
toolchain: Xcode 26.6 (build 17F113), Apple Swift 6.3.3, and arm64 macOS 26.
AddressSanitizer, UndefinedBehaviorSanitizer, and ThreadSanitizer are never
combined.

Run the complete suite locally from the repository root with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  ASAN_OPTIONS=halt_on_error=1 \
  swift test --sanitize=address -Xswiftc -warnings-as-errors

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \
  swift test --sanitize=undefined -Xswiftc -warnings-as-errors

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  TSAN_OPTIONS=halt_on_error=1 \
  swift test --sanitize=thread -Xswiftc -warnings-as-errors
```

Every unsuppressed sanitizer report, unexpected signal, test failure, or
timeout fails its lane. CI pipes each command through `tee` with
`set -o pipefail` and retains the complete output as a 14-day artifact. There
are no sanitizer suppressions.

## Subprocess-isolated regressions

SwiftPM's macOS Swift Testing host loads an instrumented test bundle with
`dlopen`. AddressSanitizer and ThreadSanitizer therefore install their
interceptors too late in a re-launched `#expect(processExitsWith:)` child and
abort even when the child body is empty. The affected exit tests detect those
two runtimes and skip only their subprocess copy; their equivalent in-process
paths remain part of the complete instrumented suite.

The AddressSanitizer and ThreadSanitizer jobs additionally run the guarded
hostile-input and expected-crash suites without instrumentation, from a
separate scratch build. This preserves their process-boundary assertions
without weakening either sanitizer run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test \
    --scratch-path /tmp/hdxl-xpc-subprocess-tests \
    -Xswiftc -warnings-as-errors \
    --filter \
    'UnalignedNumericDecodingTests|DecoderResourceLimitTests|ReferencingEncoderStateTests|UnsafePointerCountValidationTests'
```

UndefinedBehaviorSanitizer does not have the interceptor-loading limitation,
so its complete suite runs those subprocess tests directly.
