# Post-Remediation Production-Readiness Audit

## Purpose

This document defines the audit that must be performed after the
production-readiness issue program is complete. Its purpose is to determine,
with reproducible evidence, whether `XPCCoding` is suitable for production use
outside toy, hobby, and experimental prototypes.

The issue hierarchy and its native dependency graph are recorded in
[Production-Readiness Issue Program](ProductionReadinessIssueProgram.md). The
audit must use the live GitHub state as authoritative and reconcile any drift
from that point-in-time index before beginning.

This is not a regression-test checklist that can be satisfied by observing a
green GitHub check mark. It is an independent attempt to falsify the package's
correctness, safety, performance, compatibility, and release claims.

The output must be a dated audit report tied to an immutable commit or release
candidate. The report must use exactly one of these machine-significant verdict
tokens:

- **`GO`:** suitable for the documented production envelope;
- **`CONDITIONAL GO`:** suitable only with explicitly documented
  restrictions;
- **`NO-GO`:** unsuitable for production use.

Silence, missing evidence, skipped checks, tolerated crashes, or unexplained
known issues count against release.

## Fixed support policy

Unless the maintainer separately changes policy, audit against:

- Swift **6.3** as the exact supported language/toolchain version, without
  implying support for earlier or later Swift versions;
- macOS **26+**;
- iOS **26+**;
- Mac Catalyst **26+**;
- SwiftPM distribution;
- Apple XPC as the transport representation.

Do not expand the deployment or toolchain matrix during this audit. Verify that
the manifest, CI, README, and package behavior consistently describe this
intentional support envelope.

## Auditor independence

Prefer an auditor who did not implement most of the remediation work. If an
independent person or agent is unavailable:

1. start from a fresh clone with no build artifacts;
2. do not rely on implementation notes as proof;
3. reproduce every result from public APIs where possible;
4. design at least one new adversarial test per high-risk component;
5. record commands, inputs, outputs, timing, and failures verbatim.

## Required audit artifact

Create a dated Markdown report containing:

- repository URL;
- commit SHA and proposed version/tag name; do not create the final immutable
  semantic tag before the audit reaches a go decision;
- audit start/end dates;
- machine architecture and OS version;
- Xcode and complete `swift --version` output;
- every command executed;
- summaries and links to complete logs;
- benchmark hardware and run methodology;
- discovered defects with severity and reproduction;
- accepted limitations;
- final go/conditional-go/no-go decision;
- names or identities of reviewers.

Store large logs as CI artifacts or durable release artifacts. Do not paste
secrets, access tokens, signing material, or private XPC payloads into the
repository.

## Phase 0: Establish an immutable candidate

1. Start from a fresh clone of the candidate branch.
2. Confirm no ignored or untracked source influences the build.
3. Record:

   ```sh
   git status --short
   git rev-parse HEAD
   git describe --tags --always --dirty
   git submodule status
   swift --version
   xcodebuild -version
   uname -a
   ```

4. Confirm the candidate commit is reachable from the proposed PR or release
   branch.
