import Dispatch
import Foundation
import Testing
import XPC
@testable import XPCCoding

// MARK: - Unaligned Numeric Decoding Tests

/// Verifies that 128-bit integer decoding never assumes XPC-owned storage is aligned.
///
/// XPC makes no promise that `xpc_data_get_bytes_ptr` satisfies the decoded type's alignment: a
/// perfectly valid data object backed by a `DispatchData` slice beginning one byte into a larger
/// buffer reports a misaligned base address. These tests build exactly that storage, decode it
/// through the public facade, and pin down the exact-size validation that must happen before any
/// read of that storage.
@Suite("Unaligned Numeric Decoding", .tags(.decoding, .edgeCases))
struct UnalignedNumericDecodingTests {

  // MARK: Unaligned Storage

  /// Isolates the alignment trap in a subprocess, so a regression fails instead of aborting the test runner.
  @Test(.enabled(if: subprocessIsolationIsSupported, subprocessIsolationRequirement))
  func `unaligned decoding of both 128-bit integer types survives in a subprocess`() async {
    await #expect(processExitsWith: .success) {
      try decodeEveryProbeFromUnalignedStorage()
    }
  }

  @Test(arguments: binaryDataNumericProbes)
  func `unaligned storage decodes on the root, keyed, and unkeyed paths`(
    probe: any BinaryDataNumericProbe
  ) throws {
    try probe.verifyUnalignedDecoding()
  }

  // MARK: Aligned Storage

  @Test(arguments: binaryDataNumericProbes)
  func `aligned exact-size storage still decodes on every path`(
    probe: any BinaryDataNumericProbe
  ) throws {
    try probe.verifyAlignedDecoding()
  }

  // MARK: Length Validation

  @Test(arguments: binaryDataNumericProbes)
  func `too-short and too-long payloads throw data-corrupted on every path`(
    probe: any BinaryDataNumericProbe
  ) throws {
    try probe.verifyIncorrectLengthsAreRejected()
  }

  /// Proves the exact-size check happens *before* the payload is read, in a subprocess: any read
  /// past the validated length would fault on the unreadable page that follows the payload.
  @Test(.enabled(if: subprocessIsolationIsSupported, subprocessIsolationRequirement))
  func `too-short payloads are rejected without reading the bytes that follow them`() async {
    await #expect(processExitsWith: .success) {
      try rejectEveryProbeShortPayloadAdjacentToUnreadableMemory()
    }
  }

  // MARK: Negative Control

  #if DEBUG
    /// Confirms the storage these tests build really does trap an alignment-requiring load.
    ///
    /// Without this control the regressions above could silently become vacuous — for instance if
    /// a future `DispatchData` or libxpc change started handing back aligned storage. The check is
    /// debug-only because the standard library's misaligned-load precondition is a
    /// `_debugPrecondition`, which is compiled out of release builds.
    @Test(.enabled(if: subprocessIsolationIsSupported, subprocessIsolationRequirement))
    func `an alignment-requiring load still traps on that same unaligned storage`() async {
      await #expect(processExitsWith: .failure) {
        try performAlignmentRequiringLoadOnUnalignedStorage()
      }
    }
  #endif

}

// MARK: - Subprocess Support

/// Explains the condition guarding the subprocess-isolated tests.
private let subprocessIsolationRequirement: Comment = """
  Subprocess-isolated tests need a test host that can re-launch itself with the sanitizer runtime \
  loaded early enough to install its interceptors.
  """

/// Whether subprocess-isolated (exit) tests can run in the current build.
///
/// `swift test --sanitize=address` and `swift test --sanitize=thread` re-launch the child through
/// the `dlopen`-ed test bundle, so the sanitizer runtime loads too late to install its
/// interceptors and the child aborts during start-up with `Interceptors are not working`. An empty
/// exit-test body reproduces that abort, so the limitation belongs to the test host rather than to
/// anything under test; the in-process regressions cover the same extraction logic under every
/// sanitizer.
private let subprocessIsolationIsSupported: Bool = {
  // These are the runtimes that install interceptors and abort when they cannot.
  let interceptingSanitizerSymbols = ["__asan_init", "__tsan_init"]
  // `RTLD_DEFAULT` is a macro, so it needs spelling out to search every loaded image.
  let allLoadedImages = UnsafeMutableRawPointer(bitPattern: -2)
  return interceptingSanitizerSymbols.allSatisfy { symbolName in
    symbolName.withCString { symbol in
      dlsym(allLoadedImages, symbol) == nil
    }
  }
}()

