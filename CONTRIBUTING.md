# Contributing to XPCCoding

Thank you for helping improve XPCCoding. The project is maintained by one
person, so focused changes with explicit evidence are much easier to review
and sustain than broad speculative rewrites.

## Supported development environment

XPCCoding has one intentional support matrix:

- Xcode 26.6 (build 17F113);
- Apple Swift 6.3.3 in Swift 6 language mode;
- an arm64 development host; and
- macOS 26.0, iOS 26.0, and Mac Catalyst 26.0 deployment targets.

Earlier or beta toolchains, older deployment targets, Intel hosts, and
additional Apple platforms are not supported configurations. Read the
[support policy](reference/SupportPolicy.md) before proposing a matrix change.

Local quality checks also use just 1.51.0, SwiftLint 0.65.0, jq, and ripgrep.
CI installs its copies from pinned archives. Select the supported Xcode before
running repository commands:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash Scripts/verify-support-policy.sh
```

## Before starting

For anything beyond a small documentation correction:

1. Search the open and closed issues and pull requests.
2. Open or select one focused issue.
3. Link every issue that blocks the work and finish those dependencies first.
4. For a defect, add or identify a regression that fails before the fix and
   passes afterward. Record the failing-before revision and command.
5. Keep unrelated cleanup in a separate issue and pull request.

Do not report suspected vulnerabilities publicly. Follow
[SECURITY.md](SECURITY.md) and use GitHub private vulnerability reporting.

## Make the change

Preserve the distinction between the public `XPCEncoder`/`XPCDecoder` facades
and the internal `_XPCEncoder`/`_XPCDecoder` protocol implementations. Consult
[Project History](reference/ProjectHistory.md) when organization or style is
unclear, and
[Embedded Null-Byte Handling](reference/EmbeddedNullByteHandling.md) for any
string-key or string-value change.

Add proportionate tests with the implementation. A green run must contain
zero known issues or expected failures; intentionally lossy behavior is
asserted exactly. Performance claims require same-machine release evidence
from the [benchmark harness](Benchmarks/README.md), including the measured and
harness revisions.

The compatibility and release rules are:

- Public source-API changes follow
  [the API stability policy](reference/ApiStabilityPolicy.md). Update public
  documentation and migration guidance; an intentional source break also
  requires a later commit advancing the pinned API baseline.
- XPC object-representation changes update
  [the representation contract](reference/WireFormat.md) and same-build
  fixtures in the same pull request. They require every participating process
  to rebuild and redeploy together; do not present them as cross-release wire
  compatibility.
- User-visible changes update the appropriate section under
  `CHANGELOG.md`'s `Unreleased` heading. State explicitly when no changelog
  entry is warranted.
- Toolchain or platform changes are compatibility decisions and must update
  the manifest, support policy, CI assertions, README, and audit instructions
  together.

## Validate locally

Run the smallest relevant test while iterating. Before marking a substantive
pull request ready, run the canonical checks from the repository root:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

bash Scripts/verify-support-policy.sh
just format check-all
just lint check-all
just docs check-all
just release verify-api-stability
just release verify-spi-metadata
just test all
```

The complete test aggregate includes debug and release tests, recipe negative
controls, coverage, all three sanitizers, deterministic fuzzing, hostile-input
regressions, and real same-host XPC request/reply integration. Documentation-
only changes may use proportionate local checks, but the pull request must
still pass all protected hosted checks. See
[Validation Recipes](reference/ValidationRecipes.md) for individual commands.

When a check is intentionally inapplicable, explain why in the pull request
instead of silently omitting it.

## Pull requests

Open a draft pull request early enough for hosted evidence to be visible.
Complete the pull request template, including:

- the closing issue and all dependencies;
- failing-before regression evidence, or why it does not apply;
- exact validation commands and results;
- public API, XPC representation, support-matrix, and changelog impact; and
- benchmark evidence for performance-sensitive work.

Keep the branch current with `main`. Every review conversation must be
resolved and all 15 protected supported-configuration checks must pass before
merge. The CodeQL and whole-history secret-scan jobs remain visible advisory
evidence under the current
[branch-protection policy](reference/MainBranchProtection.md).

The repository currently has one eligible maintainer. It intentionally has no
`CODEOWNERS` file because assigning that same maintainer to every path would
add notifications without an independent ownership or approval signal. That
decision can be revisited if maintainership expands.
