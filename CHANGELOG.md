# Changelog

All notable changes to XPCCoding are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

This project is **pre-1.0**. Under [semantic versioning](https://semver.org),
0.y.z releases make no source-stability promise, and XPCCoding uses that latitude
deliberately: the hardening work below intentionally corrected and reduced the
public API before the first supported release. Every intentional break is listed
under **Removed** or **Changed** with a migration. See
[reference/ApiStabilityPolicy.md](reference/ApiStabilityPolicy.md) for the
source-API stability policy and [RELEASING.md](RELEASING.md) for how releases are
cut.

Two compatibility axes are tracked separately and must not be conflated:

- **Source API stability** — the Swift symbols XPCCoding vends. Governed by
  [reference/ApiStabilityPolicy.md](reference/ApiStabilityPolicy.md) and the
  `swift package diagnose-api-breaking-changes` gate.
- **XPC object representation** — the `xpc_object_t` trees XPCCoding produces and
  consumes. Governed by [reference/WireFormat.md](reference/WireFormat.md). The
  representation is a same-build, co-deployed contract with **no** cross-release
  compatibility: independently versioned peers, network transport, and
  persistence are out of scope. When the representation changes, participating
  peers rebuild and redeploy together, and the contract document and same-build
  fixtures are updated in the same change.

Changelog dates use `YYYY-MM-DD`.

## [Unreleased]

The first supported release will move these entries into a new `[<version>] -
<date>` section and retain an empty **Unreleased** section once a version is
chosen and the
[production-readiness audit](reference/PostRemediationProductionReadinessAudit.md)
reaches a GO decision. The entries below record every material change since the
pre-hardening lightweight tag `0.0.3`
(`8e95faadf8dfcb5297433a98d36a4f3c38f1b4fb`).

The pinned source-API baseline for the going-forward stability gate is the
audited hardened surface `5f6480ec450eb6a1067d183d62d47476f2ca5b4b`
(`Scripts/api-baseline.env`). The removals below reproduce with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift package diagnose-api-breaking-changes 0.0.3 --products XPCCoding
```

which exits `1`. Under the supported Swift 6.3.3 toolchain, it currently reports
these four removals:

- `XPCDecoder.init(stringKeyStrategy:stringValueStrategy:)` (gained
  `resourceLimits:`; see **Changed**)
- `XPCDecoder.init(configuration:)` (gained `resourceLimits:`; see **Changed**)
- `XPCCodec.encoder`
- `XPCCodec.decoder`

The `UnsafeMutableBufferPointer<T>` overload rename documented under **Changed**
below is a fifth, manually identified source migration. It is present in the
`0.0.3` source and absent under that name today, but the current Swift 6.3.3
diagnosis does not report that extension-method change. It remains documented
rather than being discarded because the tool omits it. Run the command above
when cutting a release and reconcile its actual output against the four-item
tool-reported list; a discrepancy is a documentation defect to fix before
tagging, not something to wave through.

### Removed

- **`XPCCodec.encoder` and `XPCCodec.decoder` stored properties.** `XPCCodec` no
  longer retains mutable coder references. Its immutable `Configuration` is now
  the codec's only persistent state (#71, #77, #92).

  *Migration.* Use the direct operations, or make a fresh facade:

  ```swift
  // Before:
  let object = try codec.encoder.encode(value)
  let value  = try codec.decoder.decode(Value.self, from: object)

  // After (direct — always uses the codec's declared configuration):
  let object = try codec.encode(value)
  let value  = try codec.decode(Value.self, from: object)

  // After (when a separately configurable facade is needed):
  let encoder = codec.makeEncoder()
  let decoder = codec.makeDecoder()
  ```

  See [reference/MigrationGuide.md](reference/MigrationGuide.md).

A codec can also no longer be built from independently supplied coders that could
disagree with its reported configuration; construct from a `Configuration`
instead (`XPCCodec(configuration:)` or `XPCCodec.standard`) (#71, #92). That
field-initialization initializer was `@usableFromInline internal` at `0.0.3`, not
public, so it is **not** a public-API removal and the API digest does not report
it; it is noted here only because it changes how a codec is constructed.

### Changed

- **`XPCDecoder.init(stringKeyStrategy:stringValueStrategy:)` gained a
  `resourceLimits:` parameter**, becoming
  `XPCDecoder.init(stringKeyStrategy:stringValueStrategy:resourceLimits:)` with
  `resourceLimits` defaulting to `.standard`. The two-label initializer no longer
  exists as a distinct entry point, so the API-diff tool reports it as removed;
  most call sites keep compiling because the new parameter is defaulted (#66).

- **`XPCDecoder.init(configuration:)` gained a `resourceLimits:` parameter**,
  becoming `XPCDecoder.init(configuration:resourceLimits:)` with `resourceLimits`
  defaulting to `.standard`. Reported as removed by the API-diff tool for the same
  reason; defaulted-parameter call sites keep compiling (#66).

- **`efficientlyEncodeBinaryData` `UnsafeMutableBufferPointer<T>` overload renamed
  to `efficientlyEncodeElements`.** At `0.0.3` the typed-element buffer overload
  was misnamed `efficientlyEncodeBinaryData`, which wrongly implied a raw-bytes
  representation. The `efficientlyEncodeBinaryData` family now names only the
  raw-bytes helpers (one `XPC_TYPE_DATA`), and `efficientlyEncodeElements` names
  the helpers that encode each element through ordinary unkeyed-container rules
  (an XPC array) (#11, #64).

  *Migration.* The affected overload existed only on `KeyedEncodingContainer`
  (the unkeyed container already named this shape `efficientlyEncodeElements` at
  `0.0.3`, and the single-value container never had it). Rename typed-element
  buffer calls:

  ```swift
  // Before:
  try container.efficientlyEncodeBinaryData(typedElementBuffer, forKey: key)
  // After:
  try container.efficientlyEncodeElements(typedElementBuffer, forKey: key)
  ```

- **`XPCCodec` is now an immutable, `Sendable` value.** One explicitly configured
  codec can be shared across Swift concurrency tasks; each operation snapshots the
  configuration and creates fresh operation-local state with no added
  synchronization. The mutable `XPCEncoder` / `XPCDecoder` facades remain
  non-`Sendable` and must stay task-confined (#77).

- **Strategy closures are `Sendable`; codec configuration is authoritative and
  copy-independent.** Reconfiguring a facade produced by `makeEncoder()` /
  `makeDecoder()` cannot affect the codec, a copy of it, or a later factory
  result (#71).

### Added

- **Normative same-build XPC representation contract**
  ([reference/WireFormat.md](reference/WireFormat.md)) plus bidirectional,
  deterministic same-build structural fixtures, and real same-host XPC
  request/reply integration tests (#65, #87, #88).
- **Finite decoder resource budgets** (`XPCDecoder.ResourceLimits`), applied
  independently per top-level decode, bounding nesting, element counts, node
  visits, and string/data byte volume; cycles are bounded by the nesting ceiling
  (#66).
- **Checked, efficient numeric representations** for narrow integers, `Float16`,
  `Float`, and native 16-byte `Int128` / `UInt128`, with alignment-safe decoding
  (#63, #72).
- **`Data` encodes as one `XPC_TYPE_DATA`** rather than an unkeyed array of bytes;
  the decoder rejects the accidental historical byte-array shape (#70).
- **Public exposure and recursive propagation of `CodingUserInfoKey` values**
  through `userInfo` (#82).
- **`XPCCodec.standard` and `XPCCodec.Configuration.standard`** as public
  standard-configuration entry points, and public standard codec construction
  (#92). (`XPCEncoder.standard` and `XPCDecoder.standard` already existed at
  `0.0.3` and are unchanged.)
- **Support policy, provenance, and publication infrastructure**: codified Swift
  6.3 / Apple 26 support policy and CI (#73, #76); restored upstream license and
  attribution (#67); repository security controls, CodeQL, and independent
  sanitizer lanes (#83, #84); reproducible API documentation (#90) and benchmarks
  (#69); deterministic property/hostile-input fuzzing and regression-first
  baseline evidence (#89); fail-closed SwiftLint (#91); audited and constrained
  `@inlinable` / `@usableFromInline` exposure (#93).
- **Maintainable contributor workflow and community standards**: documented the
  supported environment and exact local gates; added a code of conduct,
  namespaced defect/design issue forms with private security routing, and a
  regression/compatibility-focused pull request template (#49).
- **Documentation for every public declaration**, including actionable
  pointer/count, memory-extent, and lifetime contracts on every unsafe-pointer
  entry point, plus a fail-closed public-documentation completeness gate
  (`Scripts/verify-public-documentation.sh`) wired into the API documentation
  build and its CI job (#38).
- **A zero-known-issue release policy**, enforced by the canonical
  `Scripts/run-tests-with-zero-known-issues.sh` that backs both `just test
  debug|release` and the CI test job. The 69 `withKnownIssue` reports that used
  to accompany a "passing" run are replaced by exact assertions of the
  intentionally lossy `.assumeAbsent` behavior — first-null truncation, key
  collision, and the resulting inequality — and the gate additionally rejects
  reintroduced `withKnownIssue` / `XCTExpectFailure` markers, known-issue
  summaries, and raw NUL bytes in test output. Its detectors ship with positive
  and negative controls (`just test zero-known-issue-controls`) (#42).

### Fixed

- **Bijective, corrected percent-escape grammar** for embedded null and literal
  percent scalars in string keys and values; the defective pre-contract grammar
  is not accepted (#62).
- **Strict UTF-8 validation** of external XPC strings and dictionary keys;
  malformed bytes are rejected rather than repaired with U+FFFD (#74).
- **Normalized decoder error taxonomy** and preserved encoding error semantics:
  absent keys, explicit nulls, wrong kinds, and malformed correct-kind content map
  to the documented `DecodingError` cases at exact coding paths; user-thrown
  errors propagate unchanged (#85, #86).
- **Correct keyed `decodeNil` missing-key semantics** (#80), **value-semantic
  enhanced-container mutations preserved** (#81), **immutable encoding-container
  coding paths preserved** (#78), **unkeyed decoding paths derived from their
  container** (#79), and **referencing/super encoders reuse container state
  without losing neighboring values** (#68).
- **Unsafe pointer/count contracts validated before calling XPC**, and
  **alignment-safe binary numeric decoding** that never performs an unaligned
  `load(as:)` (#63, #64).

### Security

- Repository prevention, scanning, and verification controls, a private
  vulnerability-report route, and independent AddressSanitizer,
  UndefinedBehaviorSanitizer, and ThreadSanitizer CI lanes (#83, #84). See
  [SECURITY.md](SECURITY.md) and
  [reference/RepositorySecurity.md](reference/RepositorySecurity.md).

## Prior lightweight tags

`0.0.1`, `0.0.2`, and `0.0.3` are pre-hardening lightweight tags that predate the
audited API surface and the representation contract. They are retained,
immutable, and never moved, but they are **not** a supported release line and are
not the source-API baseline. See
[reference/ApiStabilityPolicy.md](reference/ApiStabilityPolicy.md).

[Unreleased]: https://github.com/plx/hdxl-xpc-coding/compare/0.0.3...HEAD
