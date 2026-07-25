# XPCCoding Production-Readiness Due-Diligence Review

**Review date:** 2026-07-25\
**Reviewed revision:** `813c52e` (`origin/main` at the time of review)\
**Disposition:** Not yet suitable for production or other load-bearing use\
**Review type:** Read-only source, API, validation, release, and repository audit

## Purpose

This document preserves the findings of a broad pre-release review of
`hdxl-xpc-coding`. The review asked whether the package could responsibly be
published and recommended for use beyond toy, hobby, or experimental
prototypes.

The answer at the reviewed revision was **no**. The package has a credible
foundation and does not require a rewrite, but it has correctness, crash
resistance, performance, compatibility, and release-process defects that must
be resolved before it can be described as production-ready.

This report is a point-in-time record, not a living status page. The
[Production-Readiness Issue Program](ProductionReadinessIssueProgram.md)
records the GitHub hierarchy, labels, and dependency graph created from it.
After those issues are resolved, follow
[Post-Remediation Production-Readiness Audit](PostRemediationProductionReadinessAudit.md)
from a clean checkout and record a new go/no-go decision.

## Deliberate support policy

The following constraints are intentional and are **not** findings:

- supported Swift version: **Swift 6.3 only**;
- minimum Apple platform versions: **macOS 26, iOS 26, and Mac Catalyst 26**;
- no commitment to earlier or later Swift toolchains, or to older deployment
  targets;
- the package is an Apple-platform Swift library distributed through SwiftPM,
  not a CLI or Rust crate.

The release program should align the manifest, CI, and documentation with that
policy. It should not expand the supported matrix unless the maintainer makes a
separate decision to do so.

## Scope

The review included:

- encoder and decoder implementation correctness;
- public API semantics and Swift `Codable` substitutability;
- malformed and adversarial XPC inputs;
- memory-safety-adjacent unsafe-pointer and alignment boundaries;
- concurrency posture;
- XPC wire representation and transport assumptions;
- performance-sensitive representations;
- tests, coverage, sanitizers, formatting, linting, and API checks;
- packaging, licensing, repository policy, and release engineering.

The static documentation website and landing page were excluded. The README,
public API documentation, and API-documentation tooling were included because
they are part of the package and its release contract.

## Review environment and limitation

The recorded validation was performed on:

- Apple Swift 6.4 (`swiftlang-6.4.0.25.4`, Clang `2100.3.25.1`);
- Xcode 27.0 (`27A5218g`);
- macOS 27.0 (`26A5378n`) on Apple silicon.

Those results characterize revision `813c52e`, but they do **not** validate the
intentional Swift 6.3-only toolchain policy. Every positive build, test,
sanitizer, coverage, and platform-compile result must be reproduced with the
exact supported Swift 6.3/Xcode toolchain before release. The demonstrated
semantic defects do not depend on treating Swift 6.4 as supported.

## Executive assessment

| Area | Assessment at reviewed revision |
| --- | --- |
| Correctness | Not release-ready |
| Crash resistance | Not safe for arbitrary or hostile XPC input |
| Performance | Serious `Data` representation defect |
| API architecture | Promising, with pre-1.0 changes required |
| Wire compatibility | Undefined |
| Testing | Broad, but missing important adversarial and shape checks |
| Release engineering | Preview-quality |
| Licensing | Provenance and notice review required |

The strongest positive signal is that the codebase has a coherent facade and
internal-coder split, no third-party Swift package dependencies, strict Swift 6
checking, and a substantial test suite. The strongest negative signal is that
ordinary public-API probes reproduced silent corruption, silent field loss,
process traps, stack exhaustion, and catastrophic object amplification.

## Release-blocking findings

### DD-001: Default percent escaping is not injective

**Severity:** P0\
**Domains:** correctness, strings, wire compatibility

The default `.percentEscape` implementation only invokes its escaping
transformation when the source contains a NUL byte:

- [`String+EmbeddedNullSupport.swift`](../Sources/XPCCoding/Support/String+EmbeddedNullSupport.swift)
- [`xpc_object_t+Extraction.swift`](../Sources/XPCCoding/Decoding/Details/xpc_object_t+Extraction.swift)

Decoding nevertheless applies `removingPercentEncoding` to every string using
that strategy. Consequently, percent sequences in otherwise ordinary strings
are interpreted as encoded bytes even though the encoder did not introduce
them.

Public-API probes demonstrated:

