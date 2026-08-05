# XPCCoding Production-Readiness Audit — 2026-07-29

<!-- markdownlint-disable MD013 -->

## Candidate

| Field | Value |
| --- | --- |
| Repository | [`plx/hdxl-xpc-coding`](https://github.com/plx/hdxl-xpc-coding) |
| Audited source commit | [`8dab29a230817c3911a2a8e48467c49a9c0a2604`](https://github.com/plx/hdxl-xpc-coding/commit/8dab29a230817c3911a2a8e48467c49a9c0a2604) |
| Audited source tree | `0c2c6353840e7c546ed18656b38f548f8c5b0d54` |
| Proposed version and tag | `0.1.0` |
| Audit period | 2026-07-27 through 2026-07-29 |
| Audit definition | [Post-Remediation Production-Readiness Audit](PostRemediationProductionReadinessAudit.md) |
| Retained local evidence | [2026-07-29 evidence index](audit-evidence/2026-07-29/README.md) |
| Remediation baseline | [`813c52e0aab258a185aa6d5e8c1a241d419ce589`](https://github.com/plx/hdxl-xpc-coding/commit/813c52e0aab258a185aa6d5e8c1a241d419ce589) |
| Source API baseline | `5f6480ec450eb6a1067d183d62d47476f2ca5b4b` |

The source candidate was established in a fresh clone. It had no untracked or
ignored source inputs, no submodules, and no package dependencies. The audit
report is added after that source freeze; it does not change the audited
library, package manifest, tests, fixtures, or release tooling.

No `0.1.0` tag, GitHub Release, or Swift Package Index submission existed when
the audit ended. Publication remains a separate, explicitly approved operation
under [issue #51](https://github.com/plx/hdxl-xpc-coding/issues/51).

## Environment

The independent local work ran on:

- Apple M4 Max, model `Mac16,5`, 64 GiB memory;
- arm64;
- macOS 27.0 prerelease build `26A5378n`;
- Xcode 26.6 build `17F113`; and
- Apple Swift 6.3.3.

The complete compiler identity was:

```text
swift-driver version: 1.148.6 Apple Swift version 6.3.3
(swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx28.0
```

The authoritative supported sanitizer and CI lane ran on an arm64 macOS 26
runner with that same Xcode 26.6 and Swift 6.3.3 toolchain. Cross-compilation
also used arm64 macOS 26, iOS 26, and Mac Catalyst 26 destinations.

## Decision

**Verdict: `GO`**

Commit `8dab29a230817c3911a2a8e48467c49a9c0a2604` is suitable for the
documented production envelope. All phases required by the audit definition
were completed, no substantive P0 or P1 finding remains open, and no waiver is
used.

The production envelope is deliberately narrow:

- Xcode 26.6 build 17F113 and Apple Swift 6.3.3 exactly;
- Swift tools version 6.3 and Swift language mode 6;
- arm64;
- macOS 26+, iOS 26+, and Mac Catalyst 26+;
- Swift Package Manager distribution;
- same-host, co-built, same-revision, co-deployed participants; and
- Apple XPC objects carried inside an application-owned transport dictionary.

Networking, persistence, neutral-byte interchange, independently versioned
participants, and cross-toolchain wire compatibility are not supported. Those
are the approved representation boundary, not release conditions.

### Accepted limitations

- Real application/service request-reply execution was performed on macOS.
  iOS and Mac Catalyst received the strongest applicable arm64 compile
  verification; the macOS application/service topology is not asserted for
  those platforms.
- Buffer/count entry points require initialized, readable backing storage for
  the complete positive count. A raw address does not carry allocation-extent
  metadata, so callers must satisfy that documented precondition.
- Real transport latency is not claimed or used as an acceptance threshold.
  Service startup and topology would make that measurement environment
  dependent. The bounded real-transport correctness test did pass.
- Performance numbers characterize the recorded M4 Max audit host and are
  regression evidence, not universal throughput guarantees.

## Executive evidence

| Phase | Result | Principal evidence |
| --- | --- | --- |
| 0. Immutable candidate | Pass | Fresh clean clone; exact commit and tree; epics #53–#58 and native leaves closed |
| 1. Manifest and public surface | Pass | Exact toolchain policy; three arm64 platform builds; external consumer; API and inlining gates |
| 2. Deterministic validation | Pass | Warning-free debug/release builds; 288 debug and 287 release tests; four disposable-worktree failure controls |
| 3. Strings and keys | Pass | 8,209 scalar-distinct strings, 2,048 mandatory-pair keys, exact scalar round trips and injectivity |
| 4. Numeric representation | Pass | Boundaries, corrupt lengths/types, exact shapes, and actual address remainders 0–15 |
| 5. `Data` and buffers | Pass | Exact one-object representation in five positions at every size through 32 MiB; retained-allocation measurements; address-instrumented `Data` and string ownership checks |
| 6. `Codable` semantics | Pass | Repeated containers, nil/missing semantics, paths, partial failure, inheritance, and `userInfo` |
| 7. Resource bounds | Pass | Checked corpus, generated and transformed cases, deterministic limits, and fail-closed runner controls |
| 8. Real XPC transport | Pass | Nine separate-process request/reply iterations at 0 bytes, 1 MiB, and 32 MiB |
| 9. Concurrency and lifetime | Pass | 8,000 shared-codec mixed operations under thread instrumentation; 2,560 batched large-payload operations with bounded resident growth |
| 10. Runtime instrumentation | Pass | Complete address, undefined-behavior, and supported-lane thread instrumentation runs |
| 11. Performance | Pass | 67 release scenarios, two decode-outcome timings, and eight allocation sizes; no same-host regression above the predeclared 10% threshold |
| 12. Coverage and test quality | Pass | 94.501% lines; 22 historical defects absent; missing-key and referencing-reuse mutation controls rejected |
| 13. Tooling and CI | Pass | Exact 15 protected checks, strict up-to-date branch policy, no bypass actors |
| 14. Documentation/legal/release | Pass | 142 declared public symbols documented; approved provenance; clean release rehearsal |

## Detailed results

### Phase 0: candidate and issue state

The clone resolved to commit `8dab29a` and tree `0c2c635`; `git status
--short` and `git submodule status` were empty. Epics
[#53](https://github.com/plx/hdxl-xpc-coding/issues/53) through
[#58](https://github.com/plx/hdxl-xpc-coding/issues/58), all native sub-issues,
and all of their blocked-by relationships were closed. Only orchestration
issues #51, #52, and #59 remained open.

The required marker scan found explanatory occurrences in audit/history
documentation, quality recipes, workflow descriptions, and negative-control
scripts. It found no unresolved product `TODO`, `FIXME`, `TBD`, or `HACK`, and
no tolerated test outcome. Each occurrence describes or enforces the
zero-known-issue policy; none is a candidate defect.

The unrelated, older documentation
[PR #5](https://github.com/plx/hdxl-xpc-coding/pull/5) is outside the
production-readiness issue program and does not alter this candidate.

### Phase 1: package and public API

`swift package dump-package`, `describe`, and `show-dependencies` confirmed:

- package `hdxl-xpc-coding`, product `XPCCoding`, module `XPCCoding`;
- tools version 6.3 and Swift language mode 6;
- macOS 26, iOS 26, and Mac Catalyst 26;
- no external package dependency; and
- no accidental unsafe SwiftPM setting.

Independent release builds passed for arm64 macOS 26, generic arm64 iOS, and
generic arm64 Mac Catalyst. A separate package importing only `XPCCoding`
compiled the standard codec, custom strategies, direct facades, `userInfo`,
enhanced data APIs, shared use, and application-owned XPC envelope.
Compile-failure controls verified that internal API and facade configuration
mutation remain inaccessible.

The source API gate found no breaking changes relative to the pinned hardened
baseline `5f6480e`. All 68 reviewed `@inlinable`/`@usableFromInline`
annotations matched the inlining policy.

### Phase 2: deterministic build and tests

Clean warning-as-error builds and tests passed:

- debug: 288 tests in 33 suites;
- release: 287 tests in 33 suites; and
- no skipped, tolerated, or known-failing tests.

The one-count difference is intentional: a debug-only language-runtime
negative control proves that an alignment-requiring operation rejects the
deliberately unsuitable address. Candidate behavior is tested in both
configurations.

Formatting, SwiftLint, documentation, API, task-recipe, zero-known-issue, and
benchmark-comparator controls all failed closed when given their deliberately
invalid fixtures and passed on the candidate.

Four detached worktrees of the exact candidate introduced one deliberate error
each. The canonical formatting command rejected malformed spacing, SwiftLint
rejected a forced unwrap, the debug test recipe reported one real failing test
in a 289-test run, and the documentation command rejected one undocumented
public declaration. The retained transcripts are:

- [formatting control](audit-evidence/2026-07-29/phase-02-format-failure-control.txt);
- [lint control](audit-evidence/2026-07-29/phase-02-lint-failure-control.txt);
- [test control](audit-evidence/2026-07-29/phase-02-test-failure-control.txt); and
- [documentation control](audit-evidence/2026-07-29/phase-02-documentation-failure-control.txt).

### Phases 3–6: representation and `Codable` behavior

A new external, release-built, public-API-only harness passed:

- 8,209 scalar-distinct strings and a 2,048-key inventory, including mandatory
  literal-percent/embedded-NUL collision pairs, composed/decomposed Unicode,
  malformed encodings, and historically colliding pairs;
- scalar-for-scalar string round trips and one-to-one escaped representations,
  with corpus identity defined by Unicode-scalar arrays rather than Swift
  canonical-equivalence;
- signed, unsigned, and floating-point boundaries, exact object kinds, invalid
  lengths/types, and checked conversions;
- `Int128` and `UInt128` decoding from actual underlying address remainders
  0 through 15;
- every required `Data` size through the documented 32 MiB maximum in
  top-level, keyed, unkeyed, nested, and inheritance positions, with the
  embedded XPC data child and exact decoded bytes checked in each position;
- documented nil/non-nil and positive/zero/negative buffer/count pairs;
- decoded `Data` ownership after source-object release and allocation churn;
  and
- repeated same-kind container requests, missing-key behavior, partial child
  failure, inheritance, user-thrown error identity, and `userInfo`.

Same-build structural fixtures were reviewed and decoded independently of the
candidate encoder. Ordinary `Data` uses one XPC data object; a containing
keyed or unkeyed structure therefore has two objects, not one object per byte.

A second external public-API probe ended the source-XPC scope before allocation
churn and then validated one MiB of `Data` plus all three data-backed string
representations byte-for-byte. It passed under address instrumentation:
1,048,576 `Data` bytes, 225,280 UTF-8 bytes, 417,794 UTF-16 bytes, and 819,204
UTF-32 bytes remained exact. Its
[source and transcript](audit-evidence/2026-07-29/README.md#phases-39-external-public-api-checks)
are retained.

Repository semantic suites—not the external harness—supplied the invalid
container-kind transition, complete coding-path, and explicit-null/non-null
coverage. In particular,
[`KeyedDecodeNilTests`](../Tests/XPCCodingTests/Suites/KeyedDecodeNilTests.swift),
[`EncodingCodingPathTests`](../Tests/XPCCodingTests/Suites/EncodingCodingPathTests.swift),
[`DecodingCodingPathTests`](../Tests/XPCCodingTests/Suites/DecodingCodingPathTests.swift),
and
[`ReferencingEncoderStateTests`](../Tests/XPCCodingTests/Suites/ReferencingEncoderStateTests.swift)
exercise those claims directly.

### Phase 7: bounded-input validation

The checked-in corpus contained 338 verified cases with digest
`7185e6b1259f65f3`. Repeated generation from seed
`0x5eed000000000001` produced one stable case digest and identical outcomes.

The bounded campaign prepared 721 cases:

- 337 corpus cases;
- 192 generated cases; and
- 192 transformed cases.

All 721 completed with zero failures and zero safety violations under eight
bounded child processes, a 10-second wall limit, a 5-second CPU limit, and a
768 MiB memory limit. Separate controls proved wall-clock enforcement, memory
enforcement, failure reporting, and reduction of a deliberately failing
fixture. The focused resource suite passed 35 tests in four suites.

### Phase 8: XPC process boundary

Nine release-built macOS application/service request-reply iterations passed:
three each with 0 bytes, a representative 1,048,576 bytes, and the documented
maximum 33,554,432 bytes. Each used separate client and service process
identifiers and an application-owned XPC dictionary. Each run also exercised a
missing operation, a wrong scalar shape, application error propagation, and
connection interruption. The fixture validated the embedded service and its
signing requirement before execution.

The empty and maximum cases used detached worktrees of exact commit `8dab29a`
and changed only the external integration fixture's compile-time payload-size
constant. Before execution, each retained wrapper required a clean index, no
untracked files, exactly one changed path, the expected porcelain status, and
a whitespace-clean diff:

- [representative payload](audit-evidence/2026-07-29/phase-08-xpc-representative-payload.txt);
- [empty payload](audit-evidence/2026-07-29/phase-08-xpc-empty-payload.txt); and
- [maximum payload](audit-evidence/2026-07-29/phase-08-xpc-maximum-payload.txt).

### Phase 9: concurrency and lifetime

The external harness completed 8,000 mixed encode/decode operations while
sharing four immutable codec configurations. The same finite concurrency-only
workload then passed all 8,000 operations under thread instrumentation on the
audit host. Repository tests separately verified configuration copies,
distinct facade factories, state isolation, returned-XPC ownership,
decoded-data ownership, and referencing-container lifecycle. The retained
[instrumented transcript](audit-evidence/2026-07-29/phase-09-external-concurrency-instrumented.txt)
contains the exact focused invocation's output.

A separate release-built public-API probe ran 2,560 mixed encode/decode
operations with a 512 KiB `Data` field in per-operation autorelease pools. It
sampled physical footprint and live default-zone allocations after each of 32
batches, following four warmup batches and allocator-pressure relief before
each sample. The acceptance limits were fixed in source before execution:
16 MiB maximum end growth, 256 KiB maximum least-squares growth per batch, and
4 MiB maximum live-allocation growth. The passing run recorded 49,152 bytes of
physical-footprint end growth, 49,104 bytes of live-allocation growth, and a
1,447.41-byte-per-batch slope. The
[source and JSON](audit-evidence/2026-07-29/README.md#phases-39-external-public-api-checks)
are retained.

### Phase 10: supported runtime instrumentation

Complete address and undefined-behavior instrumentation runs passed locally
with all 288 tests. The complete thread instrumentation job passed on the
authoritative arm64 macOS 26/Xcode 26.6 lane, then passed again when rerun
against the exact same source tree:

- [initial supported-lane job](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966648);
- [independent rerun](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90577331069); and
- [rerun log artifact](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/artifacts/8724074995),
  digest
  `sha256:d5090e1605fbdcf103be82084e192cd90c6b14c48cb44e419ad0ef54bf62899f`.

That rerun passed the full 288-test/33-suite package run plus the focused
35-test/4-suite resource run without a diagnostic.

#### Prerelease-host observation

On the audit host's macOS 27 prerelease build, the Xcode 26.6 thread
instrumentation runtime intermittently stopped while Foundation allocated
storage for `String.init(bytes:encoding:)`. The aggregate run stopped once; a
standalone rerun passed; four more repetitions passed before a sixth stopped
in the same runtime allocator path. A focused long-string run similarly passed
once and then stopped there. No data-race report was emitted.

Foundation-only and Swift-task/Foundation controls completed cleanly across
the exercised UTF-8, UTF-16, and UTF-32 paths. More importantly, the supported
arm64 macOS 26 lane passed twice on the exact source tree. The prerelease
host/toolchain pairing is therefore recorded as a non-release diagnostic
observation, not a candidate finding or waiver. Recheck it when a stable
macOS 27/Xcode pairing becomes part of a future support decision.

A separate headless Claude Opus review of this disputed observation classified
it as **non-blocking** for the stated support policy. The final disposition
remains based on the reproducible supported-lane evidence above.

### Phase 11: performance and scalability

The release benchmark used three warmups, 15 measured samples, and a 100 ms
target sample duration on the recorded M4 Max host. It exercised 67 successful
scalar, model, nesting, data, string, key, collection, and direct-buffer
scenarios.

Representative 1 MiB results:

| Scenario | Median | p95 | XPC objects |
| --- | ---: | ---: | ---: |
| Top-level `Data` encode | 57,792 ns | 64,233 ns | 1 |
| Top-level `Data` decode | 12,916 ns | 12,958 ns | 1 |
| Keyed `Data` encode | 54,333 ns | 60,091 ns | 2 |
| Unkeyed `Data` encode | 54,709 ns | 59,392 ns | 2 |
| Direct-buffer encode | 53,958 ns | 58,013 ns | 1 |

The benchmark implementation and package manifest were unchanged from the
same-machine epic-55 baseline at `51407d9`. The predeclared comparator threshold
was 10%; none of the 67 scenarios regressed by more than that threshold. The
baseline JSON is retained with SHA-256
`a103aa3f7e91cf471b85c8ad493dd2c91c193fa14dd82bb2d88a8345e54d8e08`,
and the retained comparison verifies that baseline and candidate both identify
the same `Mac16,5` host.

A separate release-built public-API timing probe covered both a successful
string decode and an expected `DecodingError.dataCorrupted` result for an
unsupported percent escape. Each used three warmups and 15 samples of 100,000
operations:

| Decode outcome | Median | p90 | p95 | p99 | Standard deviation |
| --- | ---: | ---: | ---: | ---: | ---: |
| Success | 214.75 ns | 223.85 ns | 228.02 ns | 228.22 ns | 5.00 ns |
| Expected error | 258.83 ns | 262.18 ns | 264.90 ns | 269.34 ns | 3.24 ns |

The probe's source, report, and command transcript are retained in the
[evidence index](audit-evidence/2026-07-29/README.md#phase-11-performance-and-allocations).

A release smoke sample recorded 36,192,256 bytes maximum resident set size and
3,981,816 bytes peak memory footprint, with no swap activity. Data object count
remained constant while byte count increased.

An external public-API allocation probe then measured each required `Data`
size in a fresh process. It sampled live default-zone allocation blocks and
bytes immediately before and after retaining one encode or decode result, after
two warmups. This measures the retained allocation footprint rather than
claiming a count of transient allocator events.

| Bytes | Encode blocks/bytes retained | Decode blocks/bytes retained | Encode median | Decode median |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 1 / 64 | 0 / 0 | 42 ns | 208 ns |
| 1 | 2 / 144 | 0 / 0 | 83 ns | 167 ns |
| 16 | 2 / 144 | 2 / 96 | 84 ns | 291 ns |
| 1,024 | 2 / 1,344 | 2 / 1,104 | 125 ns | 250 ns |
| 4,096 | 2 / 5,184 | 2 / 4,176 | 167 ns | 292 ns |
| 65,536 | 2 / 128 | 2 / 65,616 | 3,542 ns | 1,625 ns |
| 1,048,576 | 2 / 128 | 2 / 1,048,656 | 55,125 ns | 13,459 ns |
| 33,554,432 | 2 / 128 | 2 / 33,554,512 | 1,686,417 ns | 447,042 ns |

Every encode produced exactly one XPC object. Retained encode block count was
constant above one byte; decode retained two blocks at non-inline sizes; and
time scaled approximately linearly at the larger sizes. Source and full output
are retained in the
[evidence index](audit-evidence/2026-07-29/README.md#phase-11-performance-and-allocations).

### Phase 12: coverage and test quality

The canonical-path coverage run passed the checked-in non-regression policy:

| Metric | Candidate | Baseline |
| --- | ---: | ---: |
| Lines | 3,832/4,055 (94.501%) | 3,844/4,077 (94.285%) |
| Regions | 1,146/1,222 (93.781%) | 1,140/1,216 (93.750%) |
| Functions | 494/532 (92.857%) | 493/531 (92.844%) |

The first coverage invocation used `/tmp` while compiler paths canonicalized
to `/private/tmp`; source filtering correctly failed closed. Repeating the
unchanged candidate from the canonical path produced the passing result above.

The regression-first probe ran 26 checks in bounded child processes. All 22
historical defects reproduced at the unedited audit baseline `813c52e`, all
four controls passed there, and none of those defects reproduced on the
candidate. This provides the required counterfactual controls for percent
escaping, alignment-safe decoding, the depth boundary, and `Data`
representation.

Two additional detached worktrees started at the exact candidate and each
contained only one deliberate guard mutation. Returning `false` for a missing
key made the focused six-test keyed-nil suite fail two tests. Replacing rather
than reusing active keyed and unkeyed containers made the focused
referencing-encoder suite fail eight cases across root, keyed-superclass, and
unkeyed-superclass paths. Each wrapper required the targeted test command to
return nonzero before reporting a passing control. The exact diffs and outputs
are retained as the
[missing-key control](audit-evidence/2026-07-29/phase-12-missing-key-mutation-control.txt)
and
[referencing-reuse control](audit-evidence/2026-07-29/phase-12-referencing-reuse-mutation-control.txt).

### Phase 13: CI and repository policy

The candidate tree passed all 15 maintainer-approved protected checks:

1. [Supported tests](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966487)
2. [Strict formatting](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966456)
3. [Strict SwiftLint and recipe contracts](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966492)
4. [API documentation](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966513)
5. [Source coverage](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966626)
6. [Same-host XPC request/reply](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966724)
7. [Regression-first baseline evidence](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966596)
8. [Source API stability](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966595)
9. [Deterministic bounded-input smoke](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966656)
10. [Address Sanitizer](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966697)
11. [Undefined Behavior Sanitizer](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966669)
12. [Thread Sanitizer](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966648)
13. [Compile macOS 26](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966820)
14. [Compile iOS 26](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966706)
15. [Compile Mac Catalyst 26](https://github.com/plx/hdxl-xpc-coding/actions/runs/30300806015/job/90092966663)

Ruleset `11429473` requires those exact GitHub Actions checks on an up-to-date
branch, requires resolved conversations, blocks force-push and deletion, and
has no bypass actor.

The advisory CodeQL Actions, CodeQL Swift, and whole-history secret-scan jobs
also passed. In accordance with the maintainer's explicit decision, those
three advisory jobs are not protected merge requirements and are not counted
among the 15.

### Phase 14: documentation, provenance, and release mechanics

The documentation gate found 161 public symbols: 142 declared symbols all had
documentation, and 19 compiler-synthesized symbols were explicitly exempt.
DocC completed without a documentation warning. README examples compiled
through the external public-API fixture.

The committed `.spi.yml` passed the official SPIManifest 1.13.0 validator with
the real package/product names, Swift 6.3, macOS 26, iOS 26, and XPCCoding
documentation target. Its stale/malformed metadata controls failed closed.

The provenance decision is recorded in
[Upstream Provenance and License Review](UpstreamProvenance.md) and was
explicitly approved by repository maintainer `plx` on 2026-07-26:

- distribution is `Apache-2.0 WITH Swift-exception`;
- root `LICENSE` includes the upstream runtime exception;
- derived files retain the approved notice;
- `THIRD_PARTY_NOTICES.md` records the upstream work; and
- no upstream `NOTICE` file existed to preserve or invent.

Private vulnerability reporting was enabled, there were zero open secret
alerts, and the repository's explicit CodeQL workflow was used instead of
GitHub's default setup.

The clean-clone release rehearsal passed against the exact candidate with
Xcode 26.6/Swift 6.3.3. It performed support, metadata, API, inlining, build,
test, and external-consumer gates without publishing. Its uncompressed,
prefix-free `git archive` SHA-256 was
`e42f1b4f2b022a0cf8cfd5be517d780b96302fa3495f9d2e2b5da77437688561`.
That rehearsal checksum is not expected to match GitHub's generated,
compressed, prefixed source archive.

Proposed GitHub Release notes are preserved on
[issue #106](https://github.com/plx/hdxl-xpc-coding/issues/106#issuecomment-5096333190).
Existing lightweight tags `0.0.1`, `0.0.2`, and `0.0.3` were untouched.

## Findings

### New release-blocking findings

None.

### Resolved pre-audit finding

Release-metadata preflight identified one P1 defect before the candidate was
frozen: the first proposed release-note/archive description was not exact.
[Issue #106](https://github.com/plx/hdxl-xpc-coding/issues/106) and
[PR #107](https://github.com/plx/hdxl-xpc-coding/pull/107) corrected it.
The audit candidate includes that correction.

### Observations

| ID | Severity | Observation | Disposition |
| --- | --- | --- | --- |
| OBS-01 | Informational | Intermittent Foundation allocation stop under Xcode 26.6 thread instrumentation on a macOS 27 prerelease host | Non-blocking: supported macOS 26 lane passed twice on the exact source tree; retain and revisit for a future support-matrix change |
| OBS-02 | Informational | Real service topology executed on macOS, while iOS and Catalyst were compile-verified | Documented platform constraint; no broader topology claim is made |
| OBS-03 | Informational | Stable transport latency was not separately benchmarked | Not applicable because no latency claim is made; bounded transport correctness passed |

There are no accepted P0/P1 defects, waivers, tolerated failures, or hidden
conditions.

## Commands and artifacts

Every evidence-producing audit command is listed below. The command transcript,
external harness sources, non-CI outputs, benchmark JSON, allocation results,
regression evidence, and coverage summary are committed in the
[evidence index](audit-evidence/2026-07-29/README.md). Hosted CI logs and
artifacts are linked above; repository scripts make the substantive checks
reproducible from the immutable commit.

Temporary paths below identify isolated scratch space and are not package
inputs. `/tmp/hdxl-xpc-audit52.UvYJGp` and
`/private/tmp/hdxl-xpc-audit52.UvYJGp` identify the same canonical directory on
the audit host.

### Candidate, repository, and program state

```sh
cd /tmp/hdxl-xpc-audit52.UvYJGp/candidate
date -u +%Y-%m-%dT%H:%M:%SZ
test "$DEVELOPER_DIR" = /Applications/Xcode.app/Contents/Developer
git status --short
git rev-parse HEAD
git rev-parse "HEAD^{tree}"
git describe --tags --always --dirty
git submodule status
git remote -v
uname -a
uname -m
sw_vers
sysctl -n machdep.cpu.brand_string
sysctl -n hw.model
sysctl -n hw.memsize
xcodebuild -version
swift --version
git check-ignore -v .build

gh auth status
gh repo view plx/hdxl-xpc-coding \
  --json nameWithOwner,defaultBranchRef,url
gh issue view 52 --repo plx/hdxl-xpc-coding \
  --json number,title,state,stateReason,author,body,labels,milestone,comments,closedAt,url
gh issue list --repo plx/hdxl-xpc-coding --state all \
  --label program:production-readiness --limit 100 \
  --json number,title,state,stateReason,closedAt,labels,url
gh issue list --repo plx/hdxl-xpc-coding --state open \
  --label program:production-readiness --limit 100 \
  --json number,title,state,labels,url

for issue in 53 54 55 56 57 58 52 51 59; do
  gh api -H "X-GitHub-Api-Version: 2022-11-28" \
    "repos/plx/hdxl-xpc-coding/issues/$issue/sub_issues" --paginate
  gh api -H "X-GitHub-Api-Version: 2022-11-28" \
    "repos/plx/hdxl-xpc-coding/issues/$issue/dependencies/blocked_by" --paginate
done

rg -n --hidden --glob '!.git/**' --glob '!.build/**' \
  --glob '!DerivedData/**' --glob '!vendor/**' \
  'TODO|FIXME|TBD|HACK|known issue|withKnownIssue|XCTExpectFailure' .
```

### Package, public API, and deterministic checks

```sh
bash Scripts/verify-support-policy.sh
swift package dump-package
swift package describe
swift package show-dependencies

swift build --configuration release --triple arm64-apple-macosx26.0 \
  --scratch-path "$audit_tmp/macos-build" -Xswiftc -warnings-as-errors
xcodebuild -scheme XPCCoding -destination "generic/platform=iOS" \
  -configuration Release -derivedDataPath "$audit_tmp/ios-derived" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build
xcodebuild -scheme XPCCoding \
  -destination "generic/platform=macOS,variant=Mac Catalyst" \
  -configuration Release -derivedDataPath "$audit_tmp/catalyst-derived" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
  SUPPORTS_MACCATALYST=YES SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build

swift package clean
swift build -Xswiftc -warnings-as-errors
swift test
swift test -c release
bash Scripts/verify-public-api.sh
bash Scripts/verify-api-stability.sh
bash Scripts/verify-inlining-annotations.sh
bash Scripts/check-swift-format.sh
just lint check-all github-actions-logging
bash Scripts/verify-just-recipe-contracts.sh
bash Scripts/run-tests-with-zero-known-issues.sh self-test
swift run -c release XPCCodingBenchmarks self-test
```

The four disposable-worktree controls used the exact candidate and the
following canonical gates. Each wrapper required `control_status` to be
nonzero, so a gate that incorrectly accepted its deliberate error would have
failed the control:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  just format check-all
just lint check-all github-actions-logging
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  just test debug
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/generate-api-documentation.sh "$control_docs_output"
```

### Independent property and transport checks

```sh
cd /tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-03-09/IndependentAdversarial
swift run -c release -Xswiftc -warnings-as-errors \
  IndependentXPCCodingAdversarial

cd /private/tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-05/ValueLifetimeProbe
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift run -c release --sanitize=address \
  -Xswiftc -warnings-as-errors ValueLifetimeProbe

cd /tmp/hdxl-xpc-audit52.UvYJGp/candidate
bash Scripts/run-fuzzing-smoke.sh
bash Scripts/run-hostile-input-tests.sh
bash Scripts/run-xpc-integration.sh
```

The external harness was iterated while its independent oracle was reviewed.
The first two runs exposed an oracle error: `%000` is the valid escape `%00`
followed by literal `0`, not an incomplete encoding. The malformed fixture was
corrected to `%000%`. A later independent review found that Swift
canonical-equivalence could collapse scalar-distinct strings and that a sorted
key prefix did not guarantee the required historical pairs. The final fixture
uses scalar-array identity, requires those pairs, and checks all five `Data`
positions at every required size. These were harness corrections, not
candidate changes; the retained output is the final passing run.

The empty and maximum transport overlays were run from detached worktrees after
proving the library and manifest remained unchanged:

```sh
test "$(git rev-parse HEAD)" = \
  8dab29a230817c3911a2a8e48467c49a9c0a2604
expected_path=IntegrationTests/XPCProcessBoundary/Sources/XPCCodingXPCIntegrationProtocol/IntegrationProtocol.swift
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard)"
test "$(git diff --name-only)" = "$expected_path"
test "$(git status --porcelain=v1 --untracked-files=all)" = \
  " M $expected_path"
git diff --check
git diff -- \
  "$expected_path"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/run-xpc-integration.sh
```

### Runtime instrumentation

```sh
bash Scripts/run-sanitizer-tests.sh address
bash Scripts/run-sanitizer-tests.sh undefined
bash Scripts/run-sanitizer-tests.sh thread

cd /tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-03-09/IndependentAdversarial
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift run -c release --sanitize=thread \
  -Xswiftc -warnings-as-errors \
  IndependentXPCCodingAdversarial concurrency-only

cd /tmp/hdxl-xpc-audit52.UvYJGp/candidate
for iteration in 2 3 4 5 6; do
  bash Scripts/run-sanitizer-tests.sh thread
done

swift test --package-path /tmp/hdxl-xpc-audit52.UvYJGp/candidate \
  --scratch-path "$scratch" --sanitize=thread \
  --filter "Very Long \\(x\\)" -Xswiftc -warnings-as-errors

swiftc -parse-as-library -sanitize=thread -warnings-as-errors \
  /tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-10/tsan-foundation-control.swift \
  -o /tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-10/tsan-foundation-control
/tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-10/tsan-foundation-control

swiftc -parse-as-library -sanitize=thread -warnings-as-errors \
  /tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-10/tsan-foundation-task-control.swift \
  -o /tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-10/tsan-foundation-task-control
/tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-10/tsan-foundation-task-control
```

The Foundation-only control was exercised across three complete runs before
one longer repetition command was manually interrupted during its fourth
clean run. The task/Foundation control completed five clean runs, followed by
three clean runs covering each exercised text encoding.

The supported-lane rerun used GitHub Actions' rerun facility for run
`30300806015`; the exact rerun job and downloaded artifact are linked in phase
10.

### Benchmarks, coverage, and regression evidence

```sh
swift run -c release XPCCodingBenchmarks run \
  --output /private/tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-11/complete-release-benchmark.json \
  --warmup 3 --samples 15 --target-sample-ms 100

/usr/bin/time -l swift run -c release XPCCodingBenchmarks run --smoke \
  --output /private/tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-11/resource-smoke.json

git diff --exit-code \
  51407d962ac1b60a416e058f58459b4db5c01f27 \
  8dab29a230817c3911a2a8e48467c49a9c0a2604 \
  -- Package.swift Benchmarks
swift run -c release XPCCodingBenchmarks compare \
  reference/audit-evidence/2026-07-29/phase-11-epic55-baseline-benchmark.json \
  reference/audit-evidence/2026-07-29/phase-11-complete-release-benchmark.json \
  --threshold-percent 10

bash Scripts/generate-source-coverage.sh \
  /tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-12/coverage
bash Scripts/generate-source-coverage.sh \
  /private/tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-12/coverage-canonical
bash Scripts/run-baseline-evidence.sh

cd /private/tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-09/ResidentGrowthProbe
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift run -c release -Xswiftc -warnings-as-errors ResidentGrowthProbe
./.build/arm64-apple-macosx/release/ResidentGrowthProbe
```

The two remaining mutation controls used separate detached worktrees at the
exact candidate. Each printed its sole source diff, ran one focused suite, and
required a nonzero test status:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test -Xswiftc -warnings-as-errors --filter KeyedDecodeNilTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test -Xswiftc -warnings-as-errors \
  --filter ReferencingEncoderStateTests
```

The external allocation probe was release-built against the clean candidate
and run once per required size, with each size receiving its own process:

```sh
cd /private/tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-11/AllocationProbe
test "$(git -C ../../../candidate rev-parse HEAD)" = \
  8dab29a230817c3911a2a8e48467c49a9c0a2604
test -z "$(git -C ../../../candidate status --short)"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift build -c release -Xswiftc -warnings-as-errors
binary="$(
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    swift build -c release --show-bin-path
)/XPCCodingAllocationProbe"
for byte_count in 0 1 16 1024 4096 65536 1048576 33554432; do
  XPCCODING_AUDITED_COMMIT=8dab29a230817c3911a2a8e48467c49a9c0a2604 \
    "$binary" "$byte_count"
done
```

The external decode-outcome timing probe used the same exact clean candidate:

```sh
cd /private/tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-11/DecodeTimingProbe
test "$(git -C ../../../candidate rev-parse HEAD)" = \
  8dab29a230817c3911a2a8e48467c49a9c0a2604
test -z "$(git -C ../../../candidate status --short)"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift build -c release -Xswiftc -warnings-as-errors
binary="$(
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    swift build -c release --show-bin-path
)/XPCCodingDecodeTimingProbe"
XPCCODING_AUDITED_COMMIT=8dab29a230817c3911a2a8e48467c49a9c0a2604 \
  "$binary"
```

### CI, documentation, legal, and prepublication state

```sh
gh pr view 107 --repo plx/hdxl-xpc-coding \
  --json number,title,state,isDraft,url,author,baseRefName,baseRefOid,headRefName,headRefOid,mergeStateStatus,mergeable,reviewDecision,statusCheckRollup,commits,files,body
gh pr checks 107 --repo plx/hdxl-xpc-coding --required=false
gh api -H "X-GitHub-Api-Version: 2022-11-28" \
  repos/plx/hdxl-xpc-coding/rulesets/11429473
bash Scripts/verify-main-ruleset.sh

bash Scripts/generate-api-documentation.sh \
  /private/tmp/hdxl-xpc-audit52.UvYJGp/evidence/phase-14/docc
bash Scripts/verify-swift-package-index-metadata.sh
bash Scripts/verify-support-policy.sh
bash Scripts/verify-main-ruleset.sh

gh issue view 106 --repo plx/hdxl-xpc-coding \
  --json number,title,state,stateReason,body,comments,closedAt,url
git tag --list --format="%(refname:short) %(objecttype) %(objectname)"
gh release list --repo plx/hdxl-xpc-coding --limit 100
gh api repos/plx/hdxl-xpc-coding/private-vulnerability-reporting
gh api repos/plx/hdxl-xpc-coding/code-scanning/default-setup
gh api 'repos/plx/hdxl-xpc-coding/secret-scanning/alerts?state=open&per_page=100'
```

The clean-clone release rehearsal's report and candidate metadata are preserved
with the release-note preflight evidence for issue #106. The repository's
fail-closed rehearsal script performed the clone, exact-tree check, gates,
archive, and checksum:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/release-rehearsal.sh \
  8dab29a230817c3911a2a8e48467c49a9c0a2604 \
  /tmp/hdxl-xpc-issue106-exact.PpFVzo/release-rehearsal
```

The rehearsal published nothing.

## Sign-off

### Auditor

**Codex — `GO`, 2026-07-29.**

The audit began in fresh Codex session
`019fa539-8a60-72f1-9de0-66d785a0ce74`. An automated execution filter stopped
that session during the external bounded-input harness, so the root Codex
session resumed from the same frozen clone, reran and completed the affected
phases, reconciled all retained outputs, and issued this verdict. No candidate
source changed during that continuation.

Headless Claude Opus attempted a broader read-only review but produced no
report before being cleanly interrupted. It is not represented as a full
co-auditor. A subsequent narrow read-only review of OBS-01 did complete and
independently classified that observation as non-blocking.

### Maintainer

Repository maintainer `plx` approved:

- the legal/provenance determination on 2026-07-26; and
- the exact 15-check protected-branch policy used by this audit; and
- the audit's `GO` verdict for source commit
  `8dab29a230817c3911a2a8e48467c49a9c0a2604` (tree
  `0c2c6353840e7c546ed18656b38f548f8c5b0d54`) on 2026-07-29.

Final authorization to create and publish the `0.1.0` tag, GitHub Release, and
Swift Package Index submission is intentionally reserved for the explicit
post-audit publication checkpoint. No publication action is implied by this
maintainer approval of the technical `GO` verdict. The code-review and
authorization boundary is recorded in the
[0.1.0 review and publication playbook](PublicationPlaybook-0.1.0.md).

On 2026-08-05, the maintainer authorized pushing the audit-report branch and
opening its pull request to `main`. This stage-specific authorization does not
authorize merging the pull request or any later publication action.
