# Internal Design

An overview of `XPCCoding` internals for maintainers and contributors.

## Overview

The package follows the same high-level split as `JSONEncoder` and `JSONDecoder`:

- ``XPCEncoder`` and ``XPCDecoder`` are public facades for configuration plus top-level encode/decode operations.
- Internal encoder/decoder implementations (`_XPCEncoder`, `_XPCDecoder`) provide actual `Encoder`/`Decoder` behavior.
- Container types (`XPCKeyed...`, `XPCUnkeyed...`, `XPCSingleValue...`) translate `Codable` operations into `xpc_object_t` values.
- ``XPCCodec`` owns a mutually-compatible encoder/decoder pair and is the preferred API for round trips.

## Encoding Pipeline

For `try codec.encode(value)` (or `XPCEncoder.encode(_:)`), the flow is:

1. Build a fresh internal encoder with frozen string strategies.
2. Call `value.encode(to:)`.
3. Lazily create the root container when first requested:
   - keyed -> XPC dictionary
   - unkeyed -> XPC array
   - single value -> pending single-value slot
4. Encode primitives and nested values into XPC objects.
5. Return the finalized top-level `xpc_object_t`.

Important details:

- The root is not forced to be dictionary-shaped; all top-level container kinds are supported.
- Re-requesting the same container kind is allowed (required for superclass-encoding patterns), but switching kinds is treated as programmer error.
- `Data` at top level has a fast path to `xpc_data_t`.

## Decoding Pipeline

For `try codec.decode(T.self, from: object)` (or `XPCDecoder.decode`), the flow is:

1. Build a fresh internal decoder with frozen string strategies and the source `xpc_object_t`.
2. Call `T.init(from:)`.
3. Serve keyed/unkeyed/single-value containers over the same underlying XPC object.
4. Convert XPC values to Swift types with strict type checks.
5. Propagate decoding errors with accurate coding paths.

## Container Architecture

- Keyed containers map `CodingKey` -> XPC dictionary entries.
- Unkeyed containers map sequential indices -> XPC array entries.
- Single-value containers encode/decode one scalar or nested value.
- Referencing encoders (`_XPCDictionaryReferencingEncoder`, `_XPCArrayReferencingEncoder`) support nested/super encoding into already-owned parent containers.

This mirrors Foundation's encoder architecture while remaining explicit about XPC object ownership points.

## String Strategy Plumbing

String handling is strategy-driven because XPC strings are C-style null-terminated:

- Key strategies control dictionary key encoding/decoding.
- Value strategies control string value encoding/decoding.
- Defaults are percent-escape based for safe round trips with embedded null bytes.
- ``XPCCodec`` maps one configuration into matching encoder/decoder strategies to prevent mismatches.

For deeper behavior notes, see `reference/EmbeddedNullByteHandling.md` in this repository.

## See Also

- <doc:UsageExamples>
- <doc:EnhancedBinaryAPIs>
- <doc:CodableXPCRelationship>