```text
"%41"                    -> "A"
"a%00b"                  -> "a\0b"
"100%"                   -> decoding error
["a%00b": 1, "a\0b": 2] -> one XPC dictionary entry
```

The escaping implementation also iterates `Character`, so a percent scalar
joined to a combining mark can evade the literal-percent branch.

The default strategy therefore corrupts values, makes keys unfindable, and can
collapse distinct dictionary keys. This contradicts the README's central
embedded-NUL claim.

The existing test data contains no representative literal-percent cases.
Randomized keyed and unkeyed tests additionally replace `%` with `$`, preventing
the defect from being discovered.

**Required direction:**

- implement a total, bijective transform that escapes every literal `%` and
  every NUL;
- iterate Unicode scalars or UTF-8 bytes rather than `Character`;
- use exactly the same transformation for dictionary insertion and lookup;
- add values and keys containing `%`, `%00`, `%25`, `%41`, malformed escapes,
  combining marks, literal NUL, and collision pairs;
- exercise top-level, keyed, unkeyed, nested, and `allKeys` behavior.

### DD-002: Binary primitive decoding performs alignment-requiring loads

**Severity:** P0\
**Domains:** safety, decoding, binary data

Several fixed-width integer and floating-point types are encoded as native
in-memory bytes. Decoding constructs an `UnsafeRawBufferPointer` from
`xpc_data_get_bytes_ptr` and calls `baseAddress.load(as:)`:

- [`XPCBinaryDataRepresentationConvertible.swift`](../Sources/XPCCoding/Protocols/XPCBinaryDataRepresentationConvertible.swift)
- [`XPCObjectExtractable.swift`](../Sources/XPCCoding/Protocols/XPCObjectExtractable.swift)

The pointer is not verified to satisfy the Swift type's alignment. Valid XPC
data backed by offset storage reproduced a process trap. A full Thread
Sanitizer test run also stopped in this load path while decoding `Int16`; that
failure was an alignment trap rather than evidence of a data race.

Affected types include `Int16`, `Int32`, `Int128`, their unsigned equivalents,
`Float16`, and `Float`.

**Required direction:**

- use `loadUnaligned(as:)` or copy into correctly aligned storage;
- add deliberately offset buffers for every binary-backed primitive;
- retain those tests even if the eventual canonical wire format changes, so
  any supported legacy representation remains safe to decode.

### DD-003: Decoder recursion and allocation are unbounded

**Severity:** P0\
**Domains:** safety, security, decoding

`_XPCDecoder` recursively constructs child decoders without a shared depth,
node, container, string-size, or data-size budget:

- [`_XPCDecoder.swift`](../Sources/XPCCoding/Decoding/Details/_XPCDecoder.swift)
- [`XPCKeyedDecodingContainer.swift`](../Sources/XPCCoding/Decoding/Details/XPCKeyedDecodingContainer.swift)
- [`XPCUnkeyedDecodingContainer.swift`](../Sources/XPCCoding/Decoding/Details/XPCUnkeyedDecodingContainer.swift)

Stress probes showed that depth 1,000 could decode, while depth 5,000 exhausted
the process stack and segfaulted. A self-referential XPC array also segfaulted.
Deep acyclic remote input is sufficient to produce the crash even if cyclic
objects are rejected by a particular transport path.

Data-backed strings also allocate based on attacker-controlled XPC data
lengths.

**Required direction:**

- introduce a shared per-decode budget;
- limit recursion depth, visited nodes/containers, string bytes, and data bytes;
- define conservative defaults and, if useful, configurable limits;
- throw a documented `DecodingError` when any limit is exceeded;
- prove with subprocess tests that deep, cyclic, oversized, and boundary inputs
  throw rather than crash, hang, or exhaust memory.

### DD-004: Referencing encoders replace existing containers

**Severity:** P0\
**Domains:** correctness, encoding, inheritance

The array and dictionary referencing encoders used for `superEncoder()` create
and install a fresh keyed or unkeyed container on every request:

- [`_XPCArrayReferencingEncoder.swift`](../Sources/XPCCoding/Encoding/Details/_XPCArrayReferencingEncoder.swift)
- [`_XPCDictionaryReferencingEncoder.swift`](../Sources/XPCCoding/Encoding/Details/_XPCDictionaryReferencingEncoder.swift)

They bypass the container-reuse state machine in `_XPCEncoder`.

