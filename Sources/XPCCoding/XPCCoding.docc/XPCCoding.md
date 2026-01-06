# ``XPCCoding``

Serialize and deserialize Swift `Codable` types to and from `xpc_object_t` values.

## Overview

`XPCCoding` provides mechanisms for encoding `Encodable` types to `xpc_object_t` and decoding `Decodable` types from `xpc_object_t` archives.

The intended use case is for convenient transmission of `Codable` types between processes via Apple's XPC system, with higher efficiency than, say, using JSON as the transfer format.
This package supports all platforms for which XPC is *available* (macOS, iOS, Catalyst), but will likely only be *useful* on macOS.

The library follows the design patterns established by `JSONEncoder` and `JSONDecoder`, with the addition of an ``XPCCodec`` concept that streamlines creation of compatible encoder/decoder pairs.

For further discussion of the internal design and implementation, see <doc:InternalDesign>.

## Package Status

This package is presumptively-complete and thoroughly tested, but has yet to receive extensive real-world usage.
As such, I encourage you to consider using it, but in the spirit of *caveat coder*.

## Acknowledgements

This project started as a fork of [https://github.com/daniel-grumberg/CodableXPC](https://github.com/daniel-grumberg/CodableXPC), and has subsequently evolved into a near-total rewrite. 
Even so, the original project's influence remains visible in the project's internals, and we necessarily inherit the original project's license, too.

For more information on the relationship between this project and the original, see <doc:CodableXPCRelationship>.

## Usage Examples

Basic usage closely resembles that of `JSONEncoder` and `JSONDecoder`:

```swift
import XPCCoding

struct Message: Equatable, Codable {
    let id: Int
    let content: String
}

// the default configurations are mutually-compatible:
let encoder = XPCEncoder()
let decoder = XPCDecoder()

let message = Message(id: 1, content: "Hello")
let encoded = try encoder.encode(message) // `xpc_object_t`
let decoded = try decoder.decode(Message.self, from: encoded) // back to `Message`
assert(message == decoded) // this should succeed
```

For further usage examples, see <doc:UsageExamples>.

## Topics

### Encoding

Encoding is performed via the ``XPCEncoder`` type, which conforms to [Combine's `TopLevelEncoder` protocol](https://developer.apple.com/documentation/combine/toplevelencoder).

- ``XPCEncoder``: facade used for encoding top-level (root) values *to* `xpc_object_t`
- ``XPCEncoder/StringKeyStrategy``: encoding-time strategies for string keys
- ``XPCEncoder/StringValueStrategy``: encoding-time strategies for string values

### Decoding

Decoding is performed via the ``XPCDecoder`` type, which conforms to [Combine's `TopLevelDecoder` protocol](https://developer.apple.com/documentation/combine/topleveldecoder).

- ``XPCDecoder``: facade used for decoding top-level (root) values *from* `xpc_object_t`
- ``XPCDecoder/StringKeyStrategy``: decoding-time strategies for string keys
- ``XPCDecoder/StringValueStrategy``: decoding-time strategies for string values

### Codec

The ``XPCCodec`` type provides a convenient way to create matched encoder/decoder pairs with compatible configurations.

- ``XPCCodec``: convenience for creating matched encoder/decoder pairs
- ``XPCCodec/Configuration``: unified configuration for encoder/decoder pairs
- ``XPCCodec/StringKeyStrategy``: codec-level configuration for string keys
- ``XPCCodec/StringValueStrategy``: codec-level configuration for string values

### Efficient Binary Encoding

When working with binary data represented as length/pointer pairs, you can use avoid the overhead of transient `Data` wrappers via `XPCCoding`'s extension methods like ``SingleValueEncodingContainer/efficientlyEncodeBinaryData(_:count:)-(UnsafeRawPointer,_)``. For more information, see <doc:EnhancedBinaryAPIs>.
