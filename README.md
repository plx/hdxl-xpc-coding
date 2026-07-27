# hdxl-xpc-coding

`hdxl-xpc-coding` is a Swift package that vends the `XPCCoding` library
product and module. It provides `XPCEncoder`, `XPCDecoder`, and `XPCCodec` for
encoding Swift `Codable` values to `xpc_object_t` trees and decoding those
trees back into Swift values.

XPCCoding is deliberately narrow: it glues together applications and XPC
services that are designed, built, released, and deployed as one system on one
Apple host. Think of its representation as having the conceptual equivalent
of `package` visibility, not as a separately versioned interchange format.

## Compatibility boundary

A supported process cohort:

- uses the same XPCCoding source revision and supported Swift toolchain;
- is built together for compatible target ABIs;
- uses matching `Codable` models and XPCCoding string configuration; and
- is deployed and updated together on the same machine.

XPCCoding does not support independently versioned or independently updated
peers, decoding data from another XPCCoding release, network transport,
communication with another machine, persistence or archival, later replay,
language-neutral or architecture-neutral bytes, or direct use of libxpc's
opaque serialized representation.

The [XPC object representation contract](reference/WireFormat.md) precisely
defines the object trees used within a same-build cohort. It deliberately
defines no format version, runtime negotiation, compatibility decoder,
library-owned message envelope, or reserved transport keys. When that
representation changes, every participating process must be rebuilt and
redeployed together.

## Requirements

The sole supported build environment is:

- Xcode 26.6 (build 17F113) with Apple Swift 6.3.3;
- Swift tools version 6.3 and Swift 6 language mode;
- arm64; and
- macOS 26+, iOS 26+, or Mac Catalyst 26+.

Earlier toolchains, older deployment targets, x86_64, and other platforms are
unsupported. Later compiler versions are unverified until the policy changes
deliberately. See the [support policy](reference/SupportPolicy.md) for the
complete contract and verification command.

## Installation

Add the package's canonical HTTPS `.git` URL and the `XPCCoding` product to
your Swift package:

```swift
// swift-tools-version:6.3

import PackageDescription

let package = Package(
  name: "Example",
  platforms: [
    .macOS(.v26),
    .iOS(.v26),
    .macCatalyst(.v26),
  ],
  dependencies: [
    .package(
      url: "https://github.com/plx/hdxl-xpc-coding.git",
      branch: "main"
    )
  ],
  targets: [
    .executableTarget(
      name: "Example",
      dependencies: [
        .product(
          name: "XPCCoding",
          package: "hdxl-xpc-coding"
        )
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
```

