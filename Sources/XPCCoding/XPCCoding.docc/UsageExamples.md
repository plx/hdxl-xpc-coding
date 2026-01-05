# Usage Examples

Common usage patterns for encoding and decoding with XPCCoding.

## Overview

This article provides practical examples of using XPCCoding in your applications.

### Basic Encoding and Decoding

Use ``XPCEncoder`` and ``XPCDecoder`` directly for simple cases:

```swift
struct Message: Codable {
    let id: Int
    let content: String
}

let encoder = XPCEncoder()
let decoder = XPCDecoder()

let message = Message(id: 1, content: "Hello")
let encoded = try encoder.encode(message)
let decoded = try decoder.decode(Message.self, from: encoded)
```

### Using the Codec

For guaranteed encoder/decoder compatibility, use ``XPCCodec``:

```swift
let codec = XPCCodec(configuration: .init(
    stringKeyStrategy: .percentEscape,
    stringValueStrategy: .percentEscape
))

let encoded = try codec.encode(myValue)
let decoded = try codec.decode(MyType.self, from: encoded)
```

### Configuring String Strategies

*(Placeholder: examples of different string handling strategies)*

### Integration with XPC Services

*(Placeholder: examples of using XPCCoding with XPC connections)*

## See Also

- ``XPCCodec``
- ``XPCEncoder``
- ``XPCDecoder``
