# Internal Design

An overview of the internal architecture and implementation strategy.

## Overview

This article discusses the internal design of XPCCoding, explaining how the encoder and decoder are structured and why certain architectural decisions were made.

### Facade Pattern

Like `JSONEncoder` and `JSONDecoder`, XPCCoding separates the public-facing API from the internal `Encoder`/`Decoder` conformances:

- ``XPCEncoder`` and ``XPCDecoder`` are facades for configuration and top-level encoding/decoding
- `_XPCEncoder` and `_XPCDecoder` (internal) conform to `Encoder` and `Decoder`
- Container types handle keyed, unkeyed, and single-value encoding/decoding

### The Codec Concept

The ``XPCCodec`` type provides an additional layer that ensures encoder/decoder compatibility:

- Configuration is shared between encoder and decoder
- String handling strategies are guaranteed to match
- Round-trip encoding/decoding is reliable

### Container Implementation

*(Placeholder: describe keyed, unkeyed, and single-value container implementations)*

### String Handling

*(Placeholder: describe null-byte handling strategies and their implementation)*

## See Also

- <doc:CodableXPCRelationship>