A valid `Encodable` that requests a keyed container twice retains both fields
at the top level. When the same value is encoded through either referencing
encoder, only fields written through the second request survive.

**Required direction:**

- make referencing encoders participate in the base container state machine;
- install the first container in the parent and reuse it on subsequent
  same-kind requests;
- preserve the existing invalid-container-transition behavior;
- add regression tests for repeated keyed and unkeyed requests through both
  dictionary and array `superEncoder()` paths.

### DD-005: Ordinary `Data` creates one XPC object per byte

**Severity:** P0\
**Domains:** performance, encoding, binary data

`Data` has an intended direct `XPC_TYPE_DATA` representation in
[`LosslessXPCObjectConvertible.swift`](../Sources/XPCCoding/Protocols/LosslessXPCObjectConvertible.swift).
Normal generic encoding does not select it. Instead it calls `Data.encode(to:)`,
which encodes an unkeyed sequence of bytes; every `UInt8` becomes a separate
one-byte XPC data object.

Observed shape:

```text
Data(count: 0)    -> XPC array
Data(count: 1)    -> array containing one one-byte XPC data object
Data(count: 4096) -> array containing 4,096 one-byte XPC data objects
```

This is O(n) XPC objects and allocations instead of one XPC object. It can
dominate throughput, memory use, and serialized message size.

**Required direction:**

- fast-path `Data` at every generic encoding boundary;
- encode it as one `XPC_TYPE_DATA`;
- verify top-level, keyed, unkeyed, nested, and superclass positions;
- assert representation shape, not only round-trip equality;
- benchmark allocation count, payload size, and throughput before and after.

### DD-006: Public pointer/count APIs can abort the process

**Severity:** P0\
**Domains:** safety, API, binary data

The enhanced encoding APIs accept optional pointer/count pairs but do not
document or enforce the necessary invariants:

- [`XPCEnhancedSingleValueEncodingContainer.swift`](../Sources/XPCCoding/XPCEnhancedSingleValueEncodingContainer.swift)
- [`XPCEnhancedUnkeyedEncodingContainer.swift`](../Sources/XPCCoding/XPCEnhancedUnkeyedEncodingContainer.swift)
- [`SingleValueEncodingContainer+XPCEnhancement.swift`](../Sources/XPCCoding/SingleValueEncodingContainer+XPCEnhancement.swift)
- [`UnkeyedCodingContainer+XPCEnhancement.swift`](../Sources/XPCCoding/UnkeyedCodingContainer+XPCEnhancement.swift)
- [`KeyedEncodingContainer+XPCEnhancement.swift`](../Sources/XPCCoding/KeyedEncodingContainer+XPCEnhancement.swift)

XPC-specific implementations forward the arguments directly to
`xpc_data_create`. A public call with `nil, count: 1` aborted in
`_xpc_api_misuse`. Negative counts and insufficient backing storage are also
dangerous. Generic fallbacks behave differently, sometimes treating invalid
pairs as empty data.

**Required direction:**

- require `count >= 0`;
- require a non-nil pointer whenever `count > 0`;
- document that storage must be initialized and readable for the stated extent
  for the duration of the call;
- choose one consistent thrown-error or precondition contract;
- add subprocess tests for every invalid pointer/count combination and normal
  tests for valid empty and nonempty inputs.

### DD-007: `XPCCodec` does not enforce coder compatibility

**Severity:** P1\
**Domains:** correctness, API, codec

[`XPCCodec.swift`](../Sources/XPCCoding/XPCCodec.swift) promises mutually
compatible coders, but publicly exposes mutable `XPCEncoder` and `XPCDecoder`
class instances. Mutating one coder changes live behavior while the codec's
stored configuration and reported strategies remain unchanged. Copies of the
codec struct also alias the same coder objects.

For example, changing the encoder to a data-backed string representation while
the decoder remains percent-escaped causes `codec.encode` followed by
`codec.decode` to fail.

**Required direction:**

- make immutable configuration the single source of truth;
- use operation-local coders or fresh computed coder factories;
- remove or redesign public access to mutable live coder instances;
- verify codec copies are independent values;
- use the design as the basis for a truthful shared-value concurrency model.

### DD-008: The wire-format contract is implicit and unstable

**Severity:** P1 before production use; mandatory before 1.0\
**Domains:** compatibility, API, wire format

Primitive mapping is inconsistent:

