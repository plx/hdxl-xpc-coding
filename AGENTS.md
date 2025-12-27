# Guide For Agents

This repo contains a Swift package named `hdxl-xpc-coding`, which vends a library named `XPCCoding`. 
The library provides an `Encoder`/`Decoder` that encodes/decodes Swift `Codable` types to-and-from `xpc_object_t` values (which may then be sent between processes, etc., via Apple's XPC system). 
Analogously to `JSONEncoder` and `JSONDecoder`, the public-facing types `XPCEncoder` and `XPCDecoder` conform to `TopLevelEncoder` and `TopLevelDecoder` (respectively), but do *not* conform to `Encoder` or `Decoder` (respectively).
Instead, `XPCEncoder` and `XPCDecoder` are *facades*, delegating the actual encoding/decoding work to internal types that *do* conform to `Encoder` and `Decoder` (`_XPCEncoder` and `_XPCDecoder`, respectively).

At the highest-level, the package provides an `XPCCodec` type that simplifies obtaining mutually-compatible `XPCEncoder` and `XPCDecoder` instances.

## Project Status

On the one hand, the core functionality has been implemented and appears to work as-intended, too: it passes all tests ported over from the original `CodableXPC` library, as well as all the tests that've been added since then.

On the other hand, the project doesn't quite feel like a coherent, unified whole: there's traces of several different styles, and places where the physical organization for helpers, etc., feels inconsistent vis-a-vis other similar places.

On the gripping hand, it's still missing all the niceties that would be required for publication:

- documentation (API-level and guides, etc.)
- an updated readme
- basic/standard CI jobs for github actions
- swiftlint / swift-format configuration
- swift package index configuration

## Deeper Information

For deeper information, you can consult documents in the `reference/` directory. In particular, you may find the following of interest:

- [Project History](reference/ProjectHistory.md): read this in cases where the style or organization of the codebase feels unclear or jarring
- [Embedded Null-Byte Handling](reference/EmbeddedNullByteHandling.md): read this when working on code that deals with string keys and/or string values
