import Foundation
import Testing
import XPC
@testable import XPCCoding

@Suite("Unsafe Pointer/Count Validation", .tags(.encoding, .edgeCases))
struct UnsafePointerCountValidationTests {

  @Test(.enabled(if: pointerCountSubprocessIsolationIsSupported))
  func `nil positive raw pointer fails safely instead of aborting XPC`() async {
    await #expect(processExitsWith: .success) {
      try BinaryPointerProbe(
        shape: .singleValue,
        mutability: .immutable,
        pair: .nilPositive
      ).verifyInvalidXPCEncoding()
    }
  }

  @Test(arguments: binaryPointerProbes)
  fileprivate func `raw pointer helpers enforce one contract on fast and fallback paths`(
    probe: BinaryPointerProbe
  ) throws {
    try probe.verifyPublicHelperContract()
  }

  @Test(arguments: elementPointerProbes)
  fileprivate func `typed element helpers enforce one contract on keyed and unkeyed paths`(
    probe: ElementPointerProbe
  ) throws {
    try probe.verifyPublicHelperContract()
  }

  @Test(arguments: directEnhancedPointerProbes)
  fileprivate func `library enhanced container witnesses validate direct calls`(
    probe: DirectEnhancedPointerProbe
  ) throws {
    try probe.verifyContract()
  }

  @Test(arguments: keyedShimInvalidProbes)
  fileprivate func `keyed pointer shims cannot bypass validation`(
    probe: KeyedShimInvalidProbe
  ) throws {
    try probe.verifyRejection()
  }

}

// MARK: - Probe Inventory

private let binaryPointerProbes: [BinaryPointerProbe] = PointerContainerShape.allCases.flatMap { shape in
  PointerMutability.allCases.flatMap { mutability in
    PointerCountPair.allCases.map { pair in
      BinaryPointerProbe(
        shape: shape,
        mutability: mutability,
        pair: pair
      )
    }
  }
}

private let elementPointerProbes: [ElementPointerProbe] = ElementContainerShape.allCases.flatMap { shape in
  PointerMutability.allCases.flatMap { mutability in
    PointerCountPair.allCases.map { pair in
      ElementPointerProbe(
        shape: shape,
        mutability: mutability,
        pair: pair
      )
    }
  }
}

private let directEnhancedPointerProbes: [DirectEnhancedPointerProbe] =
  DirectEnhancedContainerShape.allCases.flatMap { shape in
    PointerMutability.allCases.flatMap { mutability in
      PointerCountPair.allCases.map { pair in
        DirectEnhancedPointerProbe(
          shape: shape,
          mutability: mutability,
          pair: pair
        )
      }
    }
  }

private let keyedShimInvalidProbes: [KeyedShimInvalidProbe] =
  PointerMutability.allCases.flatMap { mutability in
    PointerCountPair.allCases.compactMap { pair in
      guard !pair.isValid else {
        return nil
      }
      return KeyedShimInvalidProbe(
        mutability: mutability,
        pair: pair
      )
    }
  }

// MARK: - Pointer/Count Contract

private enum PointerCountPair: CaseIterable, Sendable, CustomStringConvertible {
  case nilNegative
  case nonnilNegative
  case nilZero
  case nonnilZero
  case nilPositive
  case nonnilPositive

  var count: Int {
    switch self {
    case .nilNegative, .nonnilNegative:
      -1
    case .nilZero, .nonnilZero:
      0
    case .nilPositive, .nonnilPositive:
      1
    }
  }

  var suppliesPointer: Bool {
    switch self {
    case .nilNegative, .nilZero, .nilPositive:
      false
    case .nonnilNegative, .nonnilZero, .nonnilPositive:
      true
    }
  }

  var isValid: Bool {
    switch self {
    case .nilNegative, .nonnilNegative, .nilPositive:
      false
    case .nilZero, .nonnilZero, .nonnilPositive:
      true
    }
  }

  var representsEmptyInput: Bool {
    switch self {
    case .nilZero, .nonnilZero:
      true
    case .nilNegative, .nonnilNegative, .nilPositive, .nonnilPositive:
      false
    }
  }

  var expectedDebugDescription: String {
    switch self {
    case .nilNegative, .nonnilNegative:
      "Invalid unsafe pointer/count pair: count must be nonnegative, but was -1."
    case .nilPositive:
      "Invalid unsafe pointer/count pair: a non-nil pointer is required when count is positive (count: 1)."
    case .nilZero, .nonnilZero, .nonnilPositive:
      preconditionFailure("Valid pairs do not have an error description.")
    }
  }