- `Int`, `Int64`, `UInt`, `UInt64`, and `Double` use native XPC scalar types;
- narrower and 128-bit integers plus `Float16` and `Float` use native memory
  bytes in `XPC_TYPE_DATA`;
- ordinary `Data` currently has a different shape from explicitly optimized
  data;
- string strategies are out-of-band configuration;
- there is no schema or version envelope.

The raw-byte forms depend on an unstated byte-order and layout contract and are
awkward for non-Swift peers.

**Required direction:**

- document the canonical XPC representation of every supported primitive;
- decide byte order and narrowing/range behavior;
- decide whether compatible alternate XPC numeric types may be decoded;
- define configuration negotiation and compatibility guarantees;
- define what constitutes a wire-breaking release;
- add golden representation fixtures and previous-release compatibility tests.

### DD-009: License provenance and notices require review

**Severity:** P0 release/compliance blocker\
**Domains:** licensing, release

This is not legal advice.

The repository declares that it is a heavily refactored fork of
[CodableXPC](https://github.com/daniel-grumberg/CodableXPC). Upstream's
[`LICENSE.txt`](https://raw.githubusercontent.com/daniel-grumberg/CodableXPC/master/LICENSE.txt)
contains a Runtime Library Exception in addition to Apache 2.0. Upstream source
files also carried an explicit
[`Apache License v2.0 with Runtime Library Exception`](https://raw.githubusercontent.com/daniel-grumberg/CodableXPC/master/Sources/CodableXPC/XPCEncoder.swift)
notice.

The initial local source import retained those notices. Current `Sources/` and
`Tests/` contain none, and the current root [`LICENSE`](../LICENSE) omits the
upstream exception. Apache §4 also addresses change notices and retention of
pertinent attribution notices.

Upstream did not include a `NOTICE` file, so absence of a local `NOTICE` is not
itself the concern.

**Required direction:**

- construct a source-provenance map from upstream files to current descendants;
- restore applicable upstream notices and the Runtime Library Exception unless
  qualified legal review determines otherwise;
- add prominent modification notices where required;
- retain clear fork attribution;
- consider a `THIRD_PARTY_NOTICES` file;
- record the compliance decision for future maintainers.

## Important correctness and API findings

### DD-010: Encoding containers can report incomplete coding paths

Keyed and unkeyed containers derive `codingPath` from shared mutable encoder
state. Explicit nested containers are constructed while a transient path
component is present but retain the parent encoder after that component is
removed. Generic unkeyed encoding also wraps descendant failures at only the
current index.

Containers should capture immutable base paths, child containers should receive
the appended path, and existing `EncodingError` paths should not be discarded.

### DD-011: Explicit nested-unkeyed decoding can report the parentless path

`XPCUnkeyedDecodingContainer` stores its correct path but appends the current
index to the parent decoder's mutable path. A nested array can therefore report
`["0"]` instead of `["parent", "0"]`.

Path construction should start from the container's captured `codingPath`.

### DD-012: User-thrown encoding errors change identity by position

Top-level encoding propagates a user error unchanged. Keyed generic encoding
wraps non-`EncodingError` failures, while unkeyed generic encoding wraps every
failure, including an existing `EncodingError`.

Standard coder substitutability is improved by propagating errors thrown by
user `Encodable` implementations and generating `EncodingError` only for
XPCCoding-originated failures.

### DD-013: `.throwOnDiscovery` exposes inconsistent error types

Top-level and keyed string paths can expose an internal, context-free error.
Unkeyed paths wrap the same condition in `EncodingError.invalidValue`.

All encoder-originated string incompatibilities should use one public error
contract with a complete coding path and underlying cause.

### DD-014: Missing-key `decodeNil(forKey:)` returns `false`

The keyed implementation returns `false` for both a non-null value and an
absent key. A direct missing-key request should throw `keyNotFound`, matching
standard coder behavior.

### DD-015: Malformed XPC strings are silently repaired

XPC string extraction obtains the exact XPC length but then ignores it and uses
lossy `String(cString:)`. Malformed UTF-8 can be converted to U+FFFD rather than
reported as corrupted input. Dictionary key enumeration behaves similarly.

The decoder should validate the exact byte sequence and throw
`DecodingError.dataCorrupted` for malformed strings or keys.

### DD-016: Enhanced wrappers lose value-semantic mutations

Enhanced helper methods cast `self` to a mutable existential, mutate the local
copy, and do not assign it back. External struct conformers can therefore
observe no state change, even though XPCCoding's reference-backed containers
appear to work.

Wrapper-level tests should exercise existing value-semantic recording
containers before the implementation is corrected.

### DD-017: `userInfo` is unavailable and not propagated

Internal encoders and decoders contain `userInfo` storage, but public facades
do not expose it and recursive or referencing coders do not propagate it.
Custom `Codable` implementations that require a `CodingUserInfoKey` therefore
cannot use the facade as expected.

Expose a facade-level snapshot and thread it through every root, nested,
collection, and superclass path.

### DD-018: Decoder error taxonomy is inconsistent

Examples include null-to-nonoptional decoding becoming `typeMismatch`, string
from a numeric object becoming `dataCorrupted`, and requesting a keyed
container from an array becoming `dataCorrupted`.

Adopt and test a documented convention for `valueNotFound`, `typeMismatch`,
`keyNotFound`, and `dataCorrupted`.

### DD-019: Shared Swift concurrency use has no supported model

`XPCEncoder`, `XPCDecoder`, and therefore `XPCCodec` are mutable and
non-`Sendable`. Existing concurrency tests create a fresh codec inside every
task, so they demonstrate parallel independent operations rather than safe
sharing.

The preferred direction is immutable facade configuration with operation-local
implementation state, followed by genuine shared-codec task-group and Thread
Sanitizer tests. `@unchecked Sendable` should not substitute for that design.

### DD-020: Public default API is asymmetric

Encoder initializer documentation references `.standard`, but encoder strategy
`standard` members are not public. Decoder equivalents are public.
`XPCCodec` also has neither a default initializer nor a `standard` convenience.

All package tests use `@testable import XPCCoding`, so the visibility error is
not caught by a consumer compile test.

### DD-021: Implementation is overexposed through inlining annotations

At the reviewed revision, 5,852 source lines contain 208 `@inlinable` and 191
`@usableFromInline` annotations. This includes orchestration, allocation-heavy,
and error-handling paths for which no benchmark demonstrates a benefit.

Inlining should be retained only for measured hot leaf operations. A
pre-1.0 review should reduce unnecessary client-visible implementation and ABI
surface.

### DD-022: Data-backed decoding performs avoidable initialization and copies

Binary and string-data extraction allocate zero-filled `Data`, overwrite all of
it from XPC, and then may allocate again while constructing a string.

Use an exact-length single-copy path where safe, and validate improvements with
representative benchmarks.

### DD-023: `.assumeAbsent` does not provide the claimed fast path

String-key handling scans the entire key to count NUL bytes before switching on
the passthrough strategy. The unsafe strategy therefore does not avoid the main
scan it is documented to avoid.

Dispatch on passthrough first and benchmark whether this strategy is worth
retaining.

## Verification and testing findings

### Existing validation results

All results below were collected in the Swift 6.4/Xcode 27 review environment
identified above. They are evidence about the reviewed revision, not proof that
the Swift 6.3-only supported configuration passes.

| Check | Result |
| --- | --- |
| Debug tests | Pass: 175 tests in 16 suites |
| Release tests | Pass |
| Recorded known issues | 69 |
| Warnings-as-errors build | Pass |
| Address Sanitizer | Pass |
| Undefined Behavior Sanitizer | Pass |
| Thread Sanitizer | Fails at the misaligned numeric load |
| Source coverage | 91.80% lines, 93.35% regions, 94.78% functions |
| Declared platform type-checks | macOS 26, iOS 26, and Catalyst 26 pass |
| Secret scan | Pass |
| API comparison with `0.0.3` | One public breaking change |

The 69 known issues describe intentional `.assumeAbsent` data loss. They should
be direct assertions of the documented lossy result rather than successful
test runs that report dozens of tolerated issues.

High coverage did not prevent the serious findings because:

- critical literal-percent cases were absent or explicitly filtered;
- many tests assert round-trip equality but not XPC representation shape;
- hostile graph depth, cycles, pointer/count pairs, and unaligned buffers were
  not exercised;
- all imports are `@testable`, with no black-box consumer target;
- concurrency tests do not share coder instances;
- there are no cross-release fixtures or real transport tests.

### Required confidence-building additions

- black-box consumer compile tests using plain `import XPCCoding`;
- property-based and fuzz tests for strings, keys, malformed XPC graphs, and
  decoding limits;
- subprocess tests for all potentially trapping inputs;
- real XPC connection request/reply integration tests;
- frozen representation fixtures and cross-release compatibility tests;
- shared-codec concurrency tests;
- benchmarks covering `Data`, strings, dictionaries, deep models, failure
  paths, and direct-pointer APIs;
- sanitizer jobs in CI.

## Tooling and release findings

### Quality gates currently report false success

Observed results:

```text
swift-format diagnostics:       1,243
swift-format --strict:          failure
just format check-all:          success

SwiftLint source findings:      84
SwiftLint test findings:        203
just lint check-all:            success
```

The format recipe omits strict mode. SwiftLint recipes prefix the invocation
with `-`, explicitly instructing `just` to ignore nonzero status.

The documentation checker reports eight undocumented public declarations but
also exits successfully. The configured documentation-generation command
assumes a Swift-DocC plugin that the package does not declare, so the command is
unknown.

The `all-validation` test recipe points to ordinary debug and release tests.
`HEAVY_VALIDATION` is not referenced anywhere, so validation variants currently
exercise nothing additional.

### CI is materially narrower than the release claim

The sole workflow runs debug build and tests on one macOS/Xcode combination. It
does not run:

- release tests;
- macOS, iOS, and Catalyst compilation at the intentional 26+ floor;
- strict formatting, linting, or API-documentation checks;
- API compatibility analysis;
- coverage;
- sanitizers;
- transport integration tests.

The correct response is not to support older toolchains or platforms. It is to
pin an Xcode toolchain that supplies Swift 6.3 and validate the intentional
macOS/iOS/Catalyst 26+ contract in a maintainable CI workflow.

### Release metadata is not ready

- [`README.md`](../README.md) uses the wrong project name and ends mid-sentence.
- The latest tag, `0.0.3`, is lightweight and three substantial commits behind
  the reviewed `main`.
- The API digester reports removal of
  `KeyedEncodingContainer.efficientlyEncodeBinaryData(_:forKey:)` relative to
  `0.0.3`.
- There are no GitHub Releases, changelog, security policy, contribution guide,
  issue/PR templates, release workflow, or Swift Package Index configuration.
- `main` was unprotected and had no required status checks at review time.

These are not substitutes for implementation correctness, but they are needed
before the package is presented as a dependable open-source dependency.

## Positive findings

- The facade/internal implementation split is conceptually clean.
- Each normal operation creates fresh internal encoder or decoder state.
- The package has no third-party SwiftPM dependencies or unsafe package flags.
- Swift 6 language mode and strict concurrency checking are enabled.
- Primitive XPC type validation, array bounds/index advancement, explicit nil
  handling, invalid binary lengths, and empty data/string behavior are
  generally sound.
- A root encode that produces no container throws rather than force-unwrapping.
- XPC object ownership and ordinary buffer lifetimes appear sound.
- Tests are substantially broader than the original upstream project,
  including numeric extremes, nesting, inheritance, strategies, and many error
  paths.
- Address Sanitizer and Undefined Behavior Sanitizer runs passed.
- The repository was clean at the end of the review; the audit itself changed
  no source files.

## Recommended release gates

### Gate 1: Correctness

Repair percent escaping, referencing encoders, coding paths, error propagation,
missing-key nil semantics, malformed strings, and value-semantic enhanced
wrappers. Every fix must add a test that demonstrably fails on the reviewed
implementation.

### Gate 2: Crash resistance

Repair unaligned loads, define and enforce pointer contracts, and introduce
decoder resource budgets. Demonstrate in subprocesses that malformed or
adversarial inputs throw instead of trapping, hanging, exhausting memory, or
overflowing the stack.

### Gate 3: Representation and performance

Encode `Data` as one XPC object, define the primitive/string wire contract,
introduce golden fixtures, and establish benchmark baselines.

### Gate 4: API confidence

Make the codec compatibility guarantee true, decide `userInfo` and shared
concurrency semantics, settle defaults, reduce premature inlining, and add
black-box consumer tests.

### Gate 5: Publication

Resolve licensing, make quality commands fail reliably, establish focused
Swift 6.3 and 26+ CI, complete package documentation, add transport/fuzz/
compatibility validation, and establish a repeatable release process.

After these gates close, execute the independent post-remediation audit. A
deliberate `0.1.0` is appropriate only if that audit finds no unresolved P0/P1
issues. A stable `1.0` should wait until the public API and wire compatibility
contract are both intentionally frozen.
