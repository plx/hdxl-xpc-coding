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

Call `makeEncoder()` or `makeDecoder()` when an operation needs a separately
configurable facade. Each call returns a fresh instance. Reconfiguring that
instance cannot affect the codec or a later factory result, and the
reconfigured instance is not guaranteed to remain compatible with them.

See the [migration guide](reference/MigrationGuide.md) when updating code that
previously accessed `codec.encoder` or `codec.decoder`.

Release-mode performance measurements and report comparison are documented in
[Benchmarks/README.md](Benchmarks/README.md).

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
