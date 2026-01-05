# ``XPCCoding``

Serialize and deserialize Swift `Codable` types to and from `xpc_object_t` values.

## Overview

XPCCoding provides a mechanism for encoding Swift `Codable` values to `xpc_object_t` and decoding them back, enabling type-safe inter-process communication via Apple's XPC system.

The library follows the design patterns established by `JSONEncoder` and `JSONDecoder`, with the addition of a unified ``XPCCodec`` facade that ensures encoder/decoder configuration compatibility.

### Key Features

- **Familiar API**: Mirrors `JSONEncoder`/`JSONDecoder` patterns
- **Codec Facade**: ``XPCCodec`` provides matched encoder/decoder pairs
- **String Handling**: Configurable strategies for embedded null bytes
- **Binary Data**: Enhanced APIs for efficient binary data encoding

## Topics

### Codec

- ``XPCCodec``
- ``XPCCodec/Configuration``
- ``XPCCodec/StringKeyStrategy``
- ``XPCCodec/StringValueStrategy``

### Encoding

- ``XPCEncoder``
- ``XPCEncoder/StringKeyStrategy``
- ``XPCEncoder/StringValueStrategy``
- ``TransientEncoderError``

### Decoding

- ``XPCDecoder``
- ``XPCDecoder/StringKeyStrategy``
- ``XPCDecoder/StringValueStrategy``

### Enhanced Binary Encoding

- ``XPCEnhancedSingleValueEncodingContainer``
- ``XPCEnhancedUnkeyedEncodingContainer``

### Articles

- <doc:InternalDesign>
- <doc:UsageExamples>
- <doc:EnhancedBinaryAPIs>
- <doc:CodableXPCRelationship>
