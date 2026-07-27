# Sanitizer Testing

XPCCoding runs three independent dynamic-analysis lanes on the one supported
toolchain: Xcode 26.6 (build 17F113), Apple Swift 6.3.3, and arm64 macOS 26.
AddressSanitizer, UndefinedBehaviorSanitizer, and ThreadSanitizer are never
combined.

The scripts used by CI are also the local entry points:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/run-sanitizer-tests.sh address

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/run-sanitizer-tests.sh undefined

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/run-sanitizer-tests.sh thread
```

The matching convenience recipes are `just test address-sanitizer`,
`just test undefined-behavior-sanitizer`, and
`just test thread-sanitizer`.

Each invocation uses and removes a fresh SwiftPM scratch directory. That keeps
instrumented products from different analyzers isolated when the recipes run
back-to-back.

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

Run the same isolated command used by both CI lanes with
`just test hostile-input` or `bash Scripts/run-hostile-input-tests.sh`.

UndefinedBehaviorSanitizer does not have the interceptor-loading limitation,
so its complete suite runs those subprocess tests directly.