// MARK: - Subprocess Entry Points

/// Decodes both supported 128-bit types from deliberately-misaligned storage.
private func decodeEveryProbeFromUnalignedStorage() throws {
  for probe in binaryDataNumericProbes {
    try probe.verifyUnalignedDecoding()
  }
}

/// Rejects a one-byte-short payload for both supported 128-bit types.
private func rejectEveryProbeShortPayloadAdjacentToUnreadableMemory() throws {
  for probe in binaryDataNumericProbes {
    try probe.verifyShortPayloadIsRejectedWithoutReadingAdjacentBytes()
  }
}

/// Performs the alignment-requiring load this ticket removed, against the tests' own storage.
///
/// Returning normally means the load did *not* trap, which fails the calling expectation.
private func performAlignmentRequiringLoadOnUnalignedStorage() throws {
  let object = try misalignedXPCData(
    containing: [UInt8](Int128(0x1234).xpcBinaryDataRepresentation)
  )
  let baseAddress = try #require(
    xpc_data_get_bytes_ptr(object),
    "`xpc_data_get_bytes_ptr` must supply the payload of a non-empty xpc data object."
  )
  try #require(
    UInt(bitPattern: baseAddress) % UInt(MemoryLayout<Int128>.alignment) != 0,
    "The negative control needs genuinely misaligned storage to be meaningful."
  )

  // This mirrors the pre-fix implementation of
  // `init?(unsafeXPCBinaryDataRepresentationRawBufferPointer:)`.
  let loaded = baseAddress.load(as: Int128.self)
  print("An alignment-requiring load unexpectedly succeeded, producing \(loaded).")
}

// MARK: - Probes

/// One supported binary-data-backed 128-bit integer conformance.
protocol BinaryDataNumericProbe: Sendable, CustomTestStringConvertible {

  /// Verifies decoding from deliberately-misaligned storage on every container path.
  func verifyUnalignedDecoding() throws

  /// Verifies decoding from aligned, exact-size storage on every container path.
  func verifyAlignedDecoding() throws

  /// Verifies that too-short and too-long payloads are rejected as `dataCorrupted`.
  func verifyIncorrectLengthsAreRejected() throws

  /// Verifies that a too-short payload is rejected without reading the bytes that follow it.
  func verifyShortPayloadIsRejectedWithoutReadingAdjacentBytes() throws

}

/// Every supported binary-data-backed numeric conformance.
private let binaryDataNumericProbes: [any BinaryDataNumericProbe] = [
  NumericProbe(values: Int128.exampleValues),
  NumericProbe(values: UInt128.exampleValues),
]

/// The probe implementation for a single binary-data-backed numeric type.
private struct NumericProbe<Value>: BinaryDataNumericProbe
where
  Value: Codable,
  Value: Sendable,
  Value: ConcretelyDecodable,
  Value: XPCBinaryDataRepresentationConvertible
{

  /// The values to decode from each flavor of storage.
  let values: [Value]

  /// Equivalence used to compare decoded values (the floating-point probes include NaNs).
  let isEquivalent: @Sendable (Value, Value) -> Bool

  var testDescription: String {
    String(reflecting: Value.self)
  }

}

extension NumericProbe where Value: Equatable {

  init(values: [Value]) {
    self.init(values: values) { $0 == $1 }
  }

}

// MARK: - Probe Verification

extension NumericProbe {

  /// The exact byte count of this type's binary-data representation.
  private var byteCount: Int {
    MemoryLayout<Value>.size
  }

  /// The alignment this type's storage would need for an alignment-requiring load.
  private var byteAlignment: Int {
    MemoryLayout<Value>.alignment
  }

  func verifyUnalignedDecoding() throws {
    for value in values {
      for payload in try payloads(for: value) {
        let bytes = payload.bytes
        try verifyDecodings(
          yield: value,
          interpretation: payload.interpretation,
          storageDescription: "misaligned \(payload.description)",
          storage: { try misalignedXPCData(containing: bytes) },
          verifyingStorageWith: { object in
            try requireMisalignedPayload(
              in: object,
              alignment: byteAlignment,
              byteCount: bytes.count
            )
          }
        )
      }
    }
  }

