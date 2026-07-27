import Darwin
import Foundation
@preconcurrency import XPC
import XPCCoding

// MARK: - Failure

enum ProbeFailure: Error, CustomStringConvertible {
  case assertion(String)
  case expectedRejection(String)
  case unexpectedError(String)
  case invalidDescriptor(String)

  var description: String {
    switch self {
    case .assertion(let message):
      "assertion failed: \(message)"
    case .expectedRejection(let context):
      "expected a typed rejection: \(context)"
    case .unexpectedError(let message):
      "unexpected error: \(message)"
    case .invalidDescriptor(let message):
      "invalid descriptor: \(message)"
    }
  }
}

// MARK: - Observations

/// Collects facts a probe learned that are worth recording even when it passes.
///
/// Alignment coverage in particular cannot be asserted: libxpc may legitimately
/// realign an offset source. Recording the observed remainder keeps that a
/// visible measurement rather than a silent gap.
final class ObservationLog {
  private(set) var entries: [String] = []

  func record(_ entry: String) {
    entries.append(entry)
  }
}

// MARK: - Dispatch

func runProbe(
  _ descriptor: ProbeDescriptor,
  observations: ObservationLog
) throws {
  switch descriptor.probe {
  case .model(let probe):
    try runModelProbe(probe)
  case .distinctStrings(let probe):
    try runDistinctStringsProbe(probe)
  case .keyCollision(let probe):
    try runKeyCollisionProbe(probe)
  case .graph(let probe):
    try runGraphProbe(probe)
  case .cycle(let probe):
    try runCycleProbe(probe)
  case .binary128(let probe):
    try runBinary128Probe(probe, observations: observations)
  case .resourceBoundary(let probe):
    try runResourceBoundaryProbe(probe)
  case .rawText(let probe):
    try runRawTextProbe(probe)
  case .pointerCount(let probe):
    try runPointerCountProbe(probe)
  case .representation(let probe):
    try runRepresentationProbe(probe)
  case .deliberateHang:
    // The only deliberately non-terminating case: it exists so the harness can
    // prove that its own wall-clock control kills a hung child and reports the
    // seed. It must never be reachable from the ordinary corpus run.
    observations.record("entering the deliberate hang")
    while true {
      usleep(50_000)
    }
  }
}

// MARK: - Model

private func runModelProbe(_ probe: ModelProbe) throws {
  let encoder = probe.strategy.makeEncoder()
  let decoder = probe.strategy.makeDecoder()
  let object = try encoder.encode(probe.value)

  try requireXPCType(object, XPC_TYPE_DICTIONARY, context: "model root")
  try requireDictionaryType(
    object,
    key: "string",
    type: probe.strategy.expectedStringXPCType
  )
  try requireDictionaryType(object, key: "dictionary", type: XPC_TYPE_DICTIONARY)
  try requireDictionaryType(object, key: "signed", type: XPC_TYPE_INT64)
  try requireDictionaryType(object, key: "unsigned", type: XPC_TYPE_UINT64)
  try requireDictionaryType(object, key: "floatingPoint", type: XPC_TYPE_DOUBLE)
  try requireDictionaryType(object, key: "data", type: XPC_TYPE_DATA)
  try requireDictionaryType(object, key: "numbers", type: XPC_TYPE_ARRAY)
  // A synthesized optional property omits its key for `.none` rather than
  // storing an explicit XPC null.
  switch probe.value.child {
  case .none:
    try requireDictionaryKeyAbsent(object, key: "child")
  case .some:
    try requireDictionaryType(object, key: "child", type: XPC_TYPE_DICTIONARY)
  }

  let decoded = try decoder.decode(FuzzModel.self, from: object)
  guard decoded == probe.value else {
    throw ProbeFailure.assertion("model did not round-trip exactly")
  }
}

// MARK: - Distinct Strings

