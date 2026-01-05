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

*(Placeholder: examples of using the enhanced APIs)*

```swift
// Conceptual example
var container = encoder.singleValueContainer()
if var enhanced = container as? XPCEnhancedSingleValueEncodingContainer {
    try enhanced.directlyEncodeXPCData(pointer, count: byteCount)
}
```

### Convenience Extensions

*(Placeholder: describe the public-facing extensions on standard containers)*

## See Also

- ``XPCEnhancedSingleValueEncodingContainer``
- ``XPCEnhancedUnkeyedEncodingContainer``