5. Confirm component epics #53 through #58 and all of their native leaf
   sub-issues are closed. Inspect native blocked-by relationships; do not
   accept an epic closed with open sub-issues. The current audit ticket (#52)
   and post-audit publication ticket (#51) are expected to remain open.
6. Search for unresolved release markers:

   ```sh
   rg -n --hidden \
     --glob '!.git/**' \
     --glob '!.build/**' \
     --glob '!DerivedData/**' \
     --glob '!vendor/**' \
     'TODO|FIXME|TBD|HACK|known issue|withKnownIssue|XCTExpectFailure' .
   ```

7. Triage every result. A marker is not automatically a defect, but every
   remaining result must have an explicit disposition in the audit report.

## Phase 1: Manifest and public-surface verification

### Toolchain and platform contract

Verify:

- `// swift-tools-version` expresses Swift 6.3;
- the language mode is Swift 6;
- platforms remain macOS 26, iOS 26, and Catalyst 26;
- there are no accidental dependencies or unsafe SwiftPM flags;
- the package name, product name, and module name match documentation.

Run:

```sh
swift package dump-package
swift package describe
swift package show-dependencies
```

Compile all declared platforms using the pinned Swift 6.3/Xcode toolchain.
Record the complete `swiftc` or `xcodebuild` invocation and destination. A
successful host-macOS build alone is insufficient.

### Black-box consumer

Build a separate fixture package that depends on the candidate by local path or
immutable revision and uses only:

```swift
import XPCCoding
```

It must compile representative public usage for:

- the standard codec;
- custom string strategies;
- direct `XPCEncoder` and `XPCDecoder`;
- `userInfo`;
- enhanced binary-data APIs;
- supported shared-concurrency use;
- an arbitrary root value and a transport-ready dictionary envelope.

No fixture may use `@testable`, `@_spi`, source-relative imports, or internal
symbols.

### API compatibility

Choose the intended compatibility baseline and run:

```sh
swift package diagnose-api-breaking-changes <baseline-tag-or-revision>
```

Review generated symbol graphs and all globally-added extensions on standard
library protocols. Confirm:

- every public symbol is intentional;
- naming and default visibility are coherent;
- unsafe APIs have explicit contracts;
- `@inlinable` and `@usableFromInline` appear only where justified;
- all intentional breaks appear in the changelog and migration notes.

Any unreviewed public break is a no-go.

## Phase 2: Deterministic build and unit validation

From a clean build directory, run at minimum:

```sh
swift package clean
swift build -Xswiftc -warnings-as-errors
swift test
swift test -c release
```

Then run the repository's aggregate quality command.

Requirements:

- no build warnings;
- zero failed tests;
- zero unexplained skipped tests;
- zero `withKnownIssue` or equivalent tolerated failures;
- debug and release results agree;
- all `just` or script recipes return nonzero when their underlying tool fails.

Test the last property by temporarily introducing a formatting, lint, test, and
documentation error in a disposable worktree. Confirm each corresponding
quality command fails. Remove the disposable worktree afterward.

## Phase 3: String and key correctness

Exercise every supported key and value strategy across:

- top-level single values;
- keyed containers;
- unkeyed containers;
- nested keyed and unkeyed containers;
- superclass encoders/decoders;
- dictionary `allKeys`, `contains`, and lookup.

The corpus must include:

```text
""
"plain"
"%"
"%0"
"%00"
"%25"
"%41"
"%GG"
"100%"
"a%20b"
"a%00b"
"a\0b"
"%\u{301}"
"x%\u{301}41"
leading, trailing, and repeated NULs
ASCII, BMP, supplementary-plane, decomposed, and composed Unicode
```

For an escaping strategy, prove injectivity:

1. generate a large corpus of arbitrary Swift strings;
2. encode each string to its XPC representation;
3. assert distinct inputs do not produce the same representation;
4. decode and assert exact scalar-for-scalar equality.

For keys, generate dictionaries containing pairs that historically collided,
including `%00` and literal NUL. Verify entry count, `allKeys`, lookup, and
decoded values.

For `.assumeAbsent`, verify exact documented lossy behavior. It must not be
represented as a passing known issue.

Malformed XPC string bytes must produce a documented error without replacement
characters, truncation, crashes, or inaccessible internal errors.

## Phase 4: Numeric and binary representation

### Alignment

For every binary-backed primitive:

- construct correctly sized data at offsets from 0 through at least
  `MemoryLayout<T>.alignment`;
- create XPC data whose visible bytes begin at each offset;
- inspect `xpc_data_get_bytes_ptr` and prove its address is actually misaligned
  for `T` before counting a case as alignment coverage;
- decode through the public facade;
- compare exact value and bit pattern.

If libxpc copies or coalesces an offset source into aligned storage, use
offset-backed `DispatchData`, repeated construction, or another controlled
fixture. Set a finite attempt budget before running—for example, 10,000
constructions per method—and record every method, budget, and pointer
remainder. If no actually misaligned pointer is observed, stop at the budget
instead of retrying indefinitely and record the coverage gap. A go then
requires static and dynamic evidence that no supported path performs an
alignment-requiring load; inability to construct the historical condition is
not itself a passing result.

Run these probes in subprocesses so a regression trap is reported as a test
failure rather than terminating the suite.

### Length and type corruption

For every primitive, exercise:

- zero-length data;
- every length shorter than required;
- every length up to several bytes longer than required;
- the wrong XPC object type;
- numeric extremes, signed zero, infinities, NaNs, and representative NaN
  payloads where the contract preserves bit patterns.

All invalid inputs must throw the documented `DecodingError`; none may trap or
silently reinterpret data.

### Checked numeric conversions

For every narrow signed and unsigned integer type, manually construct every
scalar XPC input kind permitted by the accepted wire contract. For a contract
using `XPC_TYPE_INT64` and `XPC_TYPE_UINT64`, exercise:

- the exact minimum and maximum;
- one representable value inside each boundary;
- one value immediately outside each boundary when the source XPC type can
  express it;
- the opposite signedness, including negative-to-unsigned and unsigned values
  greater than the signed maximum.

For `Float16` and `Float`, construct inputs in every scalar kind permitted by
the accepted contract—such as `XPC_TYPE_DOUBLE` if that mapping is adopted—
covering exact and inexact finite values, overflow, underflow, signed zero,
infinities, NaNs, and values outside the finite destination range. Verify the
canonical contract's accepted conversions and require a documented
corruption/range error for every rejected conversion. No integer or floating
conversion may truncate, wrap, or silently clamp.

### Wire shape

For every Swift primitive and standard-library type supported by the package:

1. encode a representative value;
2. assert the exact XPC type;
3. assert byte order and exact bytes where applicable;
4. compare to the frozen golden fixture;
5. decode fixtures produced by every release covered by the compatibility
   policy.

Fixtures must be reviewed data, not regenerated immediately before comparison.

## Phase 5: `Data` and unsafe-buffer APIs

### `Data` representation

For sizes 0, 1, 16, 1 KiB, 4 KiB, 64 KiB, 1 MiB, and the maximum documented
payload:

- assert ordinary `Data` encodes as exactly one `XPC_TYPE_DATA`;
- verify top-level, keyed, unkeyed, nested, and superclass positions;
- verify exact bytes after decoding;
- record encoded XPC description/size where a stable metric exists;
- measure allocations and throughput.

No per-byte XPC-object growth is acceptable.

### Decoded-value ownership

Decode `Data` and each data-backed string representation, release every strong
reference to the source XPC object, churn allocations, and then verify the
returned Swift values remain byte-for-byte valid. Repeat under ASan. This must
prove the optimized extraction path owns its result rather than borrowing
storage from a released XPC object.

### Pointer/count contract

Test, in subprocesses:

- `(nil, 0)`;
- `(nil, positive)`;
- `(nil, negative)`;
- `(nonnull, 0)`;
- `(nonnull, negative)`;
- valid initialized storage.

A raw pointer carries no extent metadata, so the current API cannot verify that
its allocation is shorter than a claimed positive count. Do not deliberately
pass such an invalid buffer to libxpc. Add a guarded negative test only if the
final API introduces enforceable extent metadata; otherwise verify this
boundary by API-contract review. Separately confirm the public documentation
makes initialized, readable backing storage for the full count an explicit
caller precondition.

Verify XPC-native and generic fallback containers implement the same documented
semantics.

### Value-semantic enhanced containers

Use external struct conformers that record calls and data in stored value
properties. Exercise every public enhanced wrapper—not just direct protocol
witnesses—and confirm mutations are preserved.

## Phase 6: Codable semantic conformance

Build adversarial custom `Encodable` and `Decodable` fixtures that directly
exercise protocol semantics rather than synthesized conformance.

Verify:

- repeated same-kind container requests retain previous data;
- invalid container-kind transitions have the documented behavior;
- every explicit nested container reports its full immutable coding path;
- keyed, unkeyed, single-value, superclass, and referencing paths agree;
- user-thrown errors preserve the documented identity;
- XPCCoding-originated errors use public standard error types;
- `decodeNil(forKey:)` distinguishes missing, explicit null, and non-null;
- `contains`, `allKeys`, `decodeIfPresent`, and direct decode agree;
- root encodes that perform no work throw;
- partial child failures do not corrupt or unexpectedly mutate the parent;
- `userInfo` reaches root, nested, collection, and superclass coders.

Compare behavior to `JSONEncoder` and `JSONDecoder` where the `Codable`
protocol defines analogous semantics. Document intentional differences.

## Phase 7: Hostile-input and resource-budget audit

All hostile-input cases must run with wall-clock and memory limits in a
subprocess.

Test:

- nesting at `limit - 1`, `limit`, and `limit + 1`;
- breadth and total-node counts around their limits;
- empty cycles and cycles containing values;
- repeated references that are not cycles;
- strings and data around every configured byte limit;
- aggregate inputs where individually small values exceed a total budget;
- malformed dictionaries, arrays, nulls, and type substitutions;
- very large key sets;
- decoding cancellation or timeout behavior if supported.

Acceptance requirements:

- within-limit input has deterministic behavior;
- over-limit input throws a documented error;
- no stack overflow, abort, segmentation fault, hang, runaway allocation, or
  recursion proportional to attacker-controlled depth occurs;
- limits are shared across child decoders and cannot be reset by nesting;
- error coding paths remain bounded and useful.

Run property-based and mutation fuzzing over arbitrary XPC graphs. Seed the
corpus with every historical reproducer from the due-diligence report. Persist
all newly discovered minimal reproducers.

## Phase 8: Real XPC transport integration

In-memory `xpc_object_t` round trips are insufficient. Create a real test
service or listener/endpoint fixture that:

- sends a request through an XPC connection;
- receives and decodes it in another process or service context;
- encodes and returns a reply;
- verifies error propagation and interruption handling;
- uses the documented dictionary envelope required by XPC transport;
- covers empty, representative, maximum-size, and malformed payloads;
- confirms ownership/lifetime behavior after send and reply;
- verifies selected string configurations and the canonical wire format.

Where iOS or Catalyst cannot run the same service topology, perform the
strongest supported compile or integration check and document the platform
constraint precisely.

Transport integration must use public package APIs and the same entitlement or
service assumptions documented for users.

## Phase 9: Concurrency and lifetime audit

Compile a separate Swift 6.3 strict-concurrency client that exercises the
documented shared-value model.

If coders/codecs are intended to be shareable:

- share one instance across a task group;
- mix encode and decode operations;
- use diverse payload shapes;
- run thousands of iterations;
- run under Thread Sanitizer;
- verify configuration cannot mutate or race during an operation.

Repeat that shared-instance test for several immutable codec configurations.
Never mutate one shared instance's strategies while its tasks are running.

Independently verify codec configuration ownership:

- copies of one codec share no mutable coder or operation state;
- repeated encoder/decoder factory calls return distinct facade instances with
  identical initial configuration;
- mutating a factory-produced coder cannot alter later codec operations or a
  sibling factory result;
- concurrent operations use immutable configuration snapshots.

If they are intentionally not shareable, verify the compiler rejects sharing
and ensure documentation clearly requires per-task instances.

Also inspect:

- retain cycles involving referencing encoders;
- lifetime of XPC objects returned from transient encoders;
- lifetime and copy semantics of raw buffers passed to XPC;
- repeated autorelease-pool behavior for large workloads;
- memory growth across long encode/decode loops.

Unexpected unbounded resident-memory growth is a no-go.

## Phase 10: Sanitizers and dynamic analysis

Run the complete suite under:

```sh
swift test --sanitize=address
swift test --sanitize=thread
swift test --sanitize=undefined
```

Use the supported equivalent commands if SwiftPM syntax differs in the pinned
toolchain. Record exact invocations.

Requirements:

- no sanitizer diagnostics;
- no unexpected signals;
- no disabled high-risk test groups;
- subprocess crash tests distinguish expected enforcement from runtime memory
  faults.

Where practical, also run Instruments or equivalent tooling for:

- leaks;
- allocations;
- time profiling;
- retained XPC graphs.

## Phase 11: Performance and scalability

### Method

Use an otherwise-idle machine, release builds, fixed CPU/power conditions, and
enough warm-up and measured iterations to produce stable distributions.
Record:

- hardware and OS;
- exact commit;
- compiler flags;
- sample count;
- median, p90, p95, and p99;
- standard deviation or confidence interval;
- allocations and peak resident memory;
- encoded payload size or object count.

Do not compare a debug candidate to a release baseline.

### Workloads

Benchmark:

- scalar primitives;
- `Data` from empty through at least 1 MiB;
- strings with no escaping, many percent signs, many NULs, and non-ASCII text;
- small and large dictionaries;
- flat and deeply nested models;
- arrays of primitives and models;
- successful and failing decoding;
- direct-pointer APIs versus ordinary `Data`;
- real XPC send/reply latency where stable enough to measure.

### Acceptance

Define thresholds before viewing the final result. At minimum:

- `Data` must exhibit O(1) XPC-object count;
- time and memory must scale approximately linearly with payload size;
- no unexplained order-of-magnitude regression against the recorded baseline;
- performance claims in documentation must be supported by measured results.

## Phase 12: Coverage and test-quality review

Generate source coverage:

```sh
swift test --enable-code-coverage
```

Use the pinned toolchain's `llvm-cov` to produce per-file line, region, and
function reports.

Coverage percentage is supporting evidence, not the acceptance criterion.
Inspect uncovered branches in:

- unsafe-pointer paths;
- all error conversions;
- referencing encoders;
- container state transitions;
- resource budgets;
- strategy switches;
- malformed-input paths.

Mutation-test or manually invert selected guards to confirm tests fail. At a
minimum, mutate:

- literal-percent escaping;
- alignment-safe load choice;
- depth-limit comparison;
- `Data` fast-path dispatch;
- missing-key nil behavior;
- referencing-container reuse.

A test suite that remains green after one of those mutations is insufficient.

## Phase 13: Tooling and CI audit

Verify the repository has required checks for:

- Swift 6.3 debug build/test;
- Swift 6.3 release build/test;
- macOS 26 build/test;
- iOS 26 compile;
- Catalyst 26 compile;
- strict formatting;
- strict linting;
- API documentation generation/checking;
- API compatibility;
- sanitizers;
- coverage or an archived coverage artifact;
- transport integration where feasible.

This may be multiple jobs using one intentionally small toolchain/platform
baseline. A broad historical-version matrix is not required.

Inspect workflow security:

- explicit least-privilege `permissions`;
- reviewed immutable action SHAs;
- checkout credentials not persisted when unnecessary;
- no secrets available to untrusted pull-request code;
- deterministic caches;
- required checks enforced on the default branch.

Re-run the workflow from a clean branch and inspect logs, not only status
conclusions.

## Phase 14: Documentation, legal, and release audit

### User and API documentation

Confirm the README includes:

- correct package and product names;
- SwiftPM installation;
- Swift 6.3 and platform 26+ policy;
- a compiling minimal example;
- codec configuration;
- XPC dictionary-envelope/transport requirements;
- concurrency model;
- wire-compatibility policy;
- unsafe-pointer preconditions;
- decoder limits;
- stability and semantic-versioning policy;
- security reporting;
- license and upstream attribution.

Compile every code sample through a black-box documentation test.

Generate public API documentation with the documented command and fail on
missing public documentation. The static website remains a separate concern.

### Licensing and provenance

Have a qualified reviewer confirm:

- the root license is complete;
- the upstream Runtime Library Exception is handled correctly;
- source-derived files retain required notices;
- modified-file notices satisfy the chosen compliance interpretation;
- third-party attribution is complete;
- no generated or copied test fixture has incompatible terms.

Record the decision. “GitHub recognizes the license” is not a legal audit.

### Release mechanics

Verify:

- changelog and migration notes;
- a clean-clone dry-run that prepares the exact candidate tag and release
  artifacts without publishing them;
- a procedure for annotated, preferably signed, tags;
- proposed GitHub Release notes tied to the audited candidate;
- reproducible SwiftPM dependency resolution;
- API-diff baseline;
- security and contribution policies;
- default-branch protection and required checks;
- committed `.spi.yml` syntax, real package/documentation targets, and exact
  Swift 6.3 / Apple 26+ claims;
- the Package Index metadata negative-control command, including proof that
  stale or malformed metadata fails;
- confirmation that no semantic tag, GitHub Release, or Package Index
  submission occurred before the audit decision;
- no credentials or private data in the repository history.

Actual semantic tagging, GitHub Release publication, and Swift Package Index
submission occur only after a go decision, through post-audit publication
ticket #51. They are not prerequisites for this audit and must not be performed
speculatively to make this phase pass.

## `GO`/`NO-GO` rubric

### Automatic no-go conditions

Any one of the following requires a no-go:

- reproducible silent corruption or field loss;
- process crash, abort, stack exhaustion, hang, or runaway allocation from an
  input outside a clearly documented programmer precondition;
- sanitizer diagnostic;
- known failing or tolerated test;
- wire fixture incompatibility within the promised compatibility window;
- unsafe API without an enforceable and documented contract;
- unresolved substantive P0 or P1 remediation finding;
- unreviewed public API break;
- absent or unresolved licensing/provenance decision;
- quality or CI gate that reports success after its underlying tool fails;
- missing real-transport validation for claims that depend on transport.

### Conditional-go examples

A conditional go may be appropriate when:

- a platform supports compilation but not the full service topology, and that
  limitation is precise and documented;
- wire compatibility is intentionally limited to identical package versions
  and configuration, with enforcement or a clear envelope;
- coders are intentionally non-shareable and the compiler/documentation enforce
  per-task use.

Conditions must describe how callers remain safe. They cannot merely defer a
known corruption or crash.

A conditional-go or no-go report does not close audit ticket #52 and does not
unblock publication. Represent every remaining condition or finding as a
native blocker, remediate it, and rerun the affected audit phases until the
candidate earns a go decision.

### Go requirements

A go requires:

- every required phase completed with retained evidence;
- all automated checks passing without tolerated failures;
- no open substantive release blockers; orchestration tickets #52 and #59 may
  remain open only because the audit is executing and post-audit publication
  has not yet occurred;
- public API examples compiling as an external consumer;
- hostile input producing bounded errors;
- stable, reviewed wire fixtures;
- real XPC transport success;
- acceptable and documented performance;
- reviewed licensing and release metadata;
- explicit approval from the maintainer and auditor.

## Suggested final report outline

```text
# XPCCoding Production-Readiness Audit — <date>

## Candidate
- repository
- SHA/tag
- Swift/Xcode/OS/hardware

## Decision
- GO / CONDITIONAL GO / NO-GO
- supported production envelope
- conditions or blockers

## Executive evidence
- deterministic tests
- adversarial tests
- sanitizers
- transport
- compatibility
- performance
- tooling/CI
- legal/release

## Findings
- severity
- reproduction
- impact
- disposition

## Commands and artifacts
- commands
- logs
- fixtures
- benchmark outputs

## Sign-off
- auditor
- maintainer
- date
```