private func runDistinctStringsProbe(
  _ probe: DistinctStringsProbe
) throws {
  // Two views of "distinct" are needed, and conflating them would weaken the
  // test. Swift `String` equality is canonical equivalence, so `"e\u{301}"` and
  // `"é"` are one dictionary key but two scalar sequences that must each survive
  // exactly.
  let keyDistinct = canonicallyOrdered(Set(probe.strings))
  let scalarDistinct = orderedUniqueByScalars(probe.strings)
  guard !keyDistinct.isEmpty else {
    throw ProbeFailure.invalidDescriptor("a string probe needs at least one string")
  }

  let encoder = probe.strategy.makeEncoder()
  let decoder = probe.strategy.makeDecoder()
  let source = Dictionary(
    uniqueKeysWithValues: keyDistinct.enumerated().map { ($0.element, $0.offset) }
  )
  let object = try encoder.encode(source)

  try requireXPCType(object, XPC_TYPE_DICTIONARY, context: "string-key map")
  guard xpc_dictionary_get_count(object) == source.count else {
    throw ProbeFailure.assertion(
      """
      distinct keys aliased under \(probe.strategy.rawValue): \
      expected \(source.count) entries, observed \(xpc_dictionary_get_count(object))
      """
    )
  }
  guard try decoder.decode([String: Int].self, from: object) == source else {
    throw ProbeFailure.assertion(
      "string-key map did not round-trip under \(probe.strategy.rawValue)"
    )
  }

  var representations: [[UInt8]: String] = [:]
  for string in scalarDistinct {
    let encoded = try encoder.encode(string)
    try requireXPCType(
      encoded,
      probe.strategy.expectedStringXPCType,
      context: "string value under \(probe.strategy.rawValue)"
    )
    try requireScalarExactRoundTrip(
      try decoder.decode(String.self, from: encoded),
      string,
      context: "string value under \(probe.strategy.rawValue)"
    )

    let representation = try stringRepresentationBytes(of: encoded)
    if let previous = representations[representation],
      Array(previous.unicodeScalars) != Array(string.unicodeScalars)
    {
      throw ProbeFailure.assertion(
        """
        distinct strings aliased under \(probe.strategy.rawValue): \
        \(String(reflecting: previous)) and \(String(reflecting: string))
        """
      )
    }
    representations[representation] = string
  }
}

/// Requires scalar-for-scalar equality, not merely Swift `String` equality.
///
/// `==` on `String` is canonical equivalence, so it would silently accept a
/// coder that normalized a decomposed sequence into a composed one.
private func requireScalarExactRoundTrip(
  _ actual: String,
  _ expected: String,
  context: String
) throws {
  guard Array(actual.unicodeScalars) == Array(expected.unicodeScalars) else {
    throw ProbeFailure.assertion(
      """
      \(context) did not round-trip scalar-for-scalar: \
      expected \(scalarListDescription(expected)), \
      observed \(scalarListDescription(actual))
      """
    )
  }
}

// MARK: - Key Collisions

private func runKeyCollisionProbe(
  _ probe: KeyCollisionProbe
) throws {
  let keys = canonicallyOrdered(Set(probe.keys))
  guard !keys.isEmpty else {
    throw ProbeFailure.invalidDescriptor("a key probe needs at least one key")
  }
  let source = Dictionary(
    uniqueKeysWithValues: keys.enumerated().map { ($0.element, $0.offset) }
  )
  let object = try XPCEncoder(
    stringKeyStrategy: probe.strategy.encodingStrategy,
    stringValueStrategy: .percentEscape
  ).encode(source)
  try requireXPCType(object, XPC_TYPE_DICTIONARY, context: "key-collision map")

  let decoder = XPCDecoder(
    stringKeyStrategy: probe.strategy.decodingStrategy,
    stringValueStrategy: .percentEscape
  )

  switch probe.strategy {
  case .percentEscape:
    // Total over Swift `String`: every distinct key must survive as a distinct
    // entry and the whole dictionary must round-trip exactly.
    guard xpc_dictionary_get_count(object) == source.count else {
      throw ProbeFailure.assertion(
        """
        percent-escaped keys collided: expected \(source.count) entries, \
        observed \(xpc_dictionary_get_count(object))
        """
      )
    }
    guard try decoder.decode([String: Int].self, from: object) == source else {
      throw ProbeFailure.assertion("percent-escaped keys did not round-trip")
    }
    // `allKeys` is checked separately, scalar-exactly, because dictionary
    // equality above compares keys by canonical equivalence.
    let decodedScalarKeys = Set(
      try decoder.decode(AllKeysProbe.self, from: object).keys.map {
        $0.unicodeScalars.map(\.value)
      }
    )
    let expectedScalarKeys = Set(keys.map { $0.unicodeScalars.map(\.value) })
    guard decodedScalarKeys == expectedScalarKeys else {
      throw ProbeFailure.assertion(
        """
        percent-escaped keys were not preserved scalar-for-scalar: \
        expected \(expectedScalarKeys.count) distinct scalar sequences, \
        observed \(decodedScalarKeys.count)
        """
      )
    }

  case .assumeAbsent:
    // Deliberately unchecked: each key becomes the C string libxpc reads, which
    // is its UTF-8 bytes up to the first null byte. The oracle is computed from
    // the input rather than from library behavior, so this asserts the exact
    // documented lossiness instead of tolerating it.
    //
    // Identity here is *byte* identity, not Swift `String` equality. Swift
    // compares strings by canonical equivalence, so `"e\u{301}"` and `"é"` are
    // one Swift key but two distinct XPC dictionary keys.
    let expectedKeyBytes = Set(keys.map(cStringBytes))
    guard xpc_dictionary_get_count(object) == expectedKeyBytes.count else {
      throw ProbeFailure.assertion(
        """
        .assumeAbsent key truncation did not match its documented behavior: \
        expected \(expectedKeyBytes.count) entries, observed \
        \(xpc_dictionary_get_count(object))
        """
      )
    }
    let decodedKeyBytes = Set(
      try decoder.decode(AllKeysProbe.self, from: object).keys.map {
        Array($0.utf8)
      }
    )
    guard decodedKeyBytes == expectedKeyBytes else {
      throw ProbeFailure.assertion(
        """
        .assumeAbsent keys were not the documented truncations: \
        expected \(byteSetDescription(expectedKeyBytes)), \
        observed \(byteSetDescription(decodedKeyBytes))
        """
      )
    }
  }
}

