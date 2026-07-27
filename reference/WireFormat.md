# XPCCoding XPC Object Representation

## Status and purpose

This document is the normative description of the `xpc_object_t` trees
produced and consumed by XPCCoding.

The filename uses “wire format” because that is a familiar search term. It does
not mean that XPCCoding defines serialized bytes on a wire. XPCCoding chooses
XPC object kinds and values; libxpc owns the opaque serialization used to move
those objects between local processes.

This contract exists so that:

- encoder and decoder implementations cannot silently share the same mistake;
- representation shape, allocation cost, and malformed-input behavior can be
  reviewed without reading implementation code;
- same-build structural fixtures have an independent source of truth; and
- applications and their co-built XPC services can agree on one precise object
  representation without paying for a general interchange protocol.

## Supported compatibility boundary

XPCCoding is a low-overhead, same-machine IPC shim for a **compilation
cohort**. A supported cohort consists of applications and XPC services that:

- are designed as one system;
- use the same XPCCoding source revision and Swift 6.3 toolchain;
- are built together for compatible target ABIs;
- use matching `Codable` models and matching XPCCoding configuration; and
- are deployed and updated together.

This boundary is intentionally similar to package visibility. Representation
details are precise within the cohort, but they are not a separately-versioned
interchange ABI.

The following are explicitly unsupported:

- independently versioned or independently updated peers;
- decoding payloads produced by another XPCCoding release;
- network transport or communication with another machine;
- persistence, archival, or later replay of XPC objects;
- non-Apple peers or reimplementation as a language-neutral protocol;
- cross-architecture interchange when a row below uses target-native bytes;
- reliance on the alignment or address of XPC-managed storage; and
- direct use of libxpc's underlying serialized bytes.

