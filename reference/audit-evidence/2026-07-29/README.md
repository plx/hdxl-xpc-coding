# Production-Readiness Audit Evidence — 2026-07-29

This directory retains the evidence that was produced outside the repository's
hosted CI jobs while auditing source commit
`8dab29a230817c3911a2a8e48467c49a9c0a2604`. The dated
[audit report](../../ProductionReadinessAudit-2026-07-29.md) links the hosted
jobs and explains the method, results, limitations, and verdict.

The evidence files are plain text or JSON so a reviewer can inspect them
without a proprietary archive tool. Build products, scratch directories,
documentation archives, and redundant hosted-CI transcripts are deliberately
excluded.

For repository storage, the copied text transcripts normalize line endings,
remove trailing horizontal whitespace, and end with one newline. The
substantive command output is otherwise unchanged; the original audit
artifacts remain in the audit workspace.

## Index

### Command record

- [Timestamped command log](command-log.txt)

### Phase 2: fail-closed quality controls

- [Formatting failure control](phase-02-format-failure-control.txt)
- [Lint failure control](phase-02-lint-failure-control.txt)
- [Test failure control](phase-02-test-failure-control.txt)
- [Documentation failure control](phase-02-documentation-failure-control.txt)

Each control used a detached worktree of the exact candidate, recorded its
single deliberate fixture change, and required the corresponding gate to
return a nonzero status. The wrapper itself returned success only after
observing that expected failure.

### Phases 3–9: external public-API checks

- [External probe package manifest](IndependentAdversarial.Package.swift.txt)
- [External probe source](IndependentAdversarial.main.swift.txt)
- [Final external probe output](phase-03-09-independent-public-api-probe.txt)
- [Value-lifetime probe package manifest](ValueLifetimeProbe.Package.swift.txt)
- [Value-lifetime probe source](ValueLifetimeProbe.main.swift.txt)
- [Address-instrumented value-lifetime output](phase-05-value-lifetime-address-instrumented.txt)
- [Bounded-input output](phase-07-bounded-inputs.txt)
- [Representative XPC payload](phase-08-xpc-representative-payload.txt)
- [Empty XPC payload](phase-08-xpc-empty-payload.txt)
- [Maximum-size XPC payload](phase-08-xpc-maximum-payload.txt)
- [Instrumented 8,000-operation concurrency run](phase-09-external-concurrency-instrumented.txt)
- [Resident-growth probe package manifest](ResidentGrowthProbe.Package.swift.txt)
- [Resident-growth probe source](ResidentGrowthProbe.main.swift.txt)
- [Resident-growth JSON](phase-09-resident-growth.json)
- [Resident-growth build and output](phase-09-resident-growth.txt)

The empty and maximum-size transport runs changed only the external fixture's
compile-time payload-size constant. Each transcript requires a clean index, no
untracked files, and exactly that one changed path before executing.

The value-lifetime probe ends the source-object scope before allocation churn
and validates exact `Data`, UTF-8, UTF-16, and UTF-32 results under address
instrumentation. The resident-growth probe runs 2,560 large mixed
encode/decode operations in per-operation autorelease pools, samples physical
footprint and live default-zone allocations after every batch, and evaluates
predeclared bounds.

### Phase 10: prerelease-host observation

- [Focused prerelease-host transcript](phase-10-prerelease-host-observation.txt)

The authoritative supported-lane runtime-instrumentation logs remain linked
from the report's phase-10 section.

### Phase 11: performance and allocations

- [Complete benchmark JSON](phase-11-complete-release-benchmark.json)
- [Complete benchmark command/output](phase-11-complete-release-benchmark.txt)
- [Epic-55 same-machine baseline JSON](phase-11-epic55-baseline-benchmark.json)
- [Same-machine comparison](phase-11-same-machine-comparison.txt)
- [Process resource sample](phase-11-release-resource-sample.txt)
- [Decode-timing probe package manifest](DecodeTimingProbe.Package.swift.txt)
- [Decode-timing probe source](DecodeTimingProbe.main.swift.txt)
- [Decode-timing JSON](phase-11-decode-timing.json)
- [Decode-timing command/output](phase-11-decode-timing.txt)
- [Allocation probe package manifest](AllocationProbe.Package.swift.txt)
- [Allocation probe source](AllocationProbe.main.swift.txt)
- [Allocation and throughput output](phase-11-data-allocation-and-throughput.txt)

The allocation probe uses public XPCCoding API and
`malloc_zone_statistics(malloc_default_zone(), ...)` around one retained encode
and decode. It reports signed deltas in live allocation blocks and bytes; it
does not claim to count transient allocator events.

### Phases 12 and 14

- [Regression-first baseline evidence](phase-12-regression-baseline-evidence.txt)
- [Missing-key mutation control](phase-12-missing-key-mutation-control.txt)
- [Referencing-container reuse mutation control](phase-12-referencing-reuse-mutation-control.txt)
- [Coverage summary](phase-12-coverage-summary.json)
- [Coverage policy result](phase-12-coverage-policy.txt)
- [Documentation and release gates](phase-14-documentation-and-release-gates.txt)
- [Prepublication state](phase-14-prepublication-state.txt)

## Integrity

Git object hashes provide the durable integrity record after this directory is
merged. A reviewer can additionally regenerate file digests with:

```sh
find reference/audit-evidence/2026-07-29 \
  -maxdepth 1 -type f ! -name README.md \
  -exec shasum -a 256 {} +
```