// MARK: - Arbitrary Graphs

private func runGraphProbe(_ probe: GraphProbe) throws {
  let root = try makeGraph(probe)
  let limits = XPCDecoder.ResourceLimits(
    maximumNestingDepth: 24,
    maximumContainerElementCount: 32,
    maximumTotalNodeCount: 256,
    maximumStringByteCount: 128,
    maximumDataByteCount: 128,
    maximumCumulativeByteCount: 512
  )
  let decoder = XPCDecoder(resourceLimits: limits)
  try requireExpectation(.tolerant, context: "arbitrary XPC graph") {
    _ = try decoder.decode(AnyXPCValue.self, from: root)
  }
}

// MARK: - Cycles

private func runCycleProbe(_ probe: CycleProbe) throws {
  let root = makeCycleGraph(probe.shape)
  // A generous node budget with a small depth budget makes nesting depth the
  // only bound that can stop a cycle, so the assertion below is specific.
  let decoder = XPCDecoder(
    resourceLimits: XPCDecoder.ResourceLimits(
      maximumNestingDepth: 16,
      maximumContainerElementCount: 64,
      maximumTotalNodeCount: 4_096,
      maximumStringByteCount: 1_024,
      maximumDataByteCount: 1_024,
      maximumCumulativeByteCount: 4_096
    )
  )

  let operation: () throws -> Void
  switch probe.shape {
  case .emptySelfArray, .valueBearingSelfArray, .mutualArrays:
    operation = { _ = try decoder.decode(RecursiveArray.self, from: root) }
  case .selfDictionary, .mutualDictionaries:
    operation = { _ = try decoder.decode(RecursiveDictionary.self, from: root) }
  case .sharedAcyclicArray:
    operation = { _ = try decoder.decode(SharedArrayPair.self, from: root) }
  case .sharedAcyclicDictionary:
    operation = { _ = try decoder.decode(SharedDictionaryPair.self, from: root) }
  }

  guard probe.expectation == .reject else {
    try requireExpectation(
      probe.expectation,
      context: "\(probe.shape.rawValue) graph",
      operation
    )
    return
  }
  try requireResourceRejection(
    limitName: "maximumNestingDepth",
    context: "\(probe.shape.rawValue) graph",
    operation
  )
}

// MARK: - 128-Bit Integers

private func runBinary128Probe(
  _ probe: Binary128Probe,
  observations: ObservationLog
) throws {
  let object = makeXPCData(probe.bytes, unaligned: probe.unaligned)
  if probe.unaligned {
    let remainder = xpcDataAlignmentRemainder(object)
    observations.record(
      """
      requested-unaligned 128-bit input of \(probe.bytes.count) bytes had \
      16-byte address remainder \(remainder.map(String.init) ?? "unavailable")
      """
    )
  }

  let decoder = XPCDecoder.standard
  let encoder = XPCEncoder.standard
  let context = """
    \(probe.type.rawValue) 128-bit \(probe.bytes.count)-byte \
    \(probe.unaligned ? "offset" : "aligned") input
    """
  let decodeAndReencode: () throws -> Void = {
    let reencoded: xpc_object_t
    switch probe.type {
    case .signed:
      reencoded = try encoder.encode(
        try decoder.decode(Int128.self, from: object)
      )
    case .unsigned:
      reencoded = try encoder.encode(
        try decoder.decode(UInt128.self, from: object)
      )
    }
    try requireXPCType(reencoded, XPC_TYPE_DATA, context: "128-bit re-encoding")
    guard dataBytes(reencoded) == probe.bytes else {
      throw ProbeFailure.assertion(
        "128-bit value did not preserve its target-native bytes"
      )
    }
  }

  guard probe.expectation != .reject else {
    // A wrong byte count is well-formed XPC data of the right *kind*, so the
    // documented rejection is `dataCorrupted`. Accepting any `DecodingError`
    // here would keep passing if that became a `typeMismatch`.
    try requireRejection(.dataCorrupted, context: context, decodeAndReencode)
    return
  }
  try requireExpectation(probe.expectation, context: context, decodeAndReencode)
}

