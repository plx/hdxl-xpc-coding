# XPCCoding Production-Readiness Issue Program

**Program created:** 2026-07-25\
**Source review revision:** `813c52e`\
**Top-level epic:** [#59](https://github.com/plx/hdxl-xpc-coding/issues/59)\
**Initial disposition:** `NO-GO` for production release

## Purpose

This document is the durable index for the GitHub issue program created from
the
[Production-Readiness Due-Diligence Review](ProductionReadinessDueDiligence-2026-07-25.md).
It explains the ticket taxonomy, hierarchy, and dependency order so the work
can be resumed after context loss and reviewed without reconstructing the
original audit conversation.

The live GitHub issue state is authoritative. This file records the program as
created and should be updated when the hierarchy or intended ordering changes
materially. After remediation, use the
[Post-Remediation Production-Readiness Audit](PostRemediationProductionReadinessAudit.md)
to make a new evidence-based go/no-go decision.

For end-to-end execution, follow the
[Production-Readiness Remediation Goal](ProductionReadinessRemediationGoal.md).
It defines live work selection, per-ticket PR discipline, continuity across
compaction, component-gate handling, the immutable audit candidate, and the
post-audit publication checkpoint.

## Fixed scope and support policy

The program deliberately targets:

- Swift 6.3 only;
- macOS 26 or newer;
- iOS 26 or newer;
- Mac Catalyst 26 or newer;
- SwiftPM distribution and Apple XPC transport.

It does not ask maintainers to support older Swift or Apple platform versions.
The static documentation website and landing page are excluded. The README,
public API documentation, repository policy, and package-index metadata remain
in scope because they are part of publishing and operating the package.

## Same-build representation decision

On 2026-07-26, the maintainer defined XPCCoding's compatibility boundary as a
same-host compilation cohort: applications and XPC services that are designed,
configured, built, deployed, and updated together. The boundary is analogous
to package visibility.

The program therefore does not pursue independently versioned peers,
cross-release decoding, network or persistent serialization, neutral byte
representations, runtime format metadata, or a library-owned message envelope.
Applications own the outer XPC dictionary used for transport and any
application-level versioning they choose.

Issue #24 was closed not planned under this decision. Its dependency edges were
removed, and #20, #22, #23, #25, #26, #36, #47, and #55 were reconciled to the
same-build model. The normative repository contract is
[XPCCoding XPC Object Representation](WireFormat.md).

## Program shape

At creation, the program contained:

- 47 independently actionable tickets:
  [#7](https://github.com/plx/hdxl-xpc-coding/issues/7) through
  [#52](https://github.com/plx/hdxl-xpc-coding/issues/52), plus
  [#60](https://github.com/plx/hdxl-xpc-coding/issues/60);
- six component epics,
  [#53](https://github.com/plx/hdxl-xpc-coding/issues/53) through
  [#58](https://github.com/plx/hdxl-xpc-coding/issues/58);
- one top-level epic,
  [#59](https://github.com/plx/hdxl-xpc-coding/issues/59);
- 41 semantic labels;
- 53 native parent/sub-issue relationships;
- 93 native `blocked by` relationships.

Each actionable ticket contains the problem, required direction, validation,
acceptance criteria, and dependencies. The fixed Swift/platform policy applies
to every ticket and is repeated in tickets where toolchain or platform behavior
is relevant. Where a regression is observable on the reviewed revision, the
ticket requires a test that fails before the fix.

## Hierarchy

Each component-remediation leaf has exactly one native component parent.
Cross-component interests are represented with labels and dependencies instead
of multiple parents. Final audit #52 and post-audit publication #51 are the two
intentional exceptions: both are direct children of top-level epic #59.

### [#53: Encoder and string correctness](https://github.com/plx/hdxl-xpc-coding/issues/53)

- [#7](https://github.com/plx/hdxl-xpc-coding/issues/7) — bijective percent
  escaping for strings and dictionary keys;
- [#10](https://github.com/plx/hdxl-xpc-coding/issues/10) — referencing-encoder
  container reuse;
- [#12](https://github.com/plx/hdxl-xpc-coding/issues/12) — immutable,
  container-relative encoding paths;
- [#14](https://github.com/plx/hdxl-xpc-coding/issues/14) — user-error
  preservation and codec-originated error normalization.

### [#54: Decoder safety and Codable semantics](https://github.com/plx/hdxl-xpc-coding/issues/54)

- [#8](https://github.com/plx/hdxl-xpc-coding/issues/8) — alignment-safe
  numeric decoding;
- [#9](https://github.com/plx/hdxl-xpc-coding/issues/9) — decoder resource
  budgets and cycle resistance;
- [#13](https://github.com/plx/hdxl-xpc-coding/issues/13) — captured unkeyed
  decoding paths;
- [#15](https://github.com/plx/hdxl-xpc-coding/issues/15) — missing-key
  `decodeNil(forKey:)` behavior;
- [#16](https://github.com/plx/hdxl-xpc-coding/issues/16) — strict malformed
  UTF-8 rejection;
- [#18](https://github.com/plx/hdxl-xpc-coding/issues/18) — documented
  `DecodingError` taxonomy.

### [#55: Wire format, binary transport, and performance](https://github.com/plx/hdxl-xpc-coding/issues/55)

- [#11](https://github.com/plx/hdxl-xpc-coding/issues/11) — safe
  pointer/count contracts;
- [#19](https://github.com/plx/hdxl-xpc-coding/issues/19) — reproducible
  release-mode benchmarks;
- [#20](https://github.com/plx/hdxl-xpc-coding/issues/20) — single-object
  ordinary `Data` encoding;
- [#22](https://github.com/plx/hdxl-xpc-coding/issues/22) — same-build XPC
  object-representation contract;
- [#23](https://github.com/plx/hdxl-xpc-coding/issues/23) — efficient,
  checked XPC numeric representations;
- [#24](https://github.com/plx/hdxl-xpc-coding/issues/24) — closed not
  planned after the maintainer selected application-owned message dictionaries
  instead of a library version envelope;
- [#25](https://github.com/plx/hdxl-xpc-coding/issues/25) — bidirectional
  same-build structural fixtures;
- [#26](https://github.com/plx/hdxl-xpc-coding/issues/26) — real,
  same-build cross-process request/reply tests;
- [#32](https://github.com/plx/hdxl-xpc-coding/issues/32) — removal of
  redundant decoder zero-filling;
- [#33](https://github.com/plx/hdxl-xpc-coding/issues/33) — removal of the
  passthrough key pre-scan.

### [#56: Public API and concurrency](https://github.com/plx/hdxl-xpc-coding/issues/56)

- [#17](https://github.com/plx/hdxl-xpc-coding/issues/17) — value-semantic
  enhanced-container mutations;
- [#21](https://github.com/plx/hdxl-xpc-coding/issues/21) — authoritative,
  copy-independent codec configuration;
- [#27](https://github.com/plx/hdxl-xpc-coding/issues/27) — public and
  recursively propagated `userInfo`;
- [#28](https://github.com/plx/hdxl-xpc-coding/issues/28) — safely shareable
  immutable codec;
- [#29](https://github.com/plx/hdxl-xpc-coding/issues/29) — black-box public
  client tests;
- [#30](https://github.com/plx/hdxl-xpc-coding/issues/30) — public,
  consistent standard/default construction;
- [#31](https://github.com/plx/hdxl-xpc-coding/issues/31) — measured inlining
  and resilience audit.

### [#57: Verification, tooling, and CI](https://github.com/plx/hdxl-xpc-coding/issues/57)

- [#37](https://github.com/plx/hdxl-xpc-coding/issues/37) — reproducible local
  API-documentation generation;
- [#38](https://github.com/plx/hdxl-xpc-coding/issues/38) — complete public
  and unsafe-contract documentation;
- [#39](https://github.com/plx/hdxl-xpc-coding/issues/39) — strict
  `swift-format` gate;
- [#40](https://github.com/plx/hdxl-xpc-coding/issues/40) — strict SwiftLint
  configuration and failure propagation;
- [#41](https://github.com/plx/hdxl-xpc-coding/issues/41) — removal or real
  implementation of `HEAVY_VALIDATION`;
- [#42](https://github.com/plx/hdxl-xpc-coding/issues/42) — exact assertions
  replacing 69 known issues;
- [#43](https://github.com/plx/hdxl-xpc-coding/issues/43) — deterministic
  property and hostile-input fuzz testing;
- [#44](https://github.com/plx/hdxl-xpc-coding/issues/44) — focused GitHub
  Actions build/test coverage;
- [#45](https://github.com/plx/hdxl-xpc-coding/issues/45) — CI quality, API,
  coverage, and test-summary enforcement;
- [#46](https://github.com/plx/hdxl-xpc-coding/issues/46) — independent ASan,
  UBSan, and TSan jobs.

### [#58: Publication, licensing, and governance](https://github.com/plx/hdxl-xpc-coding/issues/58)

- [#34](https://github.com/plx/hdxl-xpc-coding/issues/34) — codified Swift 6.3
  and Apple platform 26+ policy;
- [#35](https://github.com/plx/hdxl-xpc-coding/issues/35) — upstream license
  and attribution provenance;
- [#36](https://github.com/plx/hdxl-xpc-coding/issues/36) — complete and
  accurate README;
- [#47](https://github.com/plx/hdxl-xpc-coding/issues/47) — API baselines,
  changelog, and release discipline;
- [#48](https://github.com/plx/hdxl-xpc-coding/issues/48) — security policy
  and repository controls;
- [#49](https://github.com/plx/hdxl-xpc-coding/issues/49) — maintainable
  contributor and issue metadata;
- [#50](https://github.com/plx/hdxl-xpc-coding/issues/50) — required checks
  protecting `main`;
- [#60](https://github.com/plx/hdxl-xpc-coding/issues/60) — pre-audit Swift
  Package Index metadata preparation and validation.

### Direct children of the top-level epic

- [#52](https://github.com/plx/hdxl-xpc-coding/issues/52) executes the
  independent post-remediation audit after all component epics close.
- [#51](https://github.com/plx/hdxl-xpc-coding/issues/51) publishes the
  audited semantic release and submits it to Swift Package Index after the
  audit passes.

These two tickets are deliberately not children of the publication epic.
Making the audit a child of an epic that it blocks would create a cycle.

## Semantic label vocabulary

Labels are namespaced so queries can combine independent dimensions.

### Program

- `program:production-readiness` — work originating in the 2026 audit.

### Type

Exactly one:

- `type:epic`;
- `type:defect`;
- `type:hardening`;
- `type:design`;
- `type:testing`;
- `type:documentation`;
- `type:tooling`;
- `type:release`.

### Priority

Exactly one:

- `priority:p0` — immediate corruption, data-loss, crash, unsafe-behavior,
  foundational-compatibility, or legal-provenance blocker;
- `priority:p1` — required before a production-ready release;
- `priority:p2` — important hardening before stable 1.0 or broad adoption;
- `priority:p3` — worthwhile cleanup or maintainability work.

Priority and dependency are independent. Choose ready work from the highest
priority whose blockers are closed.

### Domain

One or more:

- `domain:correctness`;
- `domain:safety`;
- `domain:performance`;
- `domain:api`;
- `domain:compatibility`;
- `domain:quality`;
- `domain:release`;
- `domain:security`.

### Component

One or more:

- `component:strings`;
- `component:encoder`;
- `component:decoder`;
- `component:codec`;
- `component:binary-data`;
- `component:wire-format`;
- `component:transport`;
- `component:concurrency`;
- `component:tests`;
- `component:tooling`;
- `component:ci`;
- `component:documentation`;
- `component:repository`;
- `component:licensing`.

### Effort

Exactly one:

- `effort:small`;
- `effort:medium`;
- `effort:large`.

### Release state

- `release:blocker` — substantive work that must close before a
  production-ready declaration; orchestration tickets #52 and #59 necessarily
  remain open while the final audit runs, but #52 may close only on `GO`;
- `target:0.1.0` — intended for the deliberate preview release;
- `target:1.0` — required before stable compatibility commitments.

The program intentionally completes every audited finding before #52. Thus a
`target:1.0` leaf remains a blocker when it is pulled into a component epic;
the target describes the latest release horizon, not permission to close an
epic with that child open.

## Native dependency graph

An arrow means the ticket on the left is blocked by the tickets on the right.
These relationships were created through GitHub's native issue-dependency API;
the live relationships are authoritative.

```text
#14 <- #12
#17 <- #11
#18 <- #7, #8, #9, #13, #15, #16
#20 <- #19, #22
#23 <- #8, #22
#25 <- #7, #20, #22, #23
#26 <- #7, #20, #22, #23
#27 <- #10, #21
#28 <- #8, #21
#30 <- #7, #21, #29
#31 <- #17, #19, #21, #27, #28, #30
#32 <- #16, #19
#33 <- #7, #19
#36 <- #7, #9, #11, #29, #34, #35, #47
#37 <- #34
#38 <- #11, #37, #40, #56
#43 <- #7, #8, #9, #11, #16, #20, #22, #23
#44 <- #34
#45 <- #29, #37, #38, #39, #40, #41, #42, #44, #47
#46 <- #8, #9, #11, #28, #44
#47 <- #23, #31, #35
#49 <- #48
#50 <- #44, #45, #46
#51 <- #52, #60
#52 <- #53, #54, #55, #56, #57, #58
#60 <- #34, #37
```

The graph was checked at creation and was acyclic across the 53 issues incident
to dependency edges. Top-level parent #59 is the program's one issue without a
dependency edge.

## Burn-down procedure

1. Filter open issues by `program:production-readiness`.
2. Ignore epics when selecting implementation work.
3. Select the highest-priority leaf with no open native blockers.
4. Read the complete ticket and all linked prerequisite decisions.
5. Add the required pre-fix regression or negative control.
6. Implement only the ticket's bounded outcome.
7. Run the ticket-specific checks and the proportionate full-suite checks.
8. Put exact commands, observed before/after behavior, and artifact links in
   the pull request.
9. Close the leaf only after its acceptance criteria are met.
10. Close a component epic only when all native children are closed and its
    combined validation passes.
11. Run #52 against an immutable candidate after all six component epics close.
12. Proceed to #51 only after the audit records a `GO` decision; create the
    immutable semantic tag and GitHub Release there before submitting them to
    Swift Package Index.

Parallel work is encouraged when blockers permit it. The dependency graph
orders prerequisites; it is not intended to serialize unrelated components.

## Maintaining issue quality

New findings added to this program should:

- be independently actionable;
- identify the observable problem and impact;
- cite relevant code or repository state;
- describe the required outcome without prescribing an unjustified rewrite;
- require a pre-fix failing test or negative control where possible;
- state exact validation and acceptance criteria;
- identify scope constraints and compatibility implications;
- use one type, one priority, one effort, and relevant domain/component labels;
- have exactly one native parent;
- use native `blocked by` relationships only for real prerequisites.

If remediation changes the public API, same-build XPC object representation,
application-owned transport boundary, or release order, update the relevant
issue, this index, and the final audit procedure together.
