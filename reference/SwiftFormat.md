# swift-format

XPCCoding formats Swift sources with the `swift-format` bundled in the sole
supported toolchain: Xcode 26.6 (build 17F113). That Xcode release reports
swift-format version 6.3.0. Recipes resolve the executable through `xcrun`, so
`DEVELOPER_DIR` or the active Xcode selection controls which tool is used.

Every recipe first runs `Scripts/verify-swift-format-version.sh`. A missing
formatter or any version other than 6.3.0 fails before files are checked or
changed. Verify a selected toolchain directly with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/verify-swift-format-version.sh
```

All invocations explicitly load the repository's `.swift-format` file.

## Blocking checks

`Scripts/check-swift-format.sh` is the canonical strict gate. Both
`just format check-all` and the `Strict formatting (Xcode 26.6)` CI job invoke
that script directly, so local and hosted checks cannot drift into parallel
implementations. The script runs:

```sh
xcrun swift-format lint \
  --configuration .swift-format \
  --strict \
  --recursive \
  --parallel \
  Sources Tests
```

The `check-sources`, `check-tests`, and `check-file` variants are strict as
well. Any formatter finding therefore produces a nonzero exit status. None of
the check recipes ignores or rewrites that status.

## Mutating recipes

Formatting is always an explicit, separate action:

```sh
just format all
just format sources
just format tests
just format file path/to/File.swift
```

The corresponding `check-*` recipes never modify files.

## Rule ownership

swift-format owns whitespace, line breaking, indentation, and the syntactic
style rules enabled in `.swift-format`. SwiftLint owns naming, force unwraps
and force tries, implicitly-unwrapped optionals, and decisions about retaining
explicit memberwise initializers. Those overlapping swift-format rules are
disabled deliberately:

- SwiftLint keeps production force unwraps prohibited while its nested test
  configuration permits fixed literals and values proven valid by
  construction.
- SwiftLint's identifier rules carry exact project and legacy-fixture
  exceptions.
- Explicit initializers may carry access-control or inlining intent, so their
  removal is a review decision rather than an automatic formatting change.

Documentation-comment syntax remains enabled in swift-format. Public
documentation completeness is enforced separately by
`Scripts/verify-public-documentation.sh`.