  func verifyAlignedDecoding() throws {
    let encoder = XPCEncoder.standard
    for value in values {
      // The canonical encoder output is left exactly as libxpc built it, which is both the
      // ordinary round trip and the control proving this ticket did not disturb it.
      try verifyDecodings(
        yield: value,
        interpretation: .canonicallyEncoded,
        storageDescription: "canonically-encoded",
        storage: { try encoder.encode(value) },
        verifyingStorageWith: { object in
          try requireXPCData(object)
        }
      )

      let bytes = try binaryRepresentationBytes(of: value)
      try withAlignedXPCData(containing: bytes) { object in
        try verifyDecodings(
          yield: value,
          interpretation: .binaryRepresentation,
          storageDescription: "aligned binary representation",
          storage: { object },
          verifyingStorageWith: { candidate in
            try requireAlignedPayload(
              in: candidate,
              alignment: byteAlignment,
              byteCount: bytes.count
            )
          }
        )
      }
    }
  }

  func verifyIncorrectLengthsAreRejected() throws {
    let value = try #require(
      values.first,
      "Every probe needs at least one representative value."
    )
    let representation = try binaryRepresentationBytes(of: value)
    let incorrectPayloads: [(description: String, bytes: [UInt8])] = [
      (description: "one byte short", bytes: Array(representation.dropLast())),
      (description: "one byte long", bytes: representation + [unalignedPayloadSentinel]),
    ]

    for incorrectPayload in incorrectPayloads {
      let bytes = incorrectPayload.bytes
      try verifyRejections(
        context: "a \(incorrectPayload.description) misaligned payload",
        storage: { try misalignedXPCData(containing: bytes) },
        verifyingStorageWith: { object in
          try requireExactPayloadLength(of: object, byteCount: bytes.count)
        }
      )

      guard !bytes.isEmpty else {
        // An empty payload has no bytes to place in aligned storage; the misaligned case above
        // already covers the zero-length rejection that one-byte types get.
        continue
      }
      try withAlignedXPCData(containing: bytes) { object in
        try verifyRejections(
          context: "a \(incorrectPayload.description) aligned payload",
          storage: { object },
          verifyingStorageWith: { candidate in
            try requireExactPayloadLength(of: candidate, byteCount: bytes.count)
          }
        )
      }
    }
  }

  func verifyShortPayloadIsRejectedWithoutReadingAdjacentBytes() throws {
    let shortByteCount = byteCount - 1
    guard shortByteCount > 0 else {
      // A one-byte type's only short payload is empty, which has no adjacent bytes to guard.
      return
    }

    try withGuardedShortPayload(byteCount: shortByteCount) { object in
      try verifyRejections(
        context: "a one-byte-short payload followed by unreadable memory",
        storage: { object },
        verifyingStorageWith: { candidate in
          try requireExactPayloadLength(of: candidate, byteCount: shortByteCount)
        }
      )
    }
  }

  /// Returns each payload flavor that must decode back to `value`.
  private func payloads(for value: Value) throws -> [ProbePayload] {
    [
      ProbePayload(
        description: "canonical payload",
        interpretation: .canonicallyEncoded,
        bytes: try canonicalPayloadBytes(of: value)
      ),
      ProbePayload(
        description: "binary representation",
        interpretation: .binaryRepresentation,
        bytes: try binaryRepresentationBytes(of: value)
      ),
    ]
  }

  /// Returns the exact binary-data representation bytes for `value`.
  private func binaryRepresentationBytes(of value: Value) throws -> [UInt8] {
    let bytes = [UInt8](value.xpcBinaryDataRepresentation)
    try #require(
      bytes.count == byteCount,
      """
      \(testDescription) must have a \(byteCount)-byte binary representation, but had \
      \(bytes.count) bytes.
      """
    )
    return bytes
  }

  /// Requires every applicable container path to decode `value` from the supplied storage.
  private func verifyDecodings(
    yield value: Value,
    interpretation: PayloadInterpretation,
    storageDescription: String,
    storage: @escaping () throws -> xpc_object_t,
    verifyingStorageWith verifyStorage: @escaping (xpc_object_t) throws -> Void
  ) throws {
    let attempts = decodingAttempts(
      of: Value.self,
      interpretation: interpretation,
      storage: storage,
      verifyingStorageWith: verifyStorage
    )
    for attempt in attempts {
      let decoded = try attempt.decode()
      try #require(
        isEquivalent(decoded, value),
        """
        Decoding \(testDescription) from \(storageDescription) storage via the \(attempt.path) \
        path produced \(String(reflecting: decoded)) instead of \(String(reflecting: value)).
        """
      )
    }
  }

  /// Requires every container path to reject the supplied storage as `dataCorrupted`.
  private func verifyRejections(
    context: String,
    storage: @escaping () throws -> xpc_object_t,
    verifyingStorageWith verifyStorage: @escaping (xpc_object_t) throws -> Void
  ) throws {
    let attempts: [DecodingAttempt<Value>] = decodingAttempts(
      of: Value.self,
      interpretation: .canonicallyEncoded,
      storage: storage,
      verifyingStorageWith: verifyStorage
    )
    for attempt in attempts {
      try requireDataCorrupted(
        from: attempt,
        decoding: testDescription,
        context: context
      )
    }
  }

}

