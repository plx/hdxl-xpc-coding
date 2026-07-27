# Inlining and ABI-Exposure Policy

## Scope

XPCCoding is a low-overhead, same-host transport shim for applications and XPC
services that are designed, built, and deployed together. Inlining controls are
therefore performance tools, not a format-versioning or independently-versioned
peer compatibility mechanism. They do not change the XPC object representation
described in [WireFormat.md](WireFormat.md).

The default is to leave declarations without `@inlinable`,
`@usableFromInline`, or `@inline(__always)`. An exception requires:

1. a release benchmark through a normal, non-`@testable` package import;
2. a concise rationale beside the retained source cluster;
3. the smallest compiler-required transitive ABI closure; and
4. an entry in `.inlining-annotations.allowlist`.

Error construction, diagnostics, validation, and container-orchestration paths
remain non-inlinable unless a future measurement specifically justifies them.
`@usableFromInline` is not a general optimization hint: it is retained only
where Swift requires it for a measured inlinable declaration or a protocol
witness in that ABI closure.

## Issue 31 Audit

The baseline was commit `0256902205c1c7a1eab51f02c39359f8567377fc`,
measured with the supported Xcode 26.6 and Swift 6.3 toolchain. It contained 478
annotation occurrences on 449 source lines across 37 files:

- 217 `@inlinable`;
- 232 `@usableFromInline`; and
- 29 `@inline(__always)`.

The audited result contains 68 occurrences across 7 files:

- 11 `@inlinable`;
- 54 `@usableFromInline`; and
- 3 `@inline(__always)`.

The table inventories every baseline cluster. “Removed” means the file now uses
the ordinary internal or public compilation boundary throughout.

| Source file under `Sources/XPCCoding/` | Baseline | Audited | Disposition |
| --- | ---: | ---: | --- |
| `Decoding/Details/XPCKeyedDecodingContainer.swift` | 43 | 0 | Removed |
| `Encoding/Details/XPCUnkeyedEncodingContainer.swift` | 42 | 0 | Removed |
| `Decoding/Details/XPCUnkeyedDecodingContainer.swift` | 42 | 0 | Removed |
| `Encoding/Details/_XPCEncoder.swift` | 37 | 12 | Generic entry-point ABI closure only |
| `Encoding/Details/XPCKeyedEncodingContainer.swift` | 36 | 30 | Measured keyed leaves plus required witnesses |
| `Encoding/Details/XPCSingleValueEncodingContainer.swift` | 35 | 0 | Removed |
| `Protocols/XPCObjectExtractable.swift` | 34 | 0 | Removed |
| `Support/xpc_object+Support.swift` | 31 | 5 | Measured keyed dictionary-set leaf |
| `KeyedEncodingContainer+XPCEnhancement.swift` | 27 | 0 | Removed |
| `Decoding/Details/_XPCDecoder.swift` | 23 | 0 | Removed |
| `Protocols/LosslessXPCObjectConvertible.swift` | 17 | 17 | Two measured leaves plus required witness visibility |
| `Decoding/Details/_XPCDecodingState.swift` | 13 | 0 | Removed |
| `Decoding/Details/XPCSingleValueDecodingContainer.swift` | 12 | 0 | Removed |
| `UnkeyedCodingContainer+XPCEnhancement.swift` | 9 | 0 | Removed |
| `Support/String+EmbeddedNullSupport.swift` | 8 | 1 | Required dependency of measured key setter |
| `Support/XPCCodingKey.swift` | 7 | 0 | Removed |
| `Decoding/Details/xpc_object_t+Extraction.swift` | 6 | 0 | Removed |
| `SingleValueEncodingContainer+XPCEnhancement.swift` | 5 | 0 | Removed |
| `Protocols/XPCBinaryDataRepresentationConvertible.swift` | 5 | 0 | Removed |
| `Encoding/Details/_XPCDictionaryReferencingEncoder.swift` | 5 | 0 | Removed |
| `Encoding/Details/_XPCArrayReferencingEncoder.swift` | 5 | 0 | Removed |
| `Support/String+Support.swift` | 4 | 2 | Measured percent-escape count leaves |
| `Support/CodingKey+Support.swift` | 4 | 0 | Removed |
| `Encoding/Details/String+xpc_object_t.swift` | 4 | 0 | Removed |
| `XPCEnhancedUnkeyedEncodingContainer.swift` | 3 | 0 | Removed |
| `XPCEnhancedSingleValueEncodingContainer.swift` | 3 | 0 | Removed |
| `Protocols/XPCObjectCompatibilityError.swift` | 3 | 0 | Removed |
| `XPCCodec.swift` | 2 | 0 | Removed |
| `Support/InfalliblyUnwrap.swift` | 2 | 0 | Removed |
| `Encoding/XPCEncoder.swift` | 2 | 1 | Measured generic public entry point |
| `Encoding/XPCEncoder+StringKeyStrategy.swift` | 2 | 0 | Removed |
| `Decoding/XPCDecoder+StringKeyStrategy.swift` | 2 | 0 | Removed |
| `XPCCodec+StringValueDataRepresentation.swift` | 1 | 0 | Removed |
| `Support/UnsafePointerCountValidation.swift` | 1 | 0 | Removed |
| `Encoding/XPCEncoder+StringValueStrategy.swift` | 1 | 0 | Removed |
| `Decoding/XPCDecoder.swift` | 1 | 0 | Removed |
| `Decoding/XPCDecoder+StringValueStrategy.swift` | 1 | 0 | Removed |

## Performance Evidence

The release benchmark executable imports `XPCCoding` normally, so it measures
the package-client optimization boundary. Removing every annotation produced a
repeatable regression in `collections/large-dictionary/encode`: three
25-sample candidate medians were 36.3% to 37.6% slower than paired baseline
runs. This established that a small keyed-encoding cross-module specialization
closure is material.

The retained closure was then reduced declaration by declaration. With 5 warmup
batches, 25 samples, and a 200 ms target sample, the final sensitive-scenario
median was 5,665,328.125 ns versus the paired baseline's 5,671,994.750 ns, a
0.12% improvement. The benchmark's 10% regression comparator passed.

The final full-suite comparison used 2 warmup batches, 9 samples, and a 50 ms
target sample for all 55 scenarios. No scenario exceeded the 10% threshold; the
largest measured regression was 3.52%. Both reports identify Xcode 26.6, Apple
Swift 6.3.3, the same hardware, and release `-O` optimization.

The retained hot leaves are:

- the public generic `XPCEncoder.encode` call and its internal generic entry
  point;
- keyed `Int` encoding and lossless conversion;
- the per-key strategy read and direct XPC dictionary setter;
- direct `Data` conversion; and
- the two percent-escape preallocation scans.

Every other retained occurrence is a compiler-required signature, stored
dependency, or protocol witness in that closure. The allowlist records that
classification per occurrence.

## Public API Evidence

`swift package diagnose-api-breaking-changes` reported no breaking changes
against the baseline commit for the `XPCCoding` product. Public symbol graphs
were also extracted from both revisions with Xcode 26.6. After removing only
source locations and documentation line ranges, both normalized graph files
matched byte-for-byte. The audit changes compiler optimization exposure without
changing the public source API.

## Review Gate

Run:

```sh
bash Scripts/verify-inlining-annotations.sh
```

The script compares source annotations with
`.inlining-annotations.allowlist`, rejects unreviewed annotations, stale
entries, duplicate entries, and entries without a rationale, and runs in the
supported CI job. Line numbers are intentional: moving or expanding a cluster
requires an explicit allowlist update and renewed review of its evidence.
