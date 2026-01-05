# Guide For Agents

This repo contains a Swift package named `hdxl-xpc-coding`, which vends a library named `XPCCoding`.

The *purpose* of the package is to provide a mechanism for serializing and deserializing Swift `Codable` types to-and-from `xpc_object_t` values (which may then be sent between processes, etc., via Apple's XPC system). 

## General Structure

The provided public API is modeled after that of `JSONEncoder` and `JSONDecoder`: the outward-facing types (`XPCEncoder` and `XPCDecoder`) are facadess supporting:

- *configuration* of encoding/decoding parameters 
- *encoding/decoding* of "root values" to-and-from the archive format (here: `xpc_object_t`)

They also conform to `TopLevelEncoder` and `TopLevelDecoder` (respectively), which provides a standardized API for encoding/decoding those "top level" root values.

As with `JSONEncoder` and `JSONDecoder`, the actual `Encoder` and `Decoder` conformance is provided by internal types (here: `_XPCEncoder` and `_XPCDecoder`, respectively). These types are *not* part of the public API, but *are* what wind up getting used for encoding and decoding, respectively, by those outward-facing facades. Coupled with these are the associated encoding and decoding container types, which are also not part of the public API (once again as with `JSONEncoder` and `JSONDecoder`).

Additionally—and unlike `JSONEncoder` and `JSONDecoder`—the public API contains a "Codec" concept (`XPCCodec`), which provides a convenient way to obtain mutually-compatible `XPCEncoder` and `XPCDecoder` instances:

- you create an `XPCCodec` instance configured-by an `XPCCodec.Configuration`
- the `XPCCodec` instance creates-and-owns a suitably-configured, mutually-compatible pair of `XPCEncoder` and `XPCDecoder` instances
- the `XPCCodec` instance also conforms to both `TopLevelEncoder` and `TopLevelDecoder` (and thus can be used directly for encoding/decoding, as a convenience)

Finally, the library provides some extensions on the encoding containers allowing direct encoding of unsafe pointers to binary data. 
These are provided as an optional efficiency improvement:

- the underlying XPC APIs expect to receive binary data via "length and pointer" arguments
- "out of the box", the encoding container protocols would require *wrapping* that "length and pointer" into a `Data` object
- our underyling containers *do* support encoding binary data directly from a "length and pointer" 
- our public-facing extensions do a protocol check on the container to see if it supports our "enhanced" API

Note that in all cases the binary data itself winds up copied into the `xpc_object_t`. The efficiency win here—such as it is—arises simply from obviating the need for a transient `Data` wrapper to deliver them to the underlying container.

## Current Status

At this point the project is considered "feature complete" and thoroughly-tested via unit tests; remaining *known* work revolves around documentation, publishing, and so on.

For deeper information, you can consult documents in the `reference/` directory. In particular, you may find the following of interest:

- [Project History](reference/ProjectHistory.md): read this in cases where the style or organization of the codebase feels unclear or jarring
- [Embedded Null-Byte Handling](reference/EmbeddedNullByteHandling.md): read this when working on code that deals with string keys and/or string values