// MARK: - Payloads

/// One flavor of payload bytes a probe decodes.
private struct ProbePayload {

  /// A human-readable description of this payload flavor.
  let description: String

  /// How the payload relates to the value it represents.
  let interpretation: PayloadInterpretation

  /// The payload bytes themselves.
  let bytes: [UInt8]

}

/// How a payload relates to the value it represents, which determines the applicable paths.
private enum PayloadInterpretation: Sendable {

  /// The payload is exactly what the public encoder emits, so every decoding path applies.
  case canonicallyEncoded

  /// The payload is the type's own binary-data representation.
  ///
  /// The 128-bit integer's target-native binary representation.
  case binaryRepresentation

}

// MARK: - Container Paths

/// Where a data-backed payload sits within the top-level XPC message being decoded.
private enum PayloadPlacement: Sendable {

  /// The payload *is* the top-level message.
  case root

  /// The payload is the value of a single-entry XPC dictionary.
  case keyed

  /// The payload is the only element of a single-element XPC array.
  case unkeyed

  /// The dictionary key (and coding key) used by the keyed placement.
  static let key: String = "value"

  /// Wraps `payload` in the message shape this placement describes.
  func message(containing payload: xpc_object_t) -> xpc_object_t {
    switch self {
    case .root:
      payload
    case .keyed:
      createXPCDictionary(key: Self.key, value: payload)
    case .unkeyed:
      createXPCArray([payload])
    }
  }

  /// Returns the payload object as the decoder will find it within `message`.
  func payload(in message: xpc_object_t) throws -> xpc_object_t {
    switch self {
    case .root:
      message
    case .keyed:
      try #require(
        xpc_dictionary_get_value(message, Self.key),
        "The keyed placement must keep its payload reachable at `\(Self.key)`."
      )
    case .unkeyed:
      xpc_array_get_value(message, 0)
    }
  }

}

/// A single decoding attempt, labeled by the container path and dispatch flavor it exercises.
private struct DecodingAttempt<Value> {

  /// A human-readable description of the exercised path.
  let path: String

  /// Performs the decoding.
  let decode: () throws -> Value

}

/// Builds one decoding attempt per container path and dispatch flavor covered by this ticket.
///
/// Both dispatch flavors matter: generic `Codable` code reaches the `decode<T: Decodable>` funnel,
/// while a synthesized conformance reaches the containers' type-specific `decode` overloads.
private func decodingAttempts<Value>(
  of valueType: Value.Type,
  interpretation: PayloadInterpretation,
  storage: @escaping () throws -> xpc_object_t,
  verifyingStorageWith verifyStorage: @escaping (xpc_object_t) throws -> Void
) -> [DecodingAttempt<Value>] where Value: Codable, Value: ConcretelyDecodable {
  let decoder = XPCDecoder.standard

  func message(for placement: PayloadPlacement) throws -> xpc_object_t {
    let message = placement.message(containing: try storage())
    try verifyStorage(try placement.payload(in: message))
    return message
  }

  var attempts: [DecodingAttempt<Value>] = []
  switch interpretation {
  case .canonicallyEncoded:
    attempts.append(
      DecodingAttempt(path: "facade root") {
        try decoder.decode(Value.self, from: try message(for: .root))
      }
    )
  case .binaryRepresentation:
    break
  }

  attempts.append(
    contentsOf: [
      DecodingAttempt(path: "type-specific root") {
        try decoder.decode(AlignmentProbeRootValue<Value>.self, from: try message(for: .root)).value
      },
      DecodingAttempt(path: "generic keyed") {
        try decoder.decode(KeyedValueWrapper<Value>.self, from: try message(for: .keyed)).value
      },
      DecodingAttempt(path: "type-specific keyed") {
        try decoder.decode(AlignmentProbeKeyedValue<Value>.self, from: try message(for: .keyed)).value
      },
      DecodingAttempt(path: "generic unkeyed") {
        try decoder.decode(UnkeyedValueWrapper<Value>.self, from: try message(for: .unkeyed)).value
      },
      DecodingAttempt(path: "type-specific unkeyed") {
        try decoder.decode(
          AlignmentProbeUnkeyedValue<Value>.self,
          from: try message(for: .unkeyed)
        ).value
      },
    ]
  )

  return attempts
}

