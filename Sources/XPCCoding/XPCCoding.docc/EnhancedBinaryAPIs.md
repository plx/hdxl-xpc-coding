# Enhanced Binary Data APIs

Efficiently encode binary data without intermediate copies.

## Overview

XPCCoding provides enhanced encoding container protocols that allow direct encoding of binary data from unsafe pointers, bypassing the need to wrap data in `Foundation.Data` objects.

### Background

The standard `Codable` API requires encoding binary data via `Data` objects. However, when working with XPC:

- The underlying XPC APIs accept "length and pointer" arguments
- Creating a `Data` wrapper just to pass to the encoder is unnecessary overhead
- The binary data is copied into the `xpc_object_t` regardless

### Enhanced Container Protocols

XPCCoding defines two protocols that extend the standard encoding containers:

- ``XPCEnhancedSingleValueEncodingContainer``
- ``XPCEnhancedUnkeyedEncodingContainer``

### Usage Pattern

Use the convenience helpers on standard containers. They detect enhanced container support and choose the efficient path automatically.

```swift
struct Blob: Encodable {
    let pointer: UnsafeRawPointer?
    let count: Int

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.efficientlyEncodeBinaryData(pointer, count: count)
    }
}
```

For keyed and unkeyed contexts:

```swift
var keyed = encoder.container(keyedBy: CodingKeys.self)
try keyed.efficientlyEncodeBinaryData(bytesPointer, count: byteCount, forKey: .payload)

var unkeyed = encoder.unkeyedContainer()
try unkeyed.efficientlyEncodeBinaryData(bytesPointer, count: byteCount)
```

### Convenience Extensions

Public extension methods exist on:

- `SingleValueEncodingContainer`
- `UnkeyedEncodingContainer`
- `KeyedEncodingContainer`

When the backing container conforms to an enhanced protocol, the method calls `directlyEncodeXPCData(...)`. Otherwise it falls back to standard `Data` encoding behavior, preserving correctness on non-XPC encoders.

## Safety Notes

- This optimization avoids transient `Data` wrappers; it is not zero-copy across the full pipeline.
- XPC still copies payload bytes into the resulting `xpc_data_t`.
- Pointer lifetimes must remain valid for the duration of the encode call.

## See Also

- ``XPCEnhancedSingleValueEncodingContainer``
- ``XPCEnhancedUnkeyedEncodingContainer``