// MARK: - Resource Budgets

private func runResourceBoundaryProbe(
  _ probe: ResourceBoundaryProbe
) throws {
  guard probe.limit >= 0, probe.observed >= 0 else {
    throw ProbeFailure.invalidDescriptor("resource counts must be nonnegative")
  }
  let decoder = XPCDecoder(resourceLimits: probe.resourceLimits)
  let context = """
    \(probe.resource.rawValue) limit \(probe.effectiveLimit), \
    observed \(probe.observed)
    """

  let operation: () throws -> Void = {
    switch probe.resource {
    case .depth:
      _ = try decoder.decode(
        RecursiveArray.self,
        from: nestedXPCArray(edgeCount: probe.observed)
      )
    case .breadth:
      _ = try decoder.decode(
        [Int].self,
        from: xpcArray((0..<probe.observed).map { xpc_int64_create(Int64($0)) })
      )
    case .totalNodes:
      // The root array itself consumes one visit, so `observed` elements below
      // it would be one node too many.
      _ = try decoder.decode(
        [Int].self,
        from: xpcArray(
          (0..<max(0, probe.observed - 1)).map { xpc_int64_create(Int64($0)) }
        )
      )
    case .stringBytes:
      _ = try decoder.decode(
        String.self,
        from: xpcString(bytes: Array(repeating: 0x61, count: probe.observed))
      )
    case .dataBytes:
      _ = try decoder.decode(
        Data.self,
        from: makeXPCData(
          Data(repeating: 0xa5, count: probe.observed),
          unaligned: false
        )
      )
    case .cumulativeBytes:
      // Two individually-permitted strings that together exceed the total.
      let firstCount = probe.observed / 2
      _ = try decoder.decode(
        [String].self,
        from: xpcArray([
          xpcString(bytes: Array(repeating: 0x61, count: firstCount)),
          xpcString(
            bytes: Array(repeating: 0x62, count: probe.observed - firstCount)
          ),
        ])
      )
    }
  }

  guard probe.expectation == .reject else {
    try requireExpectation(probe.expectation, context: context, operation)
    return
  }
  try requireResourceRejection(
    limitName: probe.resource.limitName,
    context: context,
    operation
  )
}

// MARK: - Raw External Text

private func runRawTextProbe(_ probe: RawTextProbe) throws {
  guard !probe.bytes.contains(0) else {
    throw ProbeFailure.invalidDescriptor(
      "raw XPC text bytes cannot contain a null byte"
    )
  }
  let decoder = XPCDecoder(
    stringKeyStrategy: probe.strategy.decodingKeyStrategy,
    stringValueStrategy: probe.strategy.decodingValueStrategy
  )
  let context = """
    raw \(probe.location.rawValue) under \(probe.strategy.rawValue): \
    \(byteListDescription(probe.bytes))
    """

  var decodedText: String?
  let operation: () throws -> Void = {
    switch probe.location {
    case .stringValue:
      decodedText = try decoder.decode(
        String.self,
        from: xpcString(bytes: probe.bytes)
      )
    case .dictionaryKey:
      let keys = try decoder.decode(
        AllKeysProbe.self,
        from: xpcDictionary([(probe.bytes, xpc_int64_create(1))])
      ).keys
      guard keys.count == 1 else {
        throw ProbeFailure.assertion(
          "one XPC dictionary key decoded to \(keys.count) coding keys"
        )
      }
      decodedText = keys[0]
    }
  }

  guard probe.expectation != .reject else {
    // Malformed UTF-8 and a malformed escape sequence are both well-formed XPC
    // strings whose *content* is invalid, so both are `dataCorrupted`. This is
    // the taxonomy the audit's UTF-8 finding restored; a bare `DecodingError`
    // check would not notice it regressing.
    try requireRejection(.dataCorrupted, context: context, operation)
    return
  }
  try requireExpectation(probe.expectation, context: context, operation)

  guard probe.expectation == .pass, let expectedString = probe.expectedString
  else {
    return
  }
  guard let decodedText else {
    throw ProbeFailure.assertion("a passing raw-text probe produced no text")
  }
  try requireScalarExactRoundTrip(
    decodedText,
    expectedString,
    context: "raw \(probe.location.rawValue) under \(probe.strategy.rawValue)"
  )
}

// MARK: - Unsafe Pointer/Count

