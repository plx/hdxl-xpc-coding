# Embedded Null-Byte Handling

## Background: XPC String Usage

The XPC system uses "semantic" strings in two distinct roles:

- as string-like `xpc_object_t` values (which directly correspond to "strings")
- as *keys* in dictionary-like `xpc_object_t` values (which, indeed, *only* support string keys)

For both roles, the XPC API *only* supports C-style strings (e.g. a `char *` terminated by a null-byte, in C terminology).

Since Swift strings *can* contain null bytes, this creates an impedance mismatch that, in turn, can lead to unexpected truncation if we were to naively call through to the underlying C API. 
For example, this is what the original `CodableXPC` library did, and the unit tests I added verified the expected truncation was occurring: string keys and values containing embedded null bytes *would* "successfully" get encoded and decoded, but would fail to round-trip correctly due to truncation. 

Although it would have been possible to simply document this limitation and move on, that would have been inconsistent with the rest of the ecosystem:

- `String` supports null bytes just fine
- `JSONEncoder` and `JSONDecoder` both handle null bytes (e.g. escaping and unescaping, etc.)

Since I wanted this library to encode-and-decode the same set of values as, say, `JSONEncoder` and `JSONDecoder`, I extended the original library in order to handle such strings. 

## Strategies

Analogously to `JSONEncoder` and `JSONDecoder`, both our `XPCEncoder` and `XPCDecoder` have configurable "strategies" for customizing their behavior (...and with distinct strtegy-enumeration types for the encoder and decoder, again analogous to `JSONEncoder` and `JSONDecoder`).

Additionally, we support distinct strategies for *string values* and *string keys*; having a shared strategy concept would be more-elegant, but is unfortunately blocked by aspects of the `Encoder`/`Decoder` APIs—will explain when we reach the "string key strategies" section.

### String Value Strategies

For string *values*, we have the following options during encoding:

- `.assumeAbsent`: naively assume there are no null bytes, and directly create "xpc strings" from the `String`'s c-string representation
- `.throwOnDiscovery`: throw an error if we discover any null bytes, and otherwise behave as `.assumeAbsent`
- `.percentEscape`: encode null and literal-percent scalars with XPCCoding's
  strict percent-escape grammar, representing data as an "xpc string"
- `.useDataRepresentation(.utf8|.utf16|.utf32)`: represent strings as "xpc data"  (in the chosen encoding), not as an xpc string

For decoding, we have the following options:

- `.passthrough`: expect an XPC string and strictly decode its exact reported
  byte length as UTF-8
- `.percentEscape`: expect an xpc string encoded with XPCCoding's strict
  percent-escape grammar and reverse that transform
- `.useDataRepresentation(.utf8|.utf16|.utf32)`: expect binary data (in the chosen encoding), and create a string from it

### String Key Strategies

For string *keys*, we have the following options during encoding:

- `.assumeAbsent`: naively assume there are no null bytes, and directly create "xpc strings" from the `String`'s c-string representation
- `.percentEscape`: encode null and literal-percent scalars with XPCCoding's
  strict percent-escape grammar, representing data as an "xpc string"

For decoding, we have the following options:

- `.passthrough`: strictly decode each complete XPC dictionary key as UTF-8
- `.percentEscape`: expect an xpc string encoded with XPCCoding's strict
  percent-escape grammar and reverse that transform

#### Why No `.useDataRepresentation(_)`

The reason we don't have `.useDataRepresentation(_)` for keys is because the XPC APIs *only support string keys*—there's just no way to use binary data as a key, period.

#### Why No `.throwOnDiscovery`

The reason we don't have `.throwOnDiscovery` for keys is due to some API constraints in the "container" APIs:

- the `KeyedEncodingContainer` protocol has throwing methods for encoding *values* (e.g. `func encode<T: Codable>(_ value: T, forKey key: Key) throws`, etc.)
- the `KeyedEncodingContainer` protocol has *non*-throwing methods for creating nested containers (e.g. `func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey>` is non-throwing, etc.)

As such, providing a `.throwsOnDiscovery` strategy for keys would be making promises our implementation can't keep:

- we *can* throw on discovering keys with null bytes when encoding values
- we *cannot* throw on discovering keys with null bytes when creating nested containers (or super encoders, etc.)

That's why there's no `.throwOnDiscovery` strategy for keys.

### The Exact Behavior of `.assumeAbsent`

`.assumeAbsent` is deliberately retained, and deliberately lossy: it is the
minimum-overhead path for callers who know their strings and keys are null-free.
Because it is retained, its behavior is *asserted exactly* rather than tolerated
as a known issue (see [Validation Recipes](ValidationRecipes.md) for the
zero-known-issue policy this supports).

For string **values**, encoding hands the `String` to `xpc_string_create` as a C
string, so the representation ends at the first null byte:

| probe | decoded under `.assumeAbsent` |
| --- | --- |
| `"\0"` | `""` |
| `"Hello\0world"` | `"Hello"` |
| `"bar\0"` | `"bar"` |
| `"\0baz"` | `""` |
| `"q\0u\0u\0x"` | `"q"` |

This holds identically for a bare `String` and for single-value-, unkeyed-, and
keyed-container-wrapped strings, and the tests additionally assert that the
result is *not* equal to the source — `.assumeAbsent` must stay observably
distinct from the safe strategies, which round-trip these probes exactly.