  var description: String {
    switch self {
    case .nilNegative:
      "nil/-1"
    case .nonnilNegative:
      "nonnil/-1"
    case .nilZero:
      "nil/0"
    case .nonnilZero:
      "nonnil/0"
    case .nilPositive:
      "nil/1"
    case .nonnilPositive:
      "nonnil/1"
    }
  }
}

private enum PointerMutability: CaseIterable, Sendable, CustomStringConvertible {
  case immutable
  case mutable

  var description: String {
    switch self {
    case .immutable:
      "immutable"
    case .mutable:
      "mutable"
    }
  }
}

// MARK: - Public Raw Binary Helpers

private enum PointerContainerShape: CaseIterable, Sendable, CustomStringConvertible {
  case singleValue
  case keyed
  case unkeyed

  var expectedCodingPath: [String] {
    switch self {
    case .singleValue, .unkeyed:
      []
    case .keyed:
      [PointerCountCodingKey.value.stringValue]
    }
  }

  var description: String {
    switch self {
    case .singleValue:
      "single-value"
    case .keyed:
      "keyed"
    case .unkeyed:
      "unkeyed"
    }
  }
}

private struct BinaryPointerProbe: Sendable, CustomTestStringConvertible {
  let shape: PointerContainerShape
  let mutability: PointerMutability
  let pair: PointerCountPair

  var testDescription: String {
    "\(shape)/\(mutability)/\(pair)"
  }

  func verifyPublicHelperContract() throws {
    switch pair.isValid {
    case false:
      try verifyInvalidXPCEncoding()
      try requireInvalidPointerCountError(
        expectedPair: pair,
        expectedCodingPath: shape.expectedCodingPath
      ) {
        _ = try JSONEncoder().encode(payload)
      }
    case true:
      let expected = pair.representsEmptyInput ? Data() : Data([binaryProbeBytes[0]])
      #expect(try decodedXPCValue() == expected)
      #expect(try decodedJSONValue() == expected)
    }
  }

  func verifyInvalidXPCEncoding() throws {
    try requireInvalidPointerCountError(
      expectedPair: pair,
      expectedCodingPath: shape.expectedCodingPath
    ) {
      _ = try XPCEncoder.standard.encode(payload)
    }
  }

  private var payload: BinaryPointerPayload {
    BinaryPointerPayload(
      shape: shape,
      mutability: mutability,
      pair: pair
    )
  }

  private func decodedXPCValue() throws -> Data {
    let encoded = try XPCEncoder.standard.encode(payload)
    switch shape {
    case .singleValue:
      return try pointerCountData(from: encoded)
    case .keyed:
      return try XPCDecoder.standard.decode(PointerCountDataValue.self, from: encoded).value
    case .unkeyed:
      return try #require(
        XPCDecoder.standard.decode([Data].self, from: encoded).first
      )
    }
  }

  private func decodedJSONValue() throws -> Data {
    let encoded = try JSONEncoder().encode(payload)
    switch shape {
    case .singleValue:
      return try JSONDecoder().decode(Data.self, from: encoded)
    case .keyed:
      return try JSONDecoder().decode(PointerCountDataValue.self, from: encoded).value
    case .unkeyed:
      return try #require(
        JSONDecoder().decode([Data].self, from: encoded).first
      )
    }
  }
}

private struct BinaryPointerPayload: Encodable, Sendable {
  let shape: PointerContainerShape
  let mutability: PointerMutability
  let pair: PointerCountPair

  func encode(to encoder: any Encoder) throws {
    switch mutability {
    case .immutable:
      try binaryProbeBytes.withUnsafeBytes { buffer in
        try encode(
          pair.suppliesPointer ? buffer.baseAddress : nil,
          count: pair.count,
          to: encoder
        )
      }
    case .mutable:
      var bytes = binaryProbeBytes
      try bytes.withUnsafeMutableBytes { buffer in
        try encode(
          pair.suppliesPointer ? buffer.baseAddress : nil,
          count: pair.count,
          to: encoder
        )
      }
    }
  }