private func runPointerCountProbe(
  _ probe: PointerCountProbe
) throws {
  guard probe.isEvaluable else {
    throw ProbeFailure.invalidDescriptor(
      """
      a positive count of \(probe.count) exceeds the probe's \
      \(pointerProbeBytes.count)-byte initialized extent
      """
    )
  }

  let payload = RawPointerPayload(
    shape: probe.shape,
    suppliesPointer: probe.suppliesPointer,
    mutable: probe.mutable,
    count: probe.count
  )
  let context = """
    \(probe.shape.rawValue) \(probe.mutable ? "mutable" : "immutable") \
    pointer=\(probe.suppliesPointer), count=\(probe.count)
    """

  guard probe.expectation != .reject else {
    // An invalid pointer/count pair is an encoder-side contract violation, so
    // the exact public case is part of the contract, not an implementation
    // detail.
    try requireRejection(.invalidValue, context: context) {
      _ = try XPCEncoder.standard.encode(payload)
    }
    return
  }

  try requireExpectation(probe.expectation, context: context) {
    let object = try XPCEncoder.standard.encode(payload)
    let emitted = try probe.shape.emittedData(in: object)
    let expectedByteCount = max(0, probe.count)
    guard xpc_data_get_length(emitted) == expectedByteCount else {
      throw ProbeFailure.assertion(
        """
        pointer helper emitted \(xpc_data_get_length(emitted)) bytes, \
        expected \(expectedByteCount)
        """
      )
    }
    guard
      dataBytes(emitted) == Data(pointerProbeBytes.prefix(expectedByteCount))
    else {
      throw ProbeFailure.assertion("pointer helper emitted the wrong bytes")
    }
  }
}

private struct RawPointerPayload: Encodable {
  let shape: PointerContainerShape
  let suppliesPointer: Bool
  let mutable: Bool
  let count: Int

  func encode(to encoder: any Encoder) throws {
    switch mutable {
    case false:
      try pointerProbeBytes.withUnsafeBytes { buffer in
        try encode(
          suppliesPointer ? buffer.baseAddress : nil,
          to: encoder
        )
      }
    case true:
      var storage = pointerProbeBytes
      try storage.withUnsafeMutableBytes { buffer in
        try encode(
          suppliesPointer ? buffer.baseAddress : nil,
          to: encoder
        )
      }
    }
  }

  private func encode(
    _ pointer: UnsafeRawPointer?,
    to encoder: any Encoder
  ) throws {
    switch shape {
    case .singleValue:
      var container = encoder.singleValueContainer()
      try container.efficientlyEncodeBinaryData(pointer, count: count)
    case .keyed:
      var container = encoder.container(keyedBy: FuzzingCodingKey.self)
      try container.efficientlyEncodeBinaryData(
        pointer,
        count: count,
        forKey: FuzzingCodingKey(stringValue: pointerCountKeyName)
      )
    case .unkeyed:
      var container = encoder.unkeyedContainer()
      try container.efficientlyEncodeBinaryData(pointer, count: count)
    }
  }

  private func encode(
    _ pointer: UnsafeMutableRawPointer?,
    to encoder: any Encoder
  ) throws {
    switch shape {
    case .singleValue:
      var container = encoder.singleValueContainer()
      try container.efficientlyEncodeBinaryData(pointer, count: count)
    case .keyed:
      var container = encoder.container(keyedBy: FuzzingCodingKey.self)
      try container.efficientlyEncodeBinaryData(
        pointer,
        count: count,
        forKey: FuzzingCodingKey(stringValue: pointerCountKeyName)
      )
    case .unkeyed:
      var container = encoder.unkeyedContainer()
      try container.efficientlyEncodeBinaryData(pointer, count: count)
    }
  }
}

private let pointerCountKeyName = "value"

extension PointerContainerShape {

  fileprivate func emittedData(
    in object: xpc_object_t
  ) throws -> xpc_object_t {
    switch self {
    case .singleValue:
      try requireXPCType(object, XPC_TYPE_DATA, context: "single-value pointer root")
      return object
    case .keyed:
      try requireXPCType(object, XPC_TYPE_DICTIONARY, context: "keyed pointer root")
      guard
        let value = pointerCountKeyName.withCString({
          xpc_dictionary_get_value(object, $0)
        })
      else {
        throw ProbeFailure.assertion("keyed pointer helper omitted its key")
      }
      try requireXPCType(value, XPC_TYPE_DATA, context: "keyed pointer value")
      return value
    case .unkeyed:
      try requireXPCType(object, XPC_TYPE_ARRAY, context: "unkeyed pointer root")
      guard xpc_array_get_count(object) == 1 else {
        throw ProbeFailure.assertion(
          "unkeyed pointer helper emitted \(xpc_array_get_count(object)) elements"
        )
      }
      let value = xpc_array_get_value(object, 0)
      try requireXPCType(value, XPC_TYPE_DATA, context: "unkeyed pointer element")
      return value
    }
  }

}

