# XPCCoding Migration Guide

This guide records intentional source and behavior corrections made before the
package's first supported release. XPCCoding's same-host XPC object
representation is not a persistent archive format or an independently
versioned-peer protocol.

## 0.1.0: immutable codecs can be shared across tasks

`XPCCodec` now conforms to `Sendable` through its compiler-checked immutable
configuration. One explicitly configured codec can be captured by Swift
concurrency tasks and used for parallel encoding and decoding. Every direct
operation snapshots the configuration and creates fresh operation-local
implementation state, so sharing adds no locks or other synchronization.

The mutable `XPCEncoder` and `XPCDecoder` facade classes remain non-`Sendable`.
Keep each instance within one task, or create a fresh facade for another task.
Sharing an `XPCCodec` does not make the `xpc_object_t` produced by an operation
Swift `Sendable`; keep that object within the producing task during concurrent
round trips.

## 0.1.0: `XPCCodec` owns configuration, not coders

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