The moving `main` branch is suitable only for evaluating the package before a
supported release is available. For released software, select a semantic
version from [GitHub Releases](https://github.com/plx/hdxl-xpc-coding/releases)
instead. If that page has no release, the project has no supported released
version.

## Quick start

`XPCCodec.standard` is the simplest way to keep an encoder and decoder on the
same configuration:

```swift
import XPCCoding

struct Greeting: Codable, Equatable {
  let text: String
}

func verifyGreetingRoundTrip() throws {
  let greeting = Greeting(text: "hello from another process")
  let codec = XPCCodec.standard

  let root = try codec.encode(greeting)
  let decoded = try codec.decode(Greeting.self, from: root)

  precondition(decoded == greeting)
}
```

The root can be any shape requested by `Codable`; it does not have to be a
dictionary. `XPCEncoder` and `XPCDecoder` are top-level facades analogous to
`JSONEncoder` and `JSONDecoder`. They do not themselves conform to Swift's
`Encoder` and `Decoder` protocols.

## Put the root in an application message

XPC connection send APIs such as
[`xpc_connection_send_message`](https://developer.apple.com/documentation/xpc/xpc_connection_send_message%28_%3A_%3A%29?language=objc)
require the object sent as a message to be an XPC dictionary. XPCCoding does
not add that dictionary because the application, not the library, owns its
message protocol.

The application can place an encoded root under an application-owned key and
recover it on the other side:

```swift
@preconcurrency import XPC
import XPCCoding

enum ApplicationMessageError: Error {
  case missingPayload
}

struct WorkRequest: Codable, Equatable {
  let identifier: Int
  let input: String
}

let applicationPayloadKey = "payload"

func makeMessage(
  for request: WorkRequest,
  using codec: XPCCodec = .standard
) throws -> xpc_object_t {
  let message = xpc_dictionary_create_empty()
  let root = try codec.encode(request)
  applicationPayloadKey.withCString {
    xpc_dictionary_set_value(message, $0, root)
  }
  return message
}

func decodeRequest(
  from message: xpc_object_t,
  using codec: XPCCodec = .standard
) throws -> WorkRequest {
  guard
    let root = applicationPayloadKey.withCString({
      xpc_dictionary_get_value(message, $0)
    })
  else {
    throw ApplicationMessageError.missingPayload
  }
  return try codec.decode(WorkRequest.self, from: root)
}

func send(
  _ request: WorkRequest,
  over connection: xpc_connection_t,
  using codec: XPCCodec = .standard
) throws {
  xpc_connection_send_message(
    connection,
    try makeMessage(for: request, using: codec)
  )
}
```

The outer dictionary, `"payload"` key, operation names, reply shape,
application versioning, and error protocol are all application concerns.
XPCCoding neither inserts nor expects envelope or format-version metadata.

## Strings and configuration

XPC strings and dictionary keys are null-terminated C strings, while Swift
strings can contain embedded null scalars. The standard codec uses the
reversible `.percentEscape` strategy for both keys and values, preserving
embedded nulls and literal percent signs.

String strategies are an out-of-band cohort agreement; no strategy identifier
is serialized. Every encoder and decoder in the process cohort must use
compatible configuration. Constructing both sides from the same
`XPCCodec.Configuration` makes that relationship explicit.

Alternative value strategies can reject embedded nulls or represent strings
as data. The unchecked `.assumeAbsent` strategy can truncate a string at an
embedded null and can make distinct keys collide; use it only when the
application can uphold that precondition. See the
[representation contract](reference/WireFormat.md#strings) for every supported
strategy pair and exact behavior.

## Decoder resource limits and untrusted input

Every top-level decode uses finite `XPCDecoder.ResourceLimits`. The standard
limits bound nesting depth, entries in one container, total visited nodes,
individual string and data sizes, and cumulative decoded bytes. They are
decoder-local policy: they are not serialized and do not need to match the
encoder.

The defaults are ceilings, not a substitute for application validation. Treat
objects from a peer that could be compromised as untrusted, use stricter
limits when the application protocol permits them, and validate decoded values
against the application's semantic rules. The exact standard limits and
counting rules are documented on `XPCDecoder.ResourceLimits` and in the
[representation contract](reference/WireFormat.md#decoder-safety-and-errors).

## Unsafe buffer helpers

The optional enhanced encoding helpers accept raw byte or typed-element
pointers so callers can avoid constructing a transient `Data` or array.

For every pointer/count overload:

- the count must be nonnegative;
- a positive count requires a non-nil pointer;
- zero permits either a nil or non-nil pointer; and
- for a positive count, the caller must keep at least that many initialized,
  readable bytes or elements alive for the duration of the call.

XPCCoding rejects a negative count or a nil pointer with a positive count, but
it cannot dynamically verify the pointer's extent, initialization, or
lifetime. Raw binary helpers produce one XPC data object and copy the bytes
before returning. Typed-element helpers encode each element through ordinary
`Encodable` rules and produce an XPC array.

## Concurrency and ownership

`XPCCodec` is an immutable, compiler-checked `Sendable` configuration value.
It can be shared across tasks; each direct encode or decode operation creates
fresh operation-local coding state. `makeEncoder()` and `makeDecoder()` each
return a new, separately configurable facade.

`XPCEncoder` and `XPCDecoder` are mutable, deliberately non-`Sendable`
reference types. Keep each instance confined to one task. Sharing a codec does
not make `xpc_object_t` Swift `Sendable`; keep each XPC object within the
concurrency domain that owns it.

## Stability and release status

XPCCoding follows semantic versioning, but while it is pre-1.0 it makes no
source-stability guarantee. Intentional source breaks remain reviewed,
documented with migrations, and checked against a pinned API baseline. The
[source API stability policy](reference/ApiStabilityPolicy.md) is separate
from the same-build XPC representation policy.

Only the newest published GitHub Release is supported. Commits and forks are
not supported releases. Consult [GitHub Releases](https://github.com/plx/hdxl-xpc-coding/releases)
and the [changelog](CHANGELOG.md) before adopting a version.

## Project resources

- [API documentation build instructions](reference/ApiDocumentation.md)
- [Migration guide](reference/MigrationGuide.md)
- [Benchmarks and reproducible reports](Benchmarks/README.md)
- [Sanitizer testing](reference/SanitizerTesting.md)
- [Release process](RELEASING.md)

Report suspected vulnerabilities through the private route in
[SECURITY.md](SECURITY.md), never in a public issue. For ordinary defects,
proposals, or contributions, use the repository's
[issues](https://github.com/plx/hdxl-xpc-coding/issues) and
[pull requests](https://github.com/plx/hdxl-xpc-coding/pulls). Representation
changes must update the normative contract and same-build fixtures in the same
change.

## Origin and license

This package derives in part from
[`daniel-grumberg/CodableXPC`](https://github.com/daniel-grumberg/CodableXPC)
at pinned upstream revision
[`df3250371e7ad4882ec51b76dfbbbe7b00209fee`](https://github.com/daniel-grumberg/CodableXPC/tree/df3250371e7ad4882ec51b76dfbbbe7b00209fee).
The derived files have been substantially modified.

The package is licensed under Apache License 2.0 with the Swift Runtime Library
Exception (`Apache-2.0 WITH Swift-exception`). See [LICENSE](LICENSE),
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), and the
[upstream provenance record](reference/UpstreamProvenance.md).