// MARK: - Primitive Representation

private func runRepresentationProbe(
  _ probe: RepresentationProbe
) throws {
  let encoder = XPCEncoder.standard
  let decoder = XPCDecoder.standard

  switch probe.kind {
  case .data:
    let object = try encoder.encode(probe.bytes)
    try requireXPCType(object, XPC_TYPE_DATA, context: "Data")
    guard try decoder.decode(Data.self, from: object) == probe.bytes else {
      throw ProbeFailure.assertion("Data did not round-trip")
    }

  case .signedNarrow:
    let value = Int16(truncatingIfNeeded: probe.signed)
    let object = try encoder.encode(value)
    try requireXPCType(object, XPC_TYPE_INT64, context: "Int16")
    guard xpc_int64_get_value(object) == Int64(value) else {
      throw ProbeFailure.assertion("Int16 did not widen exactly")
    }
    guard try decoder.decode(Int16.self, from: object) == value else {
      throw ProbeFailure.assertion("Int16 did not round-trip")
    }

  case .unsignedNarrow:
    let value = UInt16(truncatingIfNeeded: probe.unsigned)
    let object = try encoder.encode(value)
    try requireXPCType(object, XPC_TYPE_UINT64, context: "UInt16")
    guard xpc_uint64_get_value(object) == UInt64(value) else {
      throw ProbeFailure.assertion("UInt16 did not widen exactly")
    }
    guard try decoder.decode(UInt16.self, from: object) == value else {
      throw ProbeFailure.assertion("UInt16 did not round-trip")
    }

  case .float16:
    let value = Float16(bitPattern: UInt16(truncatingIfNeeded: probe.floatBits))
    let object = try encoder.encode(value)
    try requireXPCType(object, XPC_TYPE_DOUBLE, context: "Float16")
    try requireFloatingPointRoundTrip(
      try decoder.decode(Float16.self, from: object),
      value,
      context: "Float16"
    )

  case .float32:
    let value = Float(bitPattern: probe.floatBits)
    let object = try encoder.encode(value)
    try requireXPCType(object, XPC_TYPE_DOUBLE, context: "Float")
    try requireFloatingPointRoundTrip(
      try decoder.decode(Float.self, from: object),
      value,
      context: "Float"
    )

  case .doubleValue:
    let value = Double(bitPattern: probe.doubleBits)
    let object = try encoder.encode(value)
    try requireXPCType(object, XPC_TYPE_DOUBLE, context: "Double")
    try requireFloatingPointRoundTrip(
      try decoder.decode(Double.self, from: object),
      value,
      context: "Double"
    )
  }
}

/// Compares by bit pattern, except that NaNs compare by classification.
private func requireFloatingPointRoundTrip<Value: BinaryFloatingPoint>(
  _ actual: Value,
  _ expected: Value,
  context: String
) throws {
  if expected.isNaN {
    guard actual.isNaN else {
      throw ProbeFailure.assertion("\(context) NaN did not round-trip as a NaN")
    }
    return
  }
  guard actual == expected, actual.sign == expected.sign else {
    throw ProbeFailure.assertion(
      "\(context) did not round-trip exactly: \(actual) vs \(expected)"
    )
  }
}

// MARK: - Expectation Enforcement

private func requireExpectation(
  _ expectation: Expectation,
  context: String,
  _ operation: () throws -> Void
) throws {
  switch expectation {
  case .pass:
    try operation()
  case .reject:
    do {
      try operation()
    } catch is DecodingError {
      return
    } catch is EncodingError {
      return
    }
    throw ProbeFailure.expectedRejection(context)
  case .tolerant:
    do {
      try operation()
    } catch is DecodingError {
      return
    } catch is EncodingError {
      return
    }
  }
}

/// The exact public error case a `reject` expectation requires.
private enum RejectionKind: String {
  case dataCorrupted = "DecodingError.dataCorrupted"
  case invalidValue = "EncodingError.invalidValue"

  func matches(_ error: any Error) -> Bool {
    switch self {
    case .dataCorrupted:
      guard let error = error as? DecodingError, case .dataCorrupted = error
      else {
        return false
      }
      return true
    case .invalidValue:
      guard let error = error as? EncodingError, case .invalidValue = error
      else {
        return false
      }
      return true
    }
  }
}

