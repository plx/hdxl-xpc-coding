# Validation Recipes

XPCCoding has no compile-time "heavy validation" mode. A compiler flag that no
source or test reads is not validation, so the former `HEAVY_VALIDATION`
debug/release variants were removed.

Build recipes now describe the only two real configurations:

```sh
just build debug
just build release
just build all
```

`build all` depends on exactly `debug` and `release`.

## Test groups

Standard unit tests are:

```sh
just test debug
just test release
just test all-standard
```

Both standard recipes go through
`Scripts/run-tests-with-zero-known-issues.sh`, described next; neither is a bare
`swift test`.

## The zero-known-issue policy

**A passing XPCCoding test run reports zero known issues.** A suite that
"passes with 69 known issues" is not a release signal anybody can read, so
intentionally lossy behavior is asserted exactly instead of being parked behind
`withKnownIssue`.

Concretely, the intentionally lossy `.assumeAbsent` string strategies are kept —
see [Embedded Null-Byte Handling](EmbeddedNullByteHandling.md) — and their exact
outcome is asserted: truncation at the first null byte, the resulting dictionary
key collision, and the resulting inequality with the source value. The safe
strategies keep exact round-trip expectations, and `.throwOnDiscovery` keeps an
exact thrown-error expectation. Changing any of those behaviors fails the suite.

`Scripts/run-tests-with-zero-known-issues.sh` is the canonical implementation
behind `just test debug`, `just test release`, and the CI test job, so the policy
cannot drift between a developer's machine and CI. It depends only on bash and
the Swift toolchain — no `just`, `jq`, or ripgrep — and fails closed on:

- `withKnownIssue` or `XCTExpectFailure` anywhere in first-party Swift sources;
- a known-issue or expected-failure marker in the captured test output;
- a raw NUL byte in the captured test output, so embedded-null probes have to
  report bytes rather than raw values; or
- a missing passing test-run summary, so a run that never reported one cannot be
  mistaken for success.

The gate's own detectors have positive and negative controls:

```sh
just test zero-known-issue-controls   # Scripts/run-tests-with-zero-known-issues.sh self-test
```

This builds nothing and runs in about a second, so a gate that has quietly
stopped rejecting anything is caught before it starts passing everything. It is
part of `just test all-validation` and runs as its own CI step.

If a genuine, temporarily unfixable defect ever needs to be recorded, record it
as a skipped test with a linked issue, or as a failing test on a branch — not as
a known issue on a green run.

The bounded validation leaves perform distinct work:

- `address-sanitizer`, `thread-sanitizer`, and
  `undefined-behavior-sanitizer` run the complete suite under separate dynamic
  analyzers;
- `fuzz-smoke` runs the fixed-seed, bounded fuzzing campaign;
- `hostile-input` runs subprocess-isolated invalid-input and expected-crash
  regressions from a fresh scratch build;
- `xpc-integration` performs three deterministic request/reply exchanges
  across a real application/service process boundary;
- `recipe-contracts` verifies the machine-readable `just` dependency graph;
- `coverage` runs the complete debug suite under the zero-known-issue policy,
  retains llvm-cov's source report, and enforces the reviewed line, region, and
  function ratios in `Scripts/source-coverage-policy.json`; and
- `zero-known-issue-controls` verifies the zero-known-issue gate itself.

`just test all-sanitizers` runs exactly the three sanitizer leaves.
`just test all-validation` runs the recipe contract, the zero-known-issue
controls, source coverage, all sanitizers, fuzz smoke, hostile-input
regressions, and XPC integration. `just test all` combines `all-standard` and
`all-validation`.

The long fuzz campaign and historical baseline reproduction remain explicit,
separate commands because they are not part of the bounded aggregate:

```sh
just test fuzz-campaign
just test baseline-evidence
```

## CI ownership

The supported workflow calls the same scripts as every executable validation
leaf:

| Validation | Canonical command | CI owner |
| --- | --- | --- |
| debug unit tests | `Scripts/run-tests-with-zero-known-issues.sh debug` | Supported tests |
| release unit tests | `Scripts/run-tests-with-zero-known-issues.sh release` | Supported tests |
| zero-known-issue controls | `Scripts/run-tests-with-zero-known-issues.sh self-test` | Supported tests |
| source coverage | `Scripts/generate-source-coverage.sh <output-directory>` | Source coverage |
| address sanitizer | `Scripts/run-sanitizer-tests.sh address` | Address Sanitizer |
| thread sanitizer | `Scripts/run-sanitizer-tests.sh thread` | Thread Sanitizer |
| undefined-behavior sanitizer | `Scripts/run-sanitizer-tests.sh undefined` | Undefined Behavior Sanitizer |
| hostile input | `Scripts/run-hostile-input-tests.sh` | Address and Thread Sanitizer |
| fuzz smoke | `Scripts/run-fuzzing-smoke.sh` | Deterministic fuzzing smoke |
| XPC integration | `Scripts/run-xpc-integration.sh` | Same-host XPC request/reply |

`Scripts/verify-just-recipe-contracts.sh` rejects obsolete validation-variant
names, any remaining `HEAVY_VALIDATION` reference in implementation or recipe
files, and any aggregate whose dependency set differs from the groups described
above.
It is the local preflight for aggregate wiring; final CI quality-gate assembly
owns installing its `just`, `jq`, and ripgrep prerequisites and adding the
preflight as a required check.

## Source-coverage policy

Run the canonical coverage gate with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  just test coverage .build/coverage
```

`Scripts/generate-source-coverage.sh` verifies the support policy, runs the
debug suite through the same zero-known-issue wrapper used elsewhere, copies
SwiftPM's raw llvm-cov JSON, writes a compact aggregate summary, and compares
production files under `Sources/XPCCoding` with the reviewed baseline in
`Scripts/source-coverage-policy.json`.

The baseline is commit `47f04faf94ff566faf9a5667e646d63d6055cc3f`
under Xcode 26.6 / Swift 6.3.3: 3,844 of 4,077 lines, 1,140 of 1,216 regions,
and 493 of 531 functions. Each ratio is a non-regression floor. A changed
source surface must retain or improve every ratio. Deliberately revising a
floor requires updating the policy file with a new reviewed revision, counts,
and rationale; CI does not auto-accept a lower measurement.

The `Source coverage (Xcode 26.6)` job retains the raw report, aggregate
summary, test transcript, and policy transcript for 14 days. The verifier's
self-test proves that an equal report passes, a line-ratio regression fails,
and a report with no production source files fails closed.
