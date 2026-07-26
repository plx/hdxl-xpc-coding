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