/// Requires `attempt` to fail with `DecodingError.dataCorrupted`.
private func requireDataCorrupted<Value>(
  from attempt: DecodingAttempt<Value>,
  decoding typeDescription: String,
  context: String,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let error = try #require(
    throws: DecodingError.self,
    """
    Decoding \(typeDescription) from \(context) via the \(attempt.path) path should have failed.
    """,
    sourceLocation: sourceLocation
  ) {
    try attempt.decode()
  }

  guard case .dataCorrupted = error else {
    throw AlignmentProbeFailure.unexpectedDecodingError(
      typeDescription: typeDescription,
      context: context,
      path: attempt.path,
      error: error
    )
  }
}

// MARK: - Type-Specific Container Overloads

/// The coding key used by the type-specific probe wrappers.
enum AlignmentProbeKey: String, CodingKey {
  case value
}

/// A type that can be decoded through its containers' type-specific `decode` overloads.
///
/// The conformances below call `decode` with a concrete type, which is what a synthesized
/// `Codable` conformance does; generic code instead reaches `decode<T: Decodable>`.
protocol ConcretelyDecodable: Decodable {

  /// Decodes an instance through the single-value container's type-specific overload.
  static func decoded(from container: any SingleValueDecodingContainer) throws -> Self

  /// Decodes an instance for `key` through the keyed container's type-specific overload.
  static func decoded(
    from container: KeyedDecodingContainer<AlignmentProbeKey>,
    forKey key: AlignmentProbeKey
  ) throws -> Self

  /// Decodes an instance through the unkeyed container's type-specific overload.
  static func decoded(from container: inout any UnkeyedDecodingContainer) throws -> Self

}

/// Decodes a root value through the single-value container's type-specific overload.
private struct AlignmentProbeRootValue<Value>: Decodable where Value: ConcretelyDecodable {

  let value: Value

  init(from decoder: any Decoder) throws {
    self.value = try Value.decoded(from: try decoder.singleValueContainer())
  }

}

/// Decodes a dictionary value through the keyed container's type-specific overload.
private struct AlignmentProbeKeyedValue<Value>: Decodable where Value: ConcretelyDecodable {

  let value: Value

  init(from decoder: any Decoder) throws {
    self.value = try Value.decoded(
      from: try decoder.container(keyedBy: AlignmentProbeKey.self),
      forKey: .value
    )
  }

}

/// Decodes an array element through the unkeyed container's type-specific overload.
private struct AlignmentProbeUnkeyedValue<Value>: Decodable where Value: ConcretelyDecodable {

  let value: Value

  init(from decoder: any Decoder) throws {
    var container: any UnkeyedDecodingContainer = try decoder.unkeyedContainer()
    self.value = try Value.decoded(from: &container)
  }

}

extension Int8: ConcretelyDecodable {

  static func decoded(from container: any SingleValueDecodingContainer) throws -> Self {
    try container.decode(Int8.self)
  }

  static func decoded(
    from container: KeyedDecodingContainer<AlignmentProbeKey>,
    forKey key: AlignmentProbeKey
  ) throws -> Self {
    try container.decode(Int8.self, forKey: key)
  }

  static func decoded(from container: inout any UnkeyedDecodingContainer) throws -> Self {
    try container.decode(Int8.self)
  }

}

extension Int16: ConcretelyDecodable {

  static func decoded(from container: any SingleValueDecodingContainer) throws -> Self {
    try container.decode(Int16.self)
  }