Apple describes XPC as local interprocess communication and states that its
underlying encoding is opaque, is not an ABI contract, and must not be archived
to disk. See
[XPC](https://developer.apple.com/documentation/xpc),
[Creating XPC Services](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html),
and
[`xpc_connection_send_message`](https://developer.apple.com/documentation/xpc/xpc_connection_send_message%28_%3A_%3A%29?language=objc).

XPCCoding therefore has:

- no wire-format version number;
- no runtime version negotiation;
- no library-owned message envelope;
- no reserved transport keys; and
- no previous-release decoder compatibility layer.

When this representation changes, every participating process is rebuilt and
deployed together.

## Representation layers

Keep these three layers distinct:

1. A Swift value's `Encodable` implementation requests keyed, unkeyed, or
   single-value containers.
2. XPCCoding represents those requests as an XPC object tree described here.
3. libxpc serializes and transports that tree between local processes using an
   opaque implementation.

Only layer 2 is XPCCoding's contract. An application's `Codable` schema and XPC
message dictionary are application protocol. Layer 3 is Apple implementation
detail.

## Primitive representation table

“Accepted input” means input accepted by a decoder built from the same
XPCCoding revision. The decoder does not accept accidental historical shapes.

| Swift value requested | Encoder output | Accepted input and validation |
| --- | --- | --- |
| `nil` or explicit `encodeNil()` | `XPC_TYPE_NULL` | `XPC_TYPE_NULL` |
| `Bool` | `XPC_TYPE_BOOL` with the same Boolean value | `XPC_TYPE_BOOL` |
| `Int`, `Int8`, `Int16`, `Int32`, `Int64` | `XPC_TYPE_INT64` after an exact widening conversion | `XPC_TYPE_INT64`; the value must be in the requested Swift type's range |
| `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64` | `XPC_TYPE_UINT64` after an exact widening conversion | `XPC_TYPE_UINT64`; the value must be in the requested Swift type's range |
| `Int128` | one 16-byte `XPC_TYPE_DATA` containing its target-native bitwise representation | `XPC_TYPE_DATA` of exactly 16 bytes, interpreted using the co-built target ABI |
| `UInt128` | one 16-byte `XPC_TYPE_DATA` containing its target-native bitwise representation | `XPC_TYPE_DATA` of exactly 16 bytes, interpreted using the co-built target ABI |
| `Float16`, `Float`, `Double` | `XPC_TYPE_DOUBLE` | `XPC_TYPE_DOUBLE`; narrowing to `Float16` or `Float` must be exact or one of the supported special values |
| `String` | strategy-dependent; see [Strings](#strings) | the XPC kind and content required by the matching decoder strategy |
| `Data` | one `XPC_TYPE_DATA`, including zero-length data | `XPC_TYPE_DATA`; bytes are copied exactly |

When `Data` is requested, any non-`XPC_TYPE_DATA` input is a
`DecodingError.typeMismatch`. In particular, XPCCoding does not accept the
accidental historical representation consisting of an unkeyed array of
individually encoded bytes.

The `Int` and `UInt` width for the maintained Apple 26 targets is the target's
Swift ABI width. Encoding must still perform an exact conversion to the
corresponding 64-bit XPC scalar and must never truncate.

### Integer details

Signed integer types through 64 bits use only `XPC_TYPE_INT64`. Unsigned
integer types through 64 bits use only `XPC_TYPE_UINT64`. The decoder does not
coerce between signed and unsigned XPC kinds. A wrong XPC kind is a type
mismatch; a correctly-typed scalar outside the requested Swift type's range is
corrupt content.

XPC has no 128-bit integer scalar. `Int128` and `UInt128` therefore use the
first 16 bytes exposed by Swift's bitwise representation for the active target
ABI, equivalent in meaning to:

```swift
withUnsafeBytes(of: value) { bytes in
  // XPC data receives all 16 bytes in this order.
}
```

XPCCoding performs no byte swapping or byte-order normalization. A decoder must
verify the 16-byte length before reading and must not assume that the
XPC-managed pointer satisfies Swift alignment. The co-built peers' compatible
ABI—not a language-neutral signed or endian convention—is the compatibility
mechanism.

### Floating-point details

Every `Float16` and `Float` value has an exact widening representation as a
`Double`. Encoding uses that value in `XPC_TYPE_DOUBLE`; it does not allocate an
XPC data object.

The following behavior is required:

- positive and negative zero remain distinguishable;
- finite normal and subnormal values round-trip exactly;
- positive and negative infinity remain infinities with the same sign;
- finite narrowing that would round, overflow, underflow, or clamp is rejected;
  and
- every NaN encodes and decodes as a NaN.

NaN sign, signaling state, and payload are not application data in this
contract. Fixtures compare NaNs by classification rather than requiring one
bit pattern. XPCCoding performs no NaN canonicalization pass.

### Enhanced binary and element helpers

The public `efficientlyEncodeBinaryData` helpers and the enhanced XPC container
requirements emit exactly one `XPC_TYPE_DATA` containing the supplied raw
bytes. This includes `InlineArray<N, UInt8>`, raw buffer pointers, and raw
pointer/count overloads. XPCCoding copies the bytes before the method returns;
the caller's address and alignment are not represented.

For pointer/count overloads, a zero byte count emits empty XPC data and permits
a nil or non-nil pointer. A positive count requires a non-nil pointer, and a
negative count is invalid. Invalid combinations throw
`EncodingError.invalidValue` before calling XPC. Buffer-pointer overloads
instead require the caller to satisfy the standard library buffer type's own
base-address/count invariants. In every case, the caller remains responsible
for the initialized readable extent and lifetime promised by the public unsafe
API.

The `efficientlyEncodeElements` helpers are different: they encode each
`Encodable` element through the ordinary unkeyed-container rules. They produce
an XPC array, not a target-native raw dump of the element buffer.

## Strings

XPC string values and XPC dictionary keys are UTF-8 C strings and cannot
contain an embedded null byte. XPCCoding's key and value strategies are an
out-of-band agreement between the co-built peers. A raw value carries no
strategy metadata.

### Strategy compatibility

| Encoder strategy | XPC representation | Required decoder strategy |
| --- | --- | --- |
| key `.assumeAbsent` | dictionary C-string key | key `.passthrough` |
| key `.percentEscape` | escaped dictionary C-string key | key `.percentEscape` |
| value `.assumeAbsent` | `XPC_TYPE_STRING` | value `.passthrough` |
| value `.throwOnDiscovery` | `XPC_TYPE_STRING`, or an encoding error before XPC creation | value `.passthrough` |
| value `.percentEscape` | escaped `XPC_TYPE_STRING` | value `.percentEscape` |
| value `.useDataRepresentation(.utf8)` | one `XPC_TYPE_DATA` produced with Foundation `.utf8` | matching `.utf8` data strategy |
| value `.useDataRepresentation(.utf16)` | one `XPC_TYPE_DATA` produced with Foundation `.utf16` | matching `.utf16` data strategy |
| value `.useDataRepresentation(.utf32)` | one `XPC_TYPE_DATA` produced with Foundation `.utf32` | matching `.utf32` data strategy |

`.assumeAbsent` is intentionally unchecked. An embedded null scalar is
truncated by the C-string boundary and can cause value corruption or key
collisions. `.throwOnDiscovery` rejects such a string before calling XPC.
`.percentEscape` and the data strategies are total over Swift `String`.

### Percent-escape grammar

The transform scans Unicode scalars once:

- U+0000 becomes the three ASCII scalars `%00`;
- U+0025 (`%`) becomes `%25`; and
- every other scalar is copied unchanged.

Decoding scans once and accepts only `%00` and `%25`. A dangling percent or
another escape such as `%`, `%0`, `%GG`, or `%41` is corrupt content.
Decoding is not recursive: `%2500` becomes the literal text `%00`.

This corrected grammar is the only supported percent representation. Payloads
from the defective pre-contract implementation are not accepted for
cross-release compatibility. See
[Embedded Null-Byte Handling](EmbeddedNullByteHandling.md).

### Data-backed strings

The `.utf8`, `.utf16`, and `.utf32` cases delegate to Foundation
`String.data(using:allowLossyConversion:)` and
`String(bytes:encoding:)` with the matching `String.Encoding`. XPCCoding adds
no byte-order conversion, BOM normalization, or alternative input grammar.

On the maintained Swift 6.3 Apple target used to establish this contract,
representative output is:

| Value | `.utf8` | `.utf16` | `.utf32` |
| --- | --- | --- | --- |
| `""` | empty data | `ff fe` | `ff fe 00 00` |
| `"A"` | `41` | `ff fe 41 00` | `ff fe 00 00 41 00 00 00` |

These rows precisely record the maintained build behavior; they do not create
a neutral Unicode byte protocol for other toolchains or architectures. A
representation change in a future co-built release updates this document and
its fixtures rather than adding a compatibility decoder.

Malformed external UTF data is corrupt content. XPC string values are decoded
using their exact reported byte lengths. Dictionary keys are measured,
strictly decoded, and cached as strings while creating the throwing keyed
container; construction of concrete `CodingKey` values is deferred until
`allKeys` is requested. Malformed UTF-8 in either position is rejected rather
than repaired with U+FFFD.

### Dictionary-key restrictions

Every keyed-container key ultimately becomes a null-terminated XPC dictionary
key:

- empty keys are valid;
- valid non-ASCII Unicode is represented as UTF-8;
- embedded null is safe only under `.percentEscape`;
- literal percent is escaped under `.percentEscape`;
- malformed external UTF-8 is rejected; and
- two distinct Swift keys must not alias under the default
  `.percentEscape` strategy.

If the caller's concrete `CodingKey` type cannot construct a value for a valid
decoded XPC key, that key is not included in that container's `allKeys`.

## Containers and `Codable` structure

XPCCoding preserves the container requests made by the value's `Codable`
implementation. It does not impose a language-neutral schema.

| Codable operation or Swift form | XPC representation |
| --- | --- |
| keyed container | `XPC_TYPE_DICTIONARY` |
| unkeyed container | `XPC_TYPE_ARRAY` |
| single-value container | the primitive or nested XPC object produced by that value |
| nested keyed container | dictionary stored at the requested key or array index |
| nested unkeyed container | array stored at the requested key or array index |
| `[Element]` | XPC array in array-index order |
| `Set<Element>` | XPC array in the set's `Encodable` traversal order; no stable order is promised |
| `[String: Value]` | XPC dictionary using the active key strategy |
| `[Int: Value]` | XPC dictionary with the integer's decimal string as its key |
| dictionary with another key type | XPC array alternating encoded key and value in dictionary traversal order |

XPC dictionary enumeration order has no semantic meaning. Encoders, decoders,
applications, and tests must not depend on it. Structural fixture tools sort
dictionary keys only to produce a deterministic comparison; sorting does not
change the XPC representation.

Swift `Dictionary` and `Set` iteration order is likewise not a cross-process
ordering contract. Use an ordered application model when order matters.

### Optionals

- At a root, single-value position, or unkeyed position, `.none` is
  `XPC_TYPE_NULL` and `.some(value)` has `value`'s ordinary representation.
- A keyed `encodeIfPresent` or synthesized optional property omits the key for
  `.none`.
- An explicit keyed `encodeNil(forKey:)` stores `XPC_TYPE_NULL`.
- The corresponding optional decode APIs treat the documented absent/null
  cases according to Swift `Codable` semantics.

### Inheritance and super coders

`superEncoder()` obtained from a keyed container stores the superclass
representation beneath the synthesized key `"super"`. The
`superEncoder(forKey:)` form uses the caller-supplied key. An unkeyed super
encoder appends one nested element at its index.

Superclass and subclass containers otherwise follow the same keyed, unkeyed,
single-value, primitive, string, and `Data` rules as every other position.
Referencing encoders must preserve neighboring values and may not overwrite or
silently discard an earlier container; completion is tracked by
[#10](https://github.com/plx/hdxl-xpc-coding/issues/10).

### Arbitrary roots

`XPCEncoder.encode` may return any supported XPC object kind. For example, an
encoded `Int` is an XPC integer and an encoded array is an XPC array. XPCCoding
does not wrap arbitrary roots.

The low-level XPC connection send API requires its message argument to be an
XPC dictionary. An application sends a raw XPCCoding result by inserting it
beneath a key in the application's own dictionary protocol. The application
owns all outer keys, operations, errors, and any application-level versioning.

XPCCoding deliberately provides no `encodeMessage`/`decodeMessage` envelope
API. The superseded envelope proposal is recorded as
[#24](https://github.com/plx/hdxl-xpc-coding/issues/24).

## Supported standard-library representations

The following are the Foundation and standard-library types for which this
package currently provides explicit test coverage. Their Swift 6.3 `Codable`
schemas are part of the supported compilation cohort and compose with the
primitive and string rules above.

| Swift type | Logical Codable schema | Resulting XPC shape |
| --- | --- | --- |
| `Data` | XPCCoding direct specialization | one `XPC_TYPE_DATA` |
| `Date` | single `Double` equal to `timeIntervalSinceReferenceDate` | `XPC_TYPE_DOUBLE` |
| `UUID` | single uppercase canonical UUID string | the active string-value strategy's representation |
| `URL` | keyed `relative: String` plus an optional recursively encoded `base: URL` | XPC dictionary |
| `Decimal` | `exponent: CInt`, `length: CUnsignedInt`, `isNegative: Bool`, `isCompact: Bool`, and an eight-element `CUnsignedShort` mantissa | XPC dictionary whose fields use the primitive table |
| `Optional` | position-dependent nil/some behavior | null, omission, or the wrapped representation as described above |
| `Array` | ordered unkeyed elements | XPC array |
| `Dictionary` | keyed for `String`/`Int` keys, otherwise alternating unkeyed key/value elements | XPC dictionary or array as described above |
| `Set` | unkeyed traversal | XPC array with unspecified element order |

These schemas describe Swift 6.3 behavior, not a promise to emulate Foundation
across independently versioned toolchains. Relevant Swift Foundation sources
include
[`Date`](https://github.com/swiftlang/swift-foundation/blob/release/6.3.1/Sources/FoundationEssentials/Date.swift),
[`Decimal`](https://github.com/swiftlang/swift-foundation/blob/release/6.3.1/Sources/FoundationEssentials/Decimal/Decimal%2BConformances.swift),
[`URL`](https://github.com/swiftlang/swift-foundation/blob/release/6.3.1/Sources/FoundationEssentials/URL/URL.swift),
and
[`UUID`](https://github.com/swiftlang/swift-foundation/blob/release/6.3.1/Sources/FoundationEssentials/UUID.swift).

Other `Encodable` types—including application models and standard-library
types not listed here—are represented exactly according to the container and
primitive calls their Swift 6.3 implementation makes. Their higher-level schema
belongs to the co-built application protocol, not XPCCoding.

## Configuration and non-payload state

Encoder and decoder key/value strategies must match out of band. `XPCCodec`
exists to construct a compatible pair. No strategy identifier is serialized.
The codec's immutable configuration is the authoritative source of its direct
operation behavior. Its coder factories return fresh, initially compatible
facades; independently reconfiguring one of those facades does not affect the
codec and can make that facade incompatible with other coders.

`Encoder.userInfo` and `Decoder.userInfo` affect application `Codable`
behavior but are never serialized as XPCCoding metadata. Public exposure and
recursive propagation are tracked separately by
[#27](https://github.com/plx/hdxl-xpc-coding/issues/27).

## Decoder safety and errors

XPC input can cross a privilege or trust boundary even when every peer is on
one machine. Same-build scope does not weaken malformed-input handling.

`XPCDecoder.ResourceLimits.standard` applies these finite ceilings independently
to every top-level decode:

| Resource | Standard maximum |
| --- | ---: |
| recursive decoding transitions below the root | 128 |
| elements in one XPC array or dictionary | 65,536 |
| total XPC-object visits, including the root | 262,144 |
| encoded bytes in one XPC string, data-backed string, or dictionary key | 8 MiB |
| bytes in one XPC data value decoded as data or a data-backed primitive | 32 MiB |
| cumulative decoded string, data, and dictionary-key bytes | 64 MiB |

These values leave generous room for application-owned local IPC messages while
placing finite ceilings below process-exhaustion territory. Applications with a
deliberately different local message-size policy can construct custom limits
and pass them to `XPCDecoder`. Every field is nonnegative, and the total-node
maximum is at least one because the root consumes one visit.

One shared state object performs constant-time accounting as decoding touches
the graph. There is no graph prewalk, object-identity set, envelope, or
per-payload version field. The decoder snapshots the configured limits at the
start of each operation; child decoders share that snapshot and separate
top-level operations do not share counters.

Checks occur before recursive decoding, container enumeration, or string/data
copying and allocation. Dictionary keys are byte-checked when a keyed container
is requested, before `allKeys` can allocate Swift strings. A recursive generic
single-value decode counts as another nesting transition even when it
reinterprets the same XPC object.

Node and byte budgets measure work, not unique object identities. Repeated
traversal consumes them again, so shared acyclic children remain valid while
self-cycles and multi-object cycles are bounded by the nesting ceiling. A
decoder's limits are local behavior: they need not match the encoder or peer,
are not serialized, and changing them does not create a payload-format version.

Errors follow this taxonomy at every root and container position:

| Condition | Error |
| --- | --- |
| absent keyed value | `DecodingError.keyNotFound` |
| explicit XPC null requested as nonoptional | `DecodingError.valueNotFound` |
| wrong XPC object kind | `DecodingError.typeMismatch` |
| correct kind with invalid length, range, content, UTF encoding, escape grammar, or exhausted resource limit | `DecodingError.dataCorrupted` |

Every error carries the complete bounded coding path and useful context without
recursively describing a hostile graph. Final taxonomy normalization is
tracked by [#18](https://github.com/plx/hdxl-xpc-coding/issues/18).

On encoding, XPCCoding-originated incompatibilities such as
`.throwOnDiscovery` and invalid public pointer/count combinations use
`EncodingError.invalidValue` with the active coding path. User-thrown errors
are preserved as user errors; normalization is tracked by
[#14](https://github.com/plx/hdxl-xpc-coding/issues/14).

## Current implementation inventory

This table distinguishes the accepted representation from current
implementation state. A deviation is not a legacy input promise.

| Area | Current state | Tracking |
| --- | --- | --- |
| null, Boolean, `Int`, `Int64`, `UInt`, `UInt64`, `Double` | representation already matches | contract fixtures in [#25](https://github.com/plx/hdxl-xpc-coding/issues/25) |
| narrow integers, `Float16`, and `Float` | canonical XPC scalar kinds and checked narrowing match the contract | implemented and covered by [#23](https://github.com/plx/hdxl-xpc-coding/issues/23) |
| `Int128`/`UInt128` | exact native 16-byte data representation and alignment-safe checked extraction match the contract | implemented and covered by [#23](https://github.com/plx/hdxl-xpc-coding/issues/23) |
| ordinary generic `Data` | direct specialization produces one XPC data object at every generic boundary | implemented and covered by [#20](https://github.com/plx/hdxl-xpc-coding/issues/20) |
| enhanced raw binary and element helpers | output shape and pointer/count validation match the contract | [#11](https://github.com/plx/hdxl-xpc-coding/issues/11) and fixture coverage in [#25](https://github.com/plx/hdxl-xpc-coding/issues/25) |
| percent escaping | corrected bijection is implemented | [#7](https://github.com/plx/hdxl-xpc-coding/issues/7) |
| strict external XPC string/key UTF-8 | exact-length validation rejects malformed bytes before values or `allKeys` are exposed | implemented and covered by [#16](https://github.com/plx/hdxl-xpc-coding/issues/16) |
| decoder budgets and cycles | finite operation-local budgets share counters across child paths; depth accounting bounds cycles without rejecting shared acyclic children | regression coverage and [#9](https://github.com/plx/hdxl-xpc-coding/issues/9) |
| decoder error taxonomy | absent keys, explicit nulls, wrong kinds, and malformed correct-kind content use the documented standard `DecodingError` cases at exact paths | implemented and covered by [#18](https://github.com/plx/hdxl-xpc-coding/issues/18) |
| referencing/super encoders | repeated-container reuse can lose data | [#10](https://github.com/plx/hdxl-xpc-coding/issues/10) |
| codec configuration ownership | mutable stored coder references can diverge | [#21](https://github.com/plx/hdxl-xpc-coding/issues/21) |
| independent structural fixtures | bidirectional, deterministic fixtures inspect encoder output and construct decoder input without sharing codec implementation | [`RepresentationFixtureTests.swift`](../Tests/XPCCodingTests/Fixtures/RepresentationFixtureTests.swift) and [`XPCStructuralFixture.swift`](../Tests/XPCCodingTests/Fixtures/XPCStructuralFixture.swift) |
| real local process-boundary validation | a co-built application and embedded service inspect physical peer-side shapes and complete bounded request/reply and remote-error exchanges | [`XPCProcessBoundary`](../IntegrationTests/XPCProcessBoundary/README.md) and [#26](https://github.com/plx/hdxl-xpc-coding/issues/26) |
| deterministic property and hostile-input fuzzing | seeded generation, mutation of a reviewed corpus, and every historical reproducer run in a child process under wall-clock, CPU, and memory bounds | [`Fuzzing`](../IntegrationTests/Fuzzing/README.md) and [#43](https://github.com/plx/hdxl-xpc-coding/issues/43) |
| regression-first baseline evidence | one probe, built unchanged against the audit revision `813c52e` and against the working tree, requires each historical defect to reproduce there and to be absent here | [`BaselineProbe`](../IntegrationTests/BaselineProbe/README.md) and [#43](https://github.com/plx/hdxl-xpc-coding/issues/43) |
| library-owned versioned envelope | intentionally absent and out of scope | [#24](https://github.com/plx/hdxl-xpc-coding/issues/24) |

## Fixture derivation rules

Same-build fixture work can derive every expectation from this document:

1. Use the exact XPC kind in the primitive or container table.
2. Record integer and Boolean scalar values directly.
3. Compare ordinary data byte-for-byte.
4. Derive 128-bit data from the active target's 16-byte Swift bitwise
   representation; do not byte-swap it.
5. Compare finite doubles exactly, distinguish signed zero, compare infinities
   by sign, and compare NaNs by classification.
6. Apply the selected string strategy exactly, including Foundation-backed
   data representations.
7. Preserve array order.
8. Sort dictionary entries only in the fixture description/comparator.
9. Construct decoder fixtures directly with XPC creation APIs rather than
   calling `XPCEncoder`.
10. Do not load fixtures from another package release or treat fixture files as
    persistent payloads.

The executable inventory lives in
[`RepresentationFixtureTests.swift`](../Tests/XPCCodingTests/Fixtures/RepresentationFixtureTests.swift).
Its expected trees are typed, review-visible Swift source. The test-only
[`XPCStructuralFixture`](../Tests/XPCCodingTests/Fixtures/XPCStructuralFixture.swift)
walks complete encoder-produced XPC trees directly and constructs fresh
decoder inputs with XPC creation APIs. It sorts dictionary keys for comparison,
compares data exactly, preserves non-NaN floating-point bit patterns, and
compares NaNs by classification. It is deliberately not a `Codable` fixture
schema, a generated snapshot, a persisted format, or a library API.

## Contribution rule

Every change that affects an emitted or accepted XPC object kind, scalar value,
data bytes, string transform, container shape, standard-library schema,
configuration requirement, or malformed-input classification must update:

1. this document;
2. the
   [bidirectional same-build structural fixtures](../Tests/XPCCodingTests/Fixtures/RepresentationFixtureTests.swift);
3. affected public API or README documentation; and
4. the change log or migration notes when the change ships.

The contract and fixtures change in the same pull request as the
representation-affecting implementation. Fixtures are reviewed expectations;
they are never silently regenerated to match current output.

Because peers are co-built, a reviewed representation change does not require
a format version or compatibility decoder. It does require rebuilding and
deploying every participating application and XPC service together.
