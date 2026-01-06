# Relationship to `CodableXPC`

When I started out to write an `Encoder`/`Decoder` pair for `xpc_object_t`, I quickly discovered the pre-existing [CodableXPC](https://github.com/daniel-grumberg/CodableXPC) package.

My initial plan was simply to fork the project, ensure it handled Swift 6, expand the unit test suite to verify its correctness, and then open a PR back to the original project. 

After further exploration, however, I discovered an API design adjustment I wanted to make as well as some limitations I wanted to address.
As such, I shifted from "fork mode" to "rewrite mode", treating the original as both a starting point and as a reference for encoder and decoder internals.

## Major Changes

### Adopt the Facade Pattern

The way Apple structures the `JSONEncoder` and `JSONDecoder` APIs is via a "facade" pattern.

For example, the `JSONEncoder` type is a `TopLevelEncoder`, but not itself an `Encoder`.
The difference is subtle, but important:

```swift
let encoder = JSONEncoder()
// this doesn't work, b/c `JSONEncoder` is not an `Encoder`
try myValue.encode(to: encoder)
// ...and even if it did, there's no API on `Encoder` to get the final archive

// this does work, though, b/c `JSONEncoder` *is* a `TopLevelEncoder`
let json = try encoder.encode(myValue)
```

When you call `JSONEncoder.encode(_:)`, what actually happens is analogous to this:

```swift
func encode<T: Encodable>(_ value: T) throws -> Data { 
  var encoder = _JSONEncoder() // internal `Encoder`-conforming type
  // skipped: configuring the `encoder` to match the facade's configuration
  try value.encode(to: encoder) // let `value` call `encode(to:)` on `encoder` (which will show up as an `Encoder`, as per the signature)
  return encoder.finalArchive // <- API *not* on `Encoder`, and specific to `the concrete _JSONEncoder` type
}
```

The `XPCCoding` library follows this pattern, too, with `XPCEncoder` and `XPCDecoder` conforming to `TopLevelEncoder` and `TopLevelDecoder` (respectively), and the corresponding `Encoder`/`Decoder`-conforming `_XPCEncoder` and `_XPCDecoder` types kept package-internal.
This is a change from the original `CodableXPC` library, which publicly exposed an `Encoder`-conforming `XPCEncoder` type and a `Decoder`-conforming `XPCDecoder` type.

Aside from achieving consistency with platform idioms, adopting the facade pattern has the additional benefit of protecting the user from unintentional misuse of the `Encoder` and `Decoder` values.
To unpack that a bit, the API contract on `Encoder` *essentially* precludes re-use of an encoder[^reuse-nuances].
Although this responsibility could be foisted upon the user, it's more-reliable to have the library assume responsibility for the invariant.

[^reuse-nuances]: The reason I need to say *essentially* is because a limited form of re-use is permitted when encoding superclasses; without that nuance to consider, it would indeed be accurate to say that re-use is forbidden.

### Arbitrary Root-Value Types

An unexpected limitation of `CodableXPC` is that its encoder and decoder implicitly require the top-level value to encode itself as a dictionary-like `xpc_object_t` value (in other words, that the root value use a `KeyedContainer` when encoding itself, and expect to find a dictionary-like `xpc_object_t` when decoding).

Even though Apple's serialization APIs doesn't *forbid* such limitations, in this case there's no inherent reason to impose them, either, so I chose not to. This minimizes surprise for users of the package, and is essentially "free" given the flexibility of the underlying XPC representation.

### Strings With Embedded Null-Bytes

The underlying XPC objects use strings for two distinct roles:

- as "keys" in dictionary-like `xpc_object_t` values (which, indeed, *only* support string keys)
- as "values" (e.g. as string-like `xpc_object_t` values, which can be used stand alone or as values in xpc arrays or dictionaries)

For both roles, the underlying XPC API only supports "C-style" strings (i.e. a `char *` terminated by a null-byte, in C terminology).

As is well-known, C-style strings cannot directly represent strings with embedded null bytes, because the embedded null-byte would be interpreted as the string's terminator:

- your string's data: `[h, e, l, l, o, 0x00, w, o, r, l, d, 0x00]`
- C-style string interpretation: `[h, e, l, l, o]` (truncated at first null-byte)

Swift's native strings have no such limitation, however, which can pose a problem when used naively with XPC:

```swift
let string = "hello\0world" // string with embedded null-byte
let xpcObject = string.withCString { cString in
  xpc_string_create(cString)
}
// contents of `xpcObject` are now truncated to "hello"
```

The original `CodableXPC` library used this "naive" approach, which meant that it would silently truncate string keys and values containing embedded null bytes[^not-a-criticism]. 
Although a defensible approach, it's inconsistent with the behavior of `JSONEncoder` and `JSONDecoder`. 
It's also a risk for users of the library, who may not have full control over the content of the values they're encoding—for example, when encoding messages from users, the system, or other untrusted sources.

As such, in `XPCCoding` I ensured the encoder and decoder can handle embedded null bytes correctly for both string keys and string values.
Additionally, I made this handling configurable, with safe default strategies for keys and values.

[^not-a-criticism]: I don't mean to criticize the original library authors here, because it's a very defensible approach—strings with embedded null bytes are rare, often considered "pathological", and are the kind of thing you'd generally prefer to avoid having or using.