  private func encode(
    _ pointer: UnsafeRawPointer?,
    count: Int,
    to encoder: any Encoder
  ) throws {
    switch shape {
    case .singleValue:
      var container = encoder.singleValueContainer()
      try container.efficientlyEncodeBinaryData(pointer, count: count)
    case .keyed:
      var container = encoder.container(keyedBy: PointerCountCodingKey.self)
      try container.efficientlyEncodeBinaryData(pointer, count: count, forKey: .value)
    case .unkeyed:
      var container = encoder.unkeyedContainer()
      try container.efficientlyEncodeBinaryData(pointer, count: count)
    }
  }

  private func encode(
    _ pointer: UnsafeMutableRawPointer?,
    count: Int,
    to encoder: any Encoder
  ) throws {
    switch shape {
    case .singleValue:
      var container = encoder.singleValueContainer()
      try container.efficientlyEncodeBinaryData(pointer, count: count)
    case .keyed:
      var container = encoder.container(keyedBy: PointerCountCodingKey.self)
      try container.efficientlyEncodeBinaryData(pointer, count: count, forKey: .value)
    case .unkeyed:
      var container = encoder.unkeyedContainer()
      try container.efficientlyEncodeBinaryData(pointer, count: count)
    }
  }
}

// MARK: - Typed Element Helpers

private enum ElementContainerShape: CaseIterable, Sendable, CustomStringConvertible {
  case keyed
  case unkeyed

  var expectedCodingPath: [String] {
    switch self {
    case .keyed:
      [PointerCountCodingKey.value.stringValue]
    case .unkeyed:
      []
    }
  }

  var description: String {
    switch self {
    case .keyed:
      "keyed"
    case .unkeyed:
      "unkeyed"
    }
  }
}

private struct ElementPointerProbe: Sendable, CustomTestStringConvertible {
  let shape: ElementContainerShape
  let mutability: PointerMutability
  let pair: PointerCountPair

  var testDescription: String {
    "\(shape)/\(mutability)/\(pair)"
  }

  func verifyPublicHelperContract() throws {
    switch pair.isValid {
    case false:
      try requireInvalidPointerCountError(
        expectedPair: pair,
        expectedCodingPath: shape.expectedCodingPath
      ) {
        _ = try XPCEncoder.standard.encode(payload)
      }
      try requireInvalidPointerCountError(
        expectedPair: pair,
        expectedCodingPath: shape.expectedCodingPath
      ) {
        _ = try JSONEncoder().encode(payload)
      }
    case true:
      let expected = pair.representsEmptyInput ? [] : [elementProbeValues[0]]
      #expect(try decodedXPCValue() == expected)
      #expect(try decodedJSONValue() == expected)
    }
  }

  private var payload: ElementPointerPayload {
    ElementPointerPayload(
      shape: shape,
      mutability: mutability,
      pair: pair
    )
  }

  private func decodedXPCValue() throws -> [Int] {
    let encoded = try XPCEncoder.standard.encode(payload)
    switch shape {
    case .keyed:
      return try XPCDecoder.standard.decode(PointerCountElementValue.self, from: encoded).value
    case .unkeyed:
      return try XPCDecoder.standard.decode([Int].self, from: encoded)
    }
  }

  private func decodedJSONValue() throws -> [Int] {
    let encoded = try JSONEncoder().encode(payload)
    switch shape {
    case .keyed:
      return try JSONDecoder().decode(PointerCountElementValue.self, from: encoded).value
    case .unkeyed:
      return try JSONDecoder().decode([Int].self, from: encoded)
    }
  }
}

private struct ElementPointerPayload: Encodable, Sendable {
  let shape: ElementContainerShape
  let mutability: PointerMutability
  let pair: PointerCountPair

  func encode(to encoder: any Encoder) throws {
    switch mutability {
    case .immutable:
      try elementProbeValues.withUnsafeBufferPointer { buffer in
        try encode(
          pair.suppliesPointer ? buffer.baseAddress : nil,
          count: pair.count,
          to: encoder
        )
      }
    case .mutable:
      var elements = elementProbeValues
      try elements.withUnsafeMutableBufferPointer { buffer in
        try encode(
          pair.suppliesPointer ? buffer.baseAddress : nil,
          count: pair.count,
          to: encoder
        )
      }
    }
  }

