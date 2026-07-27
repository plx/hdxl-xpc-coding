# hdxl-xpc-codable

A Swift encoder/decoder pair producing xpc objects as output.

This is a heavily refactored fork of
[CodableXPC](https://github.com/daniel-grumberg/CodableXPC).

## Support

XPCCoding supports exactly Xcode 26.6 (build 17F113) with Apple Swift 6.3.3
and Swift 6 language mode on arm64. Its deployment targets are macOS 26 or
newer, iOS 26 or newer, and Mac Catalyst 26 or newer.

Earlier toolchains and platform releases are unsupported. Later compiler
versions are unverified until the policy changes deliberately; successfully
building with one does not expand the support claim. See the
[support policy](reference/SupportPolicy.md) for the exact contributor,
verification, and compatibility rules.

Aside from renaming, reorganization, and purely-stylistic changes, this package:

- allows arbitrary values to be the "root value" of an archive
- adopts the `TopLevelEncoder`-facade pattern used by `JSONEncoder`/`JSONDecoder`
- reduces the public API surface to the necessary portions
- correctly handles strings with embedded null bytes and provides
  user-configurable strategies for doing so
- provides a "codec" mechanism for obtaining compatible encoder/decoder pairs
- provides auxiliary API allowing more-efficient encoding for clients working
  with lower-level data, such as APIs that encode raw byte buffers *without*
  wrapping them in a transient `Data`
- has an extensive unit-test suite validating its behavior

## Codec Ownership

`XPCCodec` is an immutable configuration value. Its direct `encode` and
`decode` operations always use the codec's declared configuration and do not
retain mutable `XPCEncoder` or `XPCDecoder` instances.

The codec conforms to `Sendable` through compiler-checked stored state and can
be shared across tasks. Each operation snapshots its configuration and creates
fresh operation-local implementation state. This adds no synchronization or
format-versioning overhead.

Call `makeEncoder()` or `makeDecoder()` when an operation needs a separately
configurable facade. Each call returns a fresh instance. Reconfiguring that
instance cannot affect the codec or a later factory result, and the
reconfigured instance is not guaranteed to remain compatible with them.
`XPCEncoder` and `XPCDecoder` are mutable, deliberately non-`Sendable`
reference types; keep each instance confined to one task.

Sharing a codec does not make an `xpc_object_t` Swift `Sendable`. Concurrent
round trips should keep each XPC object within the task that produced it.

The standard codec safely preserves embedded null and literal percent scalars
in string keys and values:

```swift
let codec = XPCCodec()
let object = try codec.encode(["key\u{0}%": "value\u{0}%"])
let value = try codec.decode([String: String].self, from: object)
```

`XPCCodec.standard`, `XPCCodec.Configuration.standard`, `XPCEncoder.standard`,
and `XPCDecoder.standard` select that same configuration. Use explicit
strategies only when all co-built peers agree on them.

See the [migration guide](reference/MigrationGuide.md) when updating code that
previously accessed `codec.encoder` or `codec.decoder`.

Release-mode performance measurements and report comparison are documented in
[Benchmarks/README.md](Benchmarks/README.md).

The exact local AddressSanitizer, UndefinedBehaviorSanitizer, ThreadSanitizer,
and subprocess-regression commands are documented in
[Sanitizer Testing](reference/SanitizerTesting.md).

The reproducible DocC command shared by local runs and CI is documented in
[API Documentation](reference/ApiDocumentation.md).

The pinned strict-lint policy and blocking-versus-summary command semantics are
documented in [SwiftLint](reference/SwiftLint.md).

## Security

Report suspected vulnerabilities through the private route in
[SECURITY.md](SECURITY.md), not through a public issue. Repository prevention,
scanning, and verification controls are documented in
[Repository Security Controls](reference/RepositorySecurity.md).

## Origin and License

This package derives in part from
[`daniel-grumberg/CodableXPC`](https://github.com/daniel-grumberg/CodableXPC)
at pinned upstream revision
[`df3250371e7ad4882ec51b76dfbbbe7b00209fee`](https://github.com/daniel-grumberg/CodableXPC/tree/df3250371e7ad4882ec51b76dfbbbe7b00209fee).
The derived files have been substantially modified.

The package is licensed under Apache License 2.0 with the Swift Runtime Library
Exception (`Apache-2.0 WITH Swift-exception`). See [LICENSE](LICENSE),
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), and the
[upstream provenance record](reference/UpstreamProvenance.md) for details.