/// Requires that `operation` throw exactly `kind`.
///
/// Accepting any `DecodingError` would let a rejection stand in for an
/// unrelated one — a `typeMismatch` where the contract promises
/// `dataCorrupted` — so the case would keep passing after the taxonomy
/// regressed. The audit's error-taxonomy findings are exactly that shape.
private func requireRejection(
  _ kind: RejectionKind,
  context: String,
  _ operation: () throws -> Void
) throws {
  do {
    try operation()
  } catch let failure as ProbeFailure {
    throw failure
  } catch {
    guard kind.matches(error) else {
      throw ProbeFailure.assertion(
        """
        \(context) was rejected as \(publicErrorDescription(error)), \
        expected \(kind.rawValue)
        """
      )
    }
    return
  }
  throw ProbeFailure.expectedRejection("\(kind.rawValue) for \(context)")
}

private func publicErrorDescription(_ error: any Error) -> String {
  switch error {
  case let error as DecodingError:
    switch error {
    case .dataCorrupted: "DecodingError.dataCorrupted"
    case .keyNotFound: "DecodingError.keyNotFound"
    case .typeMismatch: "DecodingError.typeMismatch"
    case .valueNotFound: "DecodingError.valueNotFound"
    @unknown default: "an unknown DecodingError case"
    }
  case let error as EncodingError:
    switch error {
    case .invalidValue: "EncodingError.invalidValue"
    @unknown default: "an unknown EncodingError case"
    }
  default:
    "\(type(of: error)) (\(error))"
  }
}

/// Requires a `dataCorrupted` rejection that names the exhausted budget.
private func requireResourceRejection(
  limitName: String,
  context: String,
  _ operation: () throws -> Void
) throws {
  do {
    try operation()
  } catch let error as DecodingError {
    guard case .dataCorrupted(let errorContext) = error else {
      throw ProbeFailure.assertion(
        """
        expected dataCorrupted for \(limitName) (\(context)), observed \
        \(String(reflecting: error))
        """
      )
    }
    guard errorContext.debugDescription.contains(limitName) else {
      throw ProbeFailure.assertion(
        """
        \(context) was rejected without naming \(limitName): \
        \(errorContext.debugDescription)
        """
      )
    }
    return
  }
  throw ProbeFailure.expectedRejection("\(limitName) (\(context))")
}

func requireXPCType(
  _ object: xpc_object_t,
  _ expected: xpc_type_t,
  context: String
) throws {
  guard xpc_get_type(object) == expected else {
    throw ProbeFailure.assertion(
      """
      \(context) had XPC type \(xpcTypeName(object)), expected \
      \(String(cString: xpc_type_get_name(expected)))
      """
    )
  }
}

private func requireDictionaryType(
  _ dictionary: xpc_object_t,
  key: String,
  type: xpc_type_t
) throws {
  let value = key.withCString {
    xpc_dictionary_get_value(dictionary, $0)
  }
  guard let value else {
    throw ProbeFailure.assertion("model dictionary omitted \(key)")
  }
  try requireXPCType(value, type, context: "model.\(key)")
}

private func requireDictionaryKeyAbsent(
  _ dictionary: xpc_object_t,
  key: String
) throws {
  let value = key.withCString {
    xpc_dictionary_get_value(dictionary, $0)
  }
  guard value == nil else {
    throw ProbeFailure.assertion(
      """
      model dictionary stored \(key) as \(xpcTypeName(value ?? dictionary)) \
      instead of omitting it
      """
    )
  }
}

private func xpcTypeName(_ object: xpc_object_t) -> String {
  String(cString: xpc_type_get_name(xpc_get_type(object)))
}

// MARK: - Byte Inspection

private func stringRepresentationBytes(
  of object: xpc_object_t
) throws -> [UInt8] {
  switch xpc_get_type(object) {
  case XPC_TYPE_STRING:
    guard let pointer = xpc_string_get_string_ptr(object) else {
      throw ProbeFailure.assertion("XPC string exposed no C-string storage")
    }
    let length = xpc_string_get_length(object)
    return (0..<length).map { UInt8(bitPattern: pointer[$0]) }
  case XPC_TYPE_DATA:
    return Array(dataBytes(object))
  default:
    throw ProbeFailure.assertion(
      "an encoded string was neither XPC string nor XPC data"
    )
  }
}

private func byteListDescription(_ bytes: [UInt8]) -> String {
  "[\(bytes.map { String(format: "%02x", $0) }.joined(separator: " "))]"
}

/// Orders strings by their UTF-8 bytes so diagnostics and generated case
/// contents never depend on `Set` iteration order.
private func canonicallyOrdered(_ strings: Set<String>) -> [String] {
  strings.sorted {
    Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8))
  }
}