  private func encode(
    _ pointer: UnsafePointer<Int>?,
    count: Int,
    to encoder: any Encoder
  ) throws {
    switch shape {
    case .keyed:
      var container = encoder.container(keyedBy: PointerCountCodingKey.self)
      try container.efficientlyEncodeElements(pointer, count: count, forKey: .value)
    case .unkeyed:
      var container = encoder.unkeyedContainer()
      try container.efficientlyEncodeElements(pointer, count: count)
    }
  }

  private func encode(
    _ pointer: UnsafeMutablePointer<Int>?,
    count: Int,
    to encoder: any Encoder
  ) throws {
    switch shape {
    case .keyed:
      var container = encoder.container(keyedBy: PointerCountCodingKey.self)
      try container.efficientlyEncodeElements(pointer, count: count, forKey: .value)
    case .unkeyed:
      var container = encoder.unkeyedContainer()
      try container.efficientlyEncodeElements(pointer, count: count)
    }
  }
}

// MARK: - Direct Enhanced Container Calls

private enum DirectEnhancedContainerShape: CaseIterable, Sendable, CustomStringConvertible {
  case singleValue
  case unkeyed

  var description: String {
    switch self {
    case .singleValue:
      "single-value"
    case .unkeyed:
      "unkeyed"
    }
  }
}

private struct DirectEnhancedPointerProbe: Sendable, CustomTestStringConvertible {
  let shape: DirectEnhancedContainerShape
  let mutability: PointerMutability
  let pair: PointerCountPair

  var testDescription: String {
    "\(shape)/\(mutability)/\(pair)"
  }

  func verifyContract() throws {
    let payload = DirectEnhancedPointerPayload(
      shape: shape,
      mutability: mutability,
      pair: pair
    )

    switch pair.isValid {
    case false:
      try requireInvalidPointerCountError(
        expectedPair: pair,
        expectedCodingPath: []
      ) {
        _ = try XPCEncoder.standard.encode(payload)
      }
    case true:
      let encoded = try XPCEncoder.standard.encode(payload)
      let expected = pair.representsEmptyInput ? Data() : Data([binaryProbeBytes[0]])
      switch shape {
      case .singleValue:
        #expect(try pointerCountData(from: encoded) == expected)
      case .unkeyed:
        #expect(try XPCDecoder.standard.decode([Data].self, from: encoded) == [expected])
      }
    }
  }
}

private struct DirectEnhancedPointerPayload: Encodable, Sendable {
  let shape: DirectEnhancedContainerShape
  let mutability: PointerMutability
  let pair: PointerCountPair

  func encode(to encoder: any Encoder) throws {
    switch mutability {
    case .immutable:
      try binaryProbeBytes.withUnsafeBytes { buffer in
        try encode(
          pair.suppliesPointer ? buffer.baseAddress : nil,
          count: pair.count,
          to: encoder
        )
      }
    case .mutable:
      var bytes = binaryProbeBytes
      try bytes.withUnsafeMutableBytes { buffer in
        try encode(
          pair.suppliesPointer ? buffer.baseAddress : nil,
          count: pair.count,
          to: encoder
        )
      }
    }
  }

  private func encode(
    _ pointer: UnsafeRawPointer?,
    count: Int,
    to encoder: any Encoder
  ) throws {
    switch shape {
    case .singleValue:
      var container = try requireEnhancedSingleValueContainer(from: encoder)
      try container.directlyEncodeXPCData(pointer, count: count)
    case .unkeyed:
      var container = try requireEnhancedUnkeyedContainer(from: encoder)
      try container.directlyEncodeXPCData(pointer, count: count)
    }
  }

  private func encode(
    _ pointer: UnsafeMutableRawPointer?,
    count: Int,
    to encoder: any Encoder
  ) throws {
    switch shape {
    case .singleValue:
      var container = try requireEnhancedSingleValueContainer(from: encoder)
      try container.directlyEncodeXPCData(pointer, count: count)
    case .unkeyed:
      var container = try requireEnhancedUnkeyedContainer(from: encoder)
      try container.directlyEncodeXPCData(pointer, count: count)
    }
  }
}

private func requireEnhancedSingleValueContainer(
  from encoder: any Encoder
) throws -> any XPCEnhancedSingleValueEncodingContainer {
  let container = encoder.singleValueContainer()
  guard let enhanced = container as? any XPCEnhancedSingleValueEncodingContainer else {
    throw PointerCountTestFailure.expectedEnhancedContainer
  }
  return enhanced
}

