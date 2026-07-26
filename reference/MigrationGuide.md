# XPCCoding Migration Guide

This guide records intentional source and behavior corrections made before the
package's first supported release. XPCCoding's same-host XPC object
representation is not a persistent archive format or an independently
versioned-peer protocol.

## Unreleased: `XPCCodec` owns configuration, not coders

`XPCCodec` previously exposed stored `encoder` and `decoder` reference
properties. Those references were mutable and were shared by copies of the
codec. Reconfiguring either reference could make `codec.encode` and
`codec.decode` incompatible while the codec continued to report its original
configuration.

The stored properties have been removed. `XPCCodec.Configuration` is now the
codec's only persistent state, and direct operations always derive their
behavior from it:

```swift
let codec = XPCCodec(
  configuration: .init(
    stringKeyStrategy: .percentEscape,
    stringValueStrategy: .percentEscape
  )
)

let object = try codec.encode(value)
let decoded = try codec.decode(Value.self, from: object)
```

When a caller needs a mutable facade, replace access to the old properties with
a factory call:

```swift
// Before:
let encoder = codec.encoder
let decoder = codec.decoder

// After:
let encoder = codec.makeEncoder()
let decoder = codec.makeDecoder()
```

Each factory call returns a new instance initialized from the codec's
configuration. Mutating it affects only that instance and cannot change the
codec, a copy of the codec, or a later factory result. An independently
reconfigured encoder or decoder is no longer guaranteed to be compatible with
the codec or with another factory result.

`makeDecoder()` starts with `XPCDecoder.ResourceLimits.standard`. Configure the
returned decoder or construct an `XPCDecoder` directly when an operation needs
different local resource limits. Direct `codec.decode` always uses the
standard limits.