  static func decoded(
    from container: KeyedDecodingContainer<AlignmentProbeKey>,
    forKey key: AlignmentProbeKey
  ) throws -> Self {
    try container.decode(Int16.self, forKey: key)
  }

  static func decoded(from container: inout any UnkeyedDecodingContainer) throws -> Self {
    try container.decode(Int16.self)
  }

}

extension Int32: ConcretelyDecodable {

  static func decoded(from container: any SingleValueDecodingContainer) throws -> Self {
    try container.decode(Int32.self)
  }

  static func decoded(
    from container: KeyedDecodingContainer<AlignmentProbeKey>,
    forKey key: AlignmentProbeKey
  ) throws -> Self {
    try container.decode(Int32.self, forKey: key)
  }

  static func decoded(from container: inout any UnkeyedDecodingContainer) throws -> Self {
    try container.decode(Int32.self)
  }

}

extension Int128: ConcretelyDecodable {

  static func decoded(from container: any SingleValueDecodingContainer) throws -> Self {
    try container.decode(Int128.self)
  }

  static func decoded(
    from container: KeyedDecodingContainer<AlignmentProbeKey>,
    forKey key: AlignmentProbeKey
  ) throws -> Self {
    try container.decode(Int128.self, forKey: key)
  }

  static func decoded(from container: inout any UnkeyedDecodingContainer) throws -> Self {
    try container.decode(Int128.self)
  }

}

extension UInt8: ConcretelyDecodable {

  static func decoded(from container: any SingleValueDecodingContainer) throws -> Self {
    try container.decode(UInt8.self)
  }

  static func decoded(
    from container: KeyedDecodingContainer<AlignmentProbeKey>,
    forKey key: AlignmentProbeKey
  ) throws -> Self {
    try container.decode(UInt8.self, forKey: key)
  }

  static func decoded(from container: inout any UnkeyedDecodingContainer) throws -> Self {
    try container.decode(UInt8.self)
  }

}

extension UInt16: ConcretelyDecodable {

  static func decoded(from container: any SingleValueDecodingContainer) throws -> Self {
    try container.decode(UInt16.self)
  }

  static func decoded(
    from container: KeyedDecodingContainer<AlignmentProbeKey>,
    forKey key: AlignmentProbeKey
  ) throws -> Self {
    try container.decode(UInt16.self, forKey: key)
  }

  static func decoded(from container: inout any UnkeyedDecodingContainer) throws -> Self {
    try container.decode(UInt16.self)
  }

}

extension UInt32: ConcretelyDecodable {

  static func decoded(from container: any SingleValueDecodingContainer) throws -> Self {
    try container.decode(UInt32.self)
  }

  static func decoded(
    from container: KeyedDecodingContainer<AlignmentProbeKey>,
    forKey key: AlignmentProbeKey
  ) throws -> Self {
    try container.decode(UInt32.self, forKey: key)
  }

  static func decoded(from container: inout any UnkeyedDecodingContainer) throws -> Self {
    try container.decode(UInt32.self)
  }

}

extension UInt128: ConcretelyDecodable {

  static func decoded(from container: any SingleValueDecodingContainer) throws -> Self {
    try container.decode(UInt128.self)
  }

  static func decoded(
    from container: KeyedDecodingContainer<AlignmentProbeKey>,
    forKey key: AlignmentProbeKey
  ) throws -> Self {
    try container.decode(UInt128.self, forKey: key)
  }

  static func decoded(from container: inout any UnkeyedDecodingContainer) throws -> Self {
    try container.decode(UInt128.self)
  }

}

extension Float16: ConcretelyDecodable {

  static func decoded(from container: any SingleValueDecodingContainer) throws -> Self {
    try container.decode(Float16.self)
  }

  static func decoded(
    from container: KeyedDecodingContainer<AlignmentProbeKey>,
    forKey key: AlignmentProbeKey
  ) throws -> Self {
    try container.decode(Float16.self, forKey: key)
  }

  static func decoded(from container: inout any UnkeyedDecodingContainer) throws -> Self {
    try container.decode(Float16.self)
  }

}

extension Float: ConcretelyDecodable {

  static func decoded(from container: any SingleValueDecodingContainer) throws -> Self {
    try container.decode(Float.self)
  }