For string **keys**, the same truncation applies, and distinct source keys can
therefore collide. Encoding `{"\0": 1, "bar\0": 2, "\0baz": 3, "q\0u\0u\0x": 4}`
in that order yields a three-entry dictionary, because `"\0"` and `"\0baz"` both
truncate to the empty key and the later write wins:

```text
{"": 3, "bar": 2, "q": 4}
```

Decoding that back into the original four fields reads `3` for both the first and
third field. The test fixture writes its keys in an explicit order so this
collision is a property of the fixture rather than of synthesized encoding order.

Because raw null bytes in a test transcript are unreadable and hostile to log
tooling, the embedded-null test probes carry a null-free label for test-case
names and compare UTF-8 byte arrays in their assertions; the canonical test
runner fails the run if a raw NUL byte reaches the output at all.

### Key-Strategy Performance

The key passthrough implementation switches on the representation before it
invokes the percent-escape transform. Consequently, `.assumeAbsent` encoding
and paired `.passthrough` lookup do not evaluate the null or percent count
helpers and do not allocate an escaped copy.

The release benchmark suite covers 1,024 short ASCII keys and sixteen 4 KiB
ASCII keys. Each fixture measures encoding, a known-key decode (including
keyed-container construction), and a complete dictionary decode under both
strategy pairs.

On a Mac16,5 using Xcode 26.6 and Apple Swift 6.3.3, 31 samples with 5 warmup
batches and a 200 ms target produced the following comparison against a
source-only synthetic legacy variant that performed the null-count scan before
strategy dispatch:

| fixture | encode | known-key lookup | full decode |
| --- | ---: | ---: | ---: |
| 1,024 short keys | 5.06% faster | 0.47% slower (noise) | 3.38% faster |
| sixteen 4 KiB keys | 50.79% faster | 30.86% faster | 47.40% faster |

The repository comparator accepted all six changed-path scenarios at its 10%
threshold. The clean reports identify candidate
`6820f8f04eaceb371fdf6ff477972e224c8399cf`, synthetic legacy commit
`81fce74513eb151fccf2100a9af287c954296ad8`, and shared benchmark-harness tree
`b27be7312ee7ab9996af20ca94a547b290f6b2c3`.

A same-revision comparison also quantifies the extra work performed by the safe
strategy rather than presenting `.assumeAbsent` as an unbounded performance
claim:

| fixture | direct encode lower than safe encode | passthrough lookup lower than safe lookup | passthrough decode lower than safe decode |
| --- | ---: | ---: | ---: |
| 1,024 short keys | 25.49% | 70.05% | 29.32% |
| sixteen 4 KiB keys | 94.87% | 99.15% | 96.64% |

These results do not change the safety recommendation: `.percentEscape`
remains the standard strategy, while `.assumeAbsent` is appropriate only when
the application can uphold its null-free precondition.

### Percent-Escape Grammar and Pre-1.0 Compatibility

The `.percentEscape` transform is shared by string keys and string values. It
scans Unicode scalars and always encodes the two reserved scalars:

- U+0000 is encoded as `%00`;
- U+0025 (`%`) is encoded as `%25`; and
- every other scalar is preserved.

Decoding is a single, non-recursive pass that accepts only `%00` and `%25`.
Dangling, malformed, or unsupported sequences such as `%`, `%0`, `%GG`, and
`%41` are rejected. Thus `%2500` decodes to the literal text `%00`, not to a
null scalar.

Both `.passthrough` and `.percentEscape` validate the external UTF-8 bytes
before interpreting them. Malformed XPC string values and dictionary keys
throw `DecodingError.dataCorrupted`; they are never repaired with U+FFFD.
Dictionary keys are validated and cached as decoded strings when the throwing
keyed container is created, before its nonthrowing `allKeys` property can expose
them. Construction of the container's concrete `CodingKey` values is deferred
until `allKeys` is requested.

This representation intentionally corrects the pre-1.0 behavior, which left
literal percent signs unescaped and then applied general URL percent-decoding.
That earlier behavior was not injective: it could corrupt values and collapse
distinct dictionary keys. No compatibility promise is made for payloads
created by that defective pre-release representation.

## Compatibility, Codecs, and Defaults

As with other `Encoder`/`Decoder`-based systems, successful round-tripping is only guaranteed between instances with "compatible configurations"; tl;dr: if your encoder is using `.useDataRepresentation(.utf16)`, your decoder *must* also be using `.useDataRepresentation(.utf16)` (and so on and so forth).

This configuration agreement is deliberately out of band. XPCCoding targets
applications and XPC services that are designed, configured, built, and
deployed together on one host; it does not serialize strategy metadata or
support independently versioned peers. See
[XPCCoding XPC Object Representation](WireFormat.md).

To simplify compatible operations, the library provides an `XPCCodec` type:

- its immutable `Configuration` is the sole persistent source of string-key
  and string-value behavior;
- its direct `encode` and `decode` operations always derive their behavior from
  that configuration; and
- `makeEncoder()` and `makeDecoder()` return fresh, initially compatible
  facades when a caller needs independent customization.

Mutating a factory result affects only that result. Once independently
reconfigured, that result is not guaranteed to remain compatible with the
codec or with another factory result.

Additionally, the default configurations for the codec and the individual top-level encoder and decoder types are all mutually compatible—you should only need to worry about compatibility if you're adjusting the configurations, but you'll be ok as long as you're using the codec-level API.
