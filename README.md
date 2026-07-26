# hdxl-xpc-codable

A Swift encoder/decoder pair producing xpc objects as output.

This is a heavily refactored fork of
[CodableXPC](https://github.com/daniel-grumberg/CodableXPC).

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