  static func decoded(
    from container: KeyedDecodingContainer<AlignmentProbeKey>,
    forKey key: AlignmentProbeKey
  ) throws -> Self {
    try container.decode(Float.self, forKey: key)
  }

  static func decoded(from container: inout any UnkeyedDecodingContainer) throws -> Self {
    try container.decode(Float.self)
  }

}

// MARK: - XPC Data Construction

/// The byte prefixed onto a payload to push that payload onto a misaligned address.
private let unalignedPayloadSentinel: UInt8 = 0xA5

/// Returns the payload bytes of the xpc data object the public encoder produces for `value`.
private func canonicalPayloadBytes<Value>(of value: Value) throws -> [UInt8] where Value: Encodable {
  let encoded = try XPCEncoder.standard.encode(value)
  try requireXPCData(encoded)

  let byteCount = xpc_data_get_length(encoded)
  try #require(
    byteCount > 0,
    "\(String(reflecting: Value.self)) must encode as a non-empty payload."
  )

  var bytes = [UInt8](repeating: 0, count: byteCount)
  let copiedByteCount = try bytes.withUnsafeMutableBytes { buffer in
    let baseAddress = try #require(
      buffer.baseAddress,
      "A non-empty buffer must have a base address."
    )
    return xpc_data_get_bytes(encoded, baseAddress, 0, byteCount)
  }
  try #require(
    copiedByteCount == byteCount,
    "`xpc_data_get_bytes` copied \(copiedByteCount) of \(byteCount) bytes."
  )

  return bytes
}

/// Returns an XPC data object whose payload bytes deliberately begin at a misaligned address.
///
/// The construction mirrors ordinary XPC traffic: a `DispatchData` slice that begins one byte into
/// a larger buffer is bridged to `dispatch_data_t` and handed to
/// `xpc_data_create_with_dispatch_data`, which then reports a base address offset by one byte from
/// dispatch's own (aligned) allocation.
private func misalignedXPCData(containing payload: [UInt8]) throws -> xpc_object_t {
  var prefixedBytes: [UInt8] = [unalignedPayloadSentinel]
  prefixedBytes.append(contentsOf: payload)

  let dispatchData = prefixedBytes.withUnsafeBytes { buffer in
    DispatchData(bytes: buffer)
  }
  let slice = dispatchData.subdata(in: 1..<prefixedBytes.count)
  let object = xpc_data_create_with_dispatch_data(slice as dispatch_data_t)

  try requireExactPayloadLength(of: object, byteCount: payload.count)
  if let firstPayloadByte = payload.first {
    let baseAddress = try #require(
      xpc_data_get_bytes_ptr(object),
      "A non-empty xpc data object must expose its payload."
    )
    try #require(
      baseAddress.loadUnaligned(as: UInt8.self) == firstPayloadByte,
      "The sentinel byte must not be part of the payload the decoder sees."
    )
  }

  return object
}

/// Invokes `body` with an XPC data object whose payload bytes begin at a 16-byte-aligned address.
private func withAlignedXPCData<Result>(
  containing payload: [UInt8],
  _ body: (xpc_object_t) throws -> Result
) throws -> Result {
  try withUnsafeTemporaryAllocation(
    byteCount: payload.count,
    // 16 bytes is the strictest alignment among the affected types (`Int128` and `UInt128`).
    alignment: 16
  ) { buffer in
    buffer.copyBytes(from: payload)
    let dispatchData = DispatchData(
      bytesNoCopy: UnsafeRawBufferPointer(buffer),
      deallocator: .custom(nil, {})
    )
    return try body(xpc_data_create_with_dispatch_data(dispatchData as dispatch_data_t))
  }
}

