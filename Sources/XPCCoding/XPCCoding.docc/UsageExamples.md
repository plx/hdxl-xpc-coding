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

Pick strategies based on trust level and interoperability requirements.

```swift
// Fastest, but unsafe for embedded null bytes.
let fastEncoder = XPCEncoder(
    stringKeyStrategy: .assumeAbsent,
    stringValueStrategy: .assumeAbsent
)
let fastDecoder = XPCDecoder(
    stringKeyStrategy: .passthrough,
    stringValueStrategy: .passthrough
)

// Safe defaults: round-trips embedded null bytes via percent escaping.
let safeCodec = XPCCodec(configuration: .init(
    stringKeyStrategy: .percentEscape,
    stringValueStrategy: .percentEscape
))

// Strict values: fail fast if a value contains an embedded null byte.
let strictEncoder = XPCEncoder(
    stringKeyStrategy: .percentEscape,
    stringValueStrategy: .throwOnDiscovery
)

// Preserve value bytes as xpc_data_t instead of xpc_string_t.
let dataBackedCodec = XPCCodec(configuration: .init(
    stringKeyStrategy: .percentEscape,
    stringValueStrategy: .useDataRepresentation(.utf8)
))
```

### Integration with XPC Services

A common pattern is to store your encoded payload in an XPC dictionary message.

```swift
import XPC
import XPCCoding

struct Request: Codable { let command: String }
struct Response: Codable { let ok: Bool }

let codec = XPCCodec()
let request = Request(command: "ping")

// Client side: encode payload and attach to message dictionary.
let message = xpc_dictionary_create(nil, nil, 0)
let payload = try codec.encode(request)
xpc_dictionary_set_value(message, "payload", payload)

// Send `message` through your connection API.
// ...

// Server/reply side: read payload back and decode.
if let responsePayload = xpc_dictionary_get_value(message, "payload") {
    let response = try codec.decode(Response.self, from: responsePayload)
    _ = response
}
```

## See Also

- ``XPCCodec``
- ``XPCEncoder``
- ``XPCDecoder``