/// Keeps every distinct *scalar sequence*, in first-appearance order.
///
/// A `Set<String>` would merge canonically equivalent forms, which is exactly the
/// distinction the representation must preserve.
private func orderedUniqueByScalars(_ strings: [String]) -> [String] {
  var seen: Set<[UInt32]> = []
  var result: [String] = []
  for string in strings.sorted(by: {
    Array($0.unicodeScalars.map(\.value))
      .lexicographicallyPrecedes(Array($1.unicodeScalars.map(\.value)))
  }) where seen.insert(string.unicodeScalars.map(\.value)).inserted {
    result.append(string)
  }
  return result
}

private func scalarListDescription(_ string: String) -> String {
  "[\(string.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " "))]"
}

/// The bytes libxpc reads from a Swift string's C-string representation.
///
/// This is the exact `.assumeAbsent` truncation: UTF-8 bytes up to the first
/// null byte.
private func cStringBytes(_ string: String) -> [UInt8] {
  Array(string.utf8.prefix { $0 != 0 })
}

private func byteSetDescription(_ byteSets: Set<[UInt8]>) -> String {
  let sorted = byteSets.sorted { $0.lexicographicallyPrecedes($1) }
  return "{\(sorted.map(byteListDescription).joined(separator: ", "))}"
}

// MARK: - Strategy Mapping

extension StringStrategy {

  fileprivate func makeEncoder() -> XPCEncoder {
    XPCEncoder(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: encodingValueStrategy
    )
  }

  fileprivate func makeDecoder() -> XPCDecoder {
    XPCDecoder(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: decodingValueStrategy
    )
  }

  fileprivate var encodingValueStrategy: XPCEncoder.StringValueStrategy {
    switch self {
    case .percentEscape: .percentEscape
    case .dataUTF8: .useDataRepresentation(.utf8)
    case .dataUTF16: .useDataRepresentation(.utf16)
    case .dataUTF32: .useDataRepresentation(.utf32)
    }
  }

  fileprivate var decodingValueStrategy: XPCDecoder.StringValueStrategy {
    switch self {
    case .percentEscape: .percentEscape
    case .dataUTF8: .useDataRepresentation(.utf8)
    case .dataUTF16: .useDataRepresentation(.utf16)
    case .dataUTF32: .useDataRepresentation(.utf32)
    }
  }

  fileprivate var expectedStringXPCType: xpc_type_t {
    switch self {
    case .percentEscape: XPC_TYPE_STRING
    case .dataUTF8, .dataUTF16, .dataUTF32: XPC_TYPE_DATA
    }
  }

}

extension KeyStrategy {

  fileprivate var encodingStrategy: XPCEncoder.StringKeyStrategy {
    switch self {
    case .percentEscape: .percentEscape
    case .assumeAbsent: .assumeAbsent
    }
  }

  fileprivate var decodingStrategy: XPCDecoder.StringKeyStrategy {
    switch self {
    case .percentEscape: .percentEscape
    case .assumeAbsent: .passthrough
    }
  }

}

extension RawTextStrategy {

  fileprivate var decodingKeyStrategy: XPCDecoder.StringKeyStrategy {
    switch self {
    case .percentEscape: .percentEscape
    case .passthrough: .passthrough
    }
  }

  fileprivate var decodingValueStrategy: XPCDecoder.StringValueStrategy {
    switch self {
    case .percentEscape: .percentEscape
    case .passthrough: .passthrough
    }
  }

}

extension ResourceKind {

  /// The public limit property whose name a rejection must mention.
  var limitName: String {
    switch self {
    case .depth: "maximumNestingDepth"
    case .breadth: "maximumContainerElementCount"
    case .totalNodes: "maximumTotalNodeCount"
    case .stringBytes: "maximumStringByteCount"
    case .dataBytes: "maximumDataByteCount"
    case .cumulativeBytes: "maximumCumulativeByteCount"
    }
  }

}

extension ResourceBoundaryProbe {

  /// Limits in which the probe's own resource is the only one that can bind.
  ///
  /// Every non-target ceiling is derived from `observed` so that a mutated case
  /// still fails for the reason its descriptor names.
  var resourceLimits: XPCDecoder.ResourceLimits {
    let headroom = max(observed + 2, 8)
    return XPCDecoder.ResourceLimits(
      maximumNestingDepth: resource == .depth ? limit : headroom,
      maximumContainerElementCount: resource == .breadth ? limit : headroom,
      maximumTotalNodeCount: resource == .totalNodes ? max(1, limit) : headroom,
      maximumStringByteCount: resource == .stringBytes ? limit : headroom,
      maximumDataByteCount: resource == .dataBytes ? limit : headroom,
      maximumCumulativeByteCount: resource == .cumulativeBytes
        ? limit
        : max(2 * observed + 4, 16)
    )
  }

}