/// Invokes `body` with XPC data whose `byteCount` payload bytes end exactly at unreadable memory.
///
/// Reading even one byte past the payload faults, so surviving this proves that the exact-size
/// check runs before the payload is read.
private func withGuardedShortPayload<Result>(
  byteCount: Int,
  _ body: (xpc_object_t) throws -> Result
) throws -> Result {
  let pageSize = Int(getpagesize())
  try #require(
    byteCount > 0 && byteCount <= pageSize,
    "The guarded payload must fit within the readable page."
  )

  let mapping = mmap(nil, pageSize * 2, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0)
  try #require(
    mapping != MAP_FAILED,
    "`mmap` failed with errno \(errno)."
  )
  let readablePage = try #require(mapping, "A successful `mmap` returns a mapping.")
  defer {
    _ = munmap(readablePage, pageSize * 2)
  }
  try #require(
    mprotect(readablePage.advanced(by: pageSize), pageSize, PROT_NONE) == 0,
    "`mprotect` failed with errno \(errno)."
  )

  let payload = UnsafeMutableRawBufferPointer(
    start: readablePage.advanced(by: pageSize - byteCount),
    count: byteCount
  )
  for index in payload.indices {
    payload[index] = unalignedPayloadSentinel
  }

  let dispatchData = DispatchData(
    bytesNoCopy: UnsafeRawBufferPointer(payload),
    deallocator: .custom(nil, {})
  )
  let object = xpc_data_create_with_dispatch_data(dispatchData as dispatch_data_t)

  try requireExactPayloadLength(of: object, byteCount: byteCount)
  let baseAddress = try #require(
    xpc_data_get_bytes_ptr(object),
    "A non-empty xpc data object must expose its payload."
  )
  try #require(
    baseAddress == UnsafeRawPointer(payload.baseAddress),
    "libxpc must reference the guarded payload directly, or the guard page proves nothing."
  )

  return try body(object)
}

// MARK: - Storage Verification

/// Requires `object` to be an xpc data object.
private func requireXPCData(
  _ object: xpc_object_t,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try #require(
    xpc_get_type(object) == XPC_TYPE_DATA,
    "Expected xpc data, but found \(object.typeDescription).",
    sourceLocation: sourceLocation
  )
}

/// Requires `object` to be an xpc data object holding exactly `byteCount` bytes.
private func requireExactPayloadLength(
  of object: xpc_object_t,
  byteCount: Int,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try requireXPCData(object, sourceLocation: sourceLocation)
  try #require(
    xpc_data_get_length(object) == byteCount,
    "Expected a \(byteCount)-byte payload, but found \(xpc_data_get_length(object)) bytes.",
    sourceLocation: sourceLocation
  )
}

/// Requires the payload of `object` to be misaligned, when misalignment is even possible.
private func requireMisalignedPayload(
  in object: xpc_object_t,
  alignment: Int,
  byteCount: Int,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try requireExactPayloadLength(
    of: object,
    byteCount: byteCount,
    sourceLocation: sourceLocation
  )
  guard byteCount > 0, alignment > 1 else {
    // Empty payloads have no address to check, and one-byte types cannot be misaligned.
    return
  }

  let baseAddress = try #require(
    xpc_data_get_bytes_ptr(object),
    "A non-empty xpc data object must expose its payload.",
    sourceLocation: sourceLocation
  )
  try #require(
    UInt(bitPattern: baseAddress) % UInt(alignment) != 0,
    """
    This regression needs genuinely misaligned storage: expected an address that is not a multiple \
    of \(alignment), but found \(UInt(bitPattern: baseAddress)).
    """,
    sourceLocation: sourceLocation
  )
}

/// Requires the payload of `object` to satisfy `alignment`.
private func requireAlignedPayload(
  in object: xpc_object_t,
  alignment: Int,
  byteCount: Int,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try requireExactPayloadLength(
    of: object,
    byteCount: byteCount,
    sourceLocation: sourceLocation
  )
  guard byteCount > 0 else {
    return
  }

  let baseAddress = try #require(
    xpc_data_get_bytes_ptr(object),
    "A non-empty xpc data object must expose its payload.",
    sourceLocation: sourceLocation
  )
  try #require(
    UInt(bitPattern: baseAddress) % UInt(alignment) == 0,
    """
    This check needs aligned storage: expected an address that is a multiple of \(alignment), but \
    found \(UInt(bitPattern: baseAddress)).
    """,
    sourceLocation: sourceLocation
  )
}

// MARK: - Failures

/// Failures reported by the alignment probes.
private enum AlignmentProbeFailure: Error, CustomStringConvertible {

  /// Decoding failed, but not as `dataCorrupted`.
  case unexpectedDecodingError(
    typeDescription: String,
    context: String,
    path: String,
    error: DecodingError
  )

  var description: String {
    switch self {
    case .unexpectedDecodingError(let typeDescription, let context, let path, let error):
      """
      Decoding \(typeDescription) from \(context) via the \(path) path should have failed as \
      `dataCorrupted`, but failed as \(String(reflecting: error)).
      """
    }
  }

}