private func requireEnhancedUnkeyedContainer(
  from encoder: any Encoder
) throws -> any XPCEnhancedUnkeyedEncodingContainer {
  let container = encoder.unkeyedContainer()
  guard let enhanced = container as? any XPCEnhancedUnkeyedEncodingContainer else {
    throw PointerCountTestFailure.expectedEnhancedContainer
  }
  return enhanced
}

// MARK: - Keyed Shim Bypass

private struct KeyedShimInvalidProbe: Sendable, CustomTestStringConvertible {
  let mutability: PointerMutability
  let pair: PointerCountPair

  var testDescription: String {
    "\(mutability)/\(pair)"
  }

  func verifyRejection() throws {
    try requireInvalidPointerCountError(
      expectedPair: pair,
      expectedCodingPath: []
    ) {
      _ = try XPCEncoder.standard.encode(payload)
    }
    try requireInvalidPointerCountError(
      expectedPair: pair,
      expectedCodingPath: []
    ) {
      _ = try JSONEncoder().encode(payload)
    }
  }

  private var payload: KeyedShimBypassPayload {
    KeyedShimBypassPayload(
      mutability: mutability,
      pair: pair
    )
  }
}

private struct KeyedShimBypassPayload: Encodable, Sendable {
  let mutability: PointerMutability
  let pair: PointerCountPair

  func encode(to encoder: any Encoder) throws {
    switch mutability {
    case .immutable:
      try binaryProbeBytes.withUnsafeBytes { buffer in
        try UnsafeRawPointerShim(
          unsafeRawPointer: pair.suppliesPointer ? buffer.baseAddress : nil,
          count: pair.count
        ).encode(to: encoder)
      }
    case .mutable:
      var bytes = binaryProbeBytes
      try bytes.withUnsafeMutableBytes { buffer in
        try UnsafeMutableRawPointerShim(
          unsafeMutableRawPointer: pair.suppliesPointer ? buffer.baseAddress : nil,
          count: pair.count
        ).encode(to: encoder)
      }
    }
  }
}

// MARK: - Error and Result Helpers

private enum PointerCountCodingKey: String, CodingKey {
  case value
}

private struct PointerCountDataValue: Decodable, Equatable {
  let value: Data
}

private struct PointerCountElementValue: Decodable, Equatable {
  let value: [Int]
}

private let binaryProbeBytes: [UInt8] = [0x2A, 0x63]
private let elementProbeValues: [Int] = [42, 99]

private func pointerCountData(from object: xpc_object_t) throws -> Data {
  try #require(xpc_get_type(object) == XPC_TYPE_DATA)
  let byteCount = xpc_data_get_length(object)
  guard byteCount > 0 else {
    return Data()
  }

  var data = Data(repeating: 0, count: byteCount)
  let copiedByteCount = try data.withUnsafeMutableBytes { buffer in
    xpc_data_get_bytes(
      object,
      try #require(buffer.baseAddress),
      0,
      byteCount
    )
  }
  try #require(copiedByteCount == byteCount)
  return data
}

private func requireInvalidPointerCountError(
  expectedPair: PointerCountPair,
  expectedCodingPath: [String],
  sourceLocation: SourceLocation = #_sourceLocation,
  _ body: () throws -> Void
) throws {
  let encodingError: EncodingError
  do {
    try body()
    throw PointerCountTestFailure.expectedEncodingError
  } catch let error as EncodingError {
    encodingError = error
  }

  guard case .invalidValue(_, let context) = encodingError else {
    throw PointerCountTestFailure.unexpectedEncodingError(encodingError)
  }
  #expect(
    context.debugDescription == expectedPair.expectedDebugDescription,
    sourceLocation: sourceLocation
  )
  try verifyCodingPath(
    context.codingPath,
    matches: expectedCodingPath,
    sourceLocation: sourceLocation
  )
}

private enum PointerCountTestFailure: Error {
  case expectedEncodingError
  case expectedEnhancedContainer
  case unexpectedEncodingError(EncodingError)
}

// MARK: - Subprocess Support

private let pointerCountSubprocessIsolationIsSupported: Bool = {
  let interceptingSanitizerSymbols = ["__asan_init", "__tsan_init"]
  let allLoadedImages = UnsafeMutableRawPointer(bitPattern: -2)
  return interceptingSanitizerSymbols.allSatisfy { symbolName in
    symbolName.withCString { symbol in
      dlsym(allLoadedImages, symbol) == nil
    }
  }
}()
