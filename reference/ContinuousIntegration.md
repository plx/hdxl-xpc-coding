# Continuous Integration

XPCCoding's required checks use the sole supported Xcode 26.6 / Apple Swift
6.3.3 toolchain on arm64 `macos-26` runners. Workflow job display names are a
maintainer contract: branch protection refers to these stable check contexts,
so renaming one requires a coordinated ruleset update.

## Stable supported-configuration checks

The `Supported Configuration` workflow exposes:

- `Supported tests (Xcode 26.6)`;
- `Strict formatting (Xcode 26.6)`;
- `Strict SwiftLint and recipe contracts (Xcode 26.6)`;
- `API documentation (Xcode 26.6)`;
- `Source coverage (Xcode 26.6)`;
- `Same-host XPC request/reply (Xcode 26.6)`;
- `Regression-first baseline evidence (Xcode 26.6)`;
- `Source API stability (Xcode 26.6)`;
- `Deterministic fuzzing smoke (Xcode 26.6)`;
- `Address Sanitizer (Xcode 26.6)`;
- `Undefined Behavior Sanitizer (Xcode 26.6)`;
- `Thread Sanitizer (Xcode 26.6)`;
- `Compile macOS 26 (arm64)`;
- `Compile iOS 26 (arm64)`; and
- `Compile Mac Catalyst 26 (arm64)`.

Issue #50 selects and applies the required subset in the repository ruleset.
Until that settings ticket completes, this list documents the exact contexts
available for protection; it does not claim that GitHub already requires them.

## Canonical quality commands

CI calls the same implementations used locally:

| Gate | Canonical command |
| --- | --- |
| Formatting | `bash Scripts/check-swift-format.sh` |
| SwiftLint | `just lint check-all github-actions-logging` |
| API documentation | `bash Scripts/generate-api-documentation.sh <output-directory>` |
| Zero known issues | `bash Scripts/run-tests-with-zero-known-issues.sh debug` and `release` |
| Public consumer | `bash Scripts/verify-public-api.sh` |
| Source API | `bash Scripts/verify-api-stability.sh` |
| Source coverage | `bash Scripts/generate-source-coverage.sh <output-directory>` |
| Aggregate recipes | `bash Scripts/verify-just-recipe-contracts.sh` |

The quality job installs exact arm64 release archives of just 1.51.0, ripgrep
15.1.0, and SwiftLint 0.65.0. `Scripts/install-ci-quality-tools.sh` verifies
their published SHA-256 digests before installation. No release gate uses
`continue-on-error`, and shell pipelines use `pipefail` before `tee`.

Test, documentation, coverage, baseline, fuzzing, benchmark, and sanitizer
jobs retain the reports or complete transcripts that materially aid
diagnosis. Artifacts are short-lived validation evidence, not release
artifacts.

## Negative controls

Before changing a gate or its required-check status, use a disposable
branch/worktree and introduce one isolated failure at a time:

- malformed Swift formatting;
- a strict SwiftLint violation in production source;
- an unresolved DocC symbol link;
- a real `withKnownIssue` or failing test;
- an internal symbol reference in the public consumer;
- removal of a pinned public API;
- a coverage policy ratio above the measured report; and
- a wrong `all-validation` dependency.

Push each isolated probe only when hosted evidence is required. Confirm the
intended named job concludes `failure`, record the run URL, then revert the
probe and require a clean final run. Never retain a weakened threshold,
ignored exit, expected failure, or negative-control source change merely to
make the final workflow green.
