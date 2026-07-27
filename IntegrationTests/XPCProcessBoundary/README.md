# Same-Host XPC Process-Boundary Fixture

This macOS-only fixture proves that XPCCoding's documented XPC object trees
survive libxpc serialization, a real local process boundary, and an
application-owned request/reply protocol.

It deliberately models XPCCoding's supported deployment boundary: the client
and service depend on the same local package checkout, are built by one
SwiftPM invocation, and are assembled and deployed together. It is not a
cross-version, persistent, network, or language-neutral interoperability test.

## Run

From the repository root, with the
[supported Xcode toolchain](../../reference/SupportPolicy.md) selected:

```sh
bash Scripts/run-xpc-integration.sh
```

The script:

1. builds the client and service together in release mode with warnings as
   errors;
2. assembles a temporary macOS application bundle with the service under
   `Contents/XPCServices`;
3. validates both committed property lists;
4. ad-hoc signs the nested service and then the application;
5. verifies both signatures;
6. executes three fresh client/service runs; and
7. removes the temporary bundle.

Every request has a five-second deadline, and every client connection is
cancelled deterministically. A timeout reports the operation that failed.

## Topology and assumptions

The application-private service uses the bundle identifier
`com.plx.hdxl-xpc-coding.integration.service` and the low-level
`xpc_connection_create`/`xpc_main` APIs. The fixture requires no entitlements:
neither the temporary application nor its service is sandboxed or privileged.
It tests the application XPC service namespace on the same macOS host; it does
not attempt a Mach service, system daemon, endpoint transfer, or remote
machine.

These assumptions follow Apple's documented application-service layout and
request/reply model:

- [Creating XPC Services](https://developer.apple.com/documentation/xpc/creating-xpc-services)
- [XPC Services API](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html)
- [`xpc_connection_send_message`](https://developer.apple.com/documentation/xpc/xpc_connection_send_message%28_%3A_%3A%29?language=objc)

## What crosses the boundary

The outer request and reply objects are dictionaries owned entirely by this
fixture's application protocol. Beneath its keys, public `XPCEncoder` and
`XPCDecoder` APIs carry scalar, array, keyed, nested, repaired-string, checked
numeric, 128-bit integer, and one-mebibyte native-`Data` roots. XPCCoding adds
no message envelope, reserved key, format version, or negotiation metadata.

The service verifies the physical XPC kinds it receives before decoding. It
then decodes and transforms the values, encodes the response roots, and sends
them in an application reply dictionary. The client verifies:

- the service's declared PID and libxpc-observed PID agree and differ from the
  client PID;
- all peer-observed XPC kinds match
  [`reference/WireFormat.md`](../../reference/WireFormat.md);
- transformed values and the large-data checksum match;
- missing operations and wrong root shapes receive bounded application-error
  replies; and
- terminating the service without replying produces
  `XPC_ERROR_CONNECTION_INTERRUPTED` without killing or hanging the client.
