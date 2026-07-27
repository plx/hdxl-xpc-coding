import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - CodingPath Verification

func verifyCodingPath(
  _ codingPath: [any CodingKey],
  matches expectedKeys: [String],
  interpretAsPrefix: Bool = false,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  switch interpretAsPrefix {
  case false:
    try #require(
      codingPath.count == expectedKeys.count,
      """
      Incorrect coding-path length: expected \(expectedKeys.count) items, but got \(codingPath.count)!

      - codingPath: [ \(codingPath.map { $0.stringValue }.joined(separator: ", ")) ]
      - expectedKeys: [ \(expectedKeys.joined(separator: ", ")) ]
      """,
      sourceLocation: sourceLocation
    )
  case true:
    try #require(
      codingPath.count >= expectedKeys.count,
      """
      Discovered too-short coding-path length: expected \(expectedKeys.count) items, but got \(codingPath.count)!

      - codingPath: [ \(codingPath.map { $0.stringValue }.joined(separator: ", ")) ]
      - expectedKeys: [ \(expectedKeys.joined(separator: ", ")) ]
      """,
      sourceLocation: sourceLocation
    )
  }

  for (index, (codingKey, expectedKey)) in zip(codingPath, expectedKeys).enumerated() {
    #expect(
      codingKey.stringValue == expectedKey,
      """
      Found key mismatch @ \(index): `\(codingKey.stringValue)` != `\(expectedKey)`
      """,
      sourceLocation: sourceLocation
    )
  }
}

func verifyCodingPath(
  of encodingError: EncodingError,
  matches expectedKeys: [String],
  interpretAsPrefix: Bool = false,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let codingPath = try #require(
    encodingError.codingPath,
    """
    Couldn't find a coding path on encoding-error \(String(reflecting: encodingError))
    """,
    sourceLocation: sourceLocation
  )

  try verifyCodingPath(
    codingPath,
    matches: expectedKeys,
    interpretAsPrefix: interpretAsPrefix,
    sourceLocation: sourceLocation
  )
}

extension EncodingError {

  var codingPath: [any CodingKey]? {
    switch self {
    case .invalidValue(_, let context):
      context.codingPath
    @unknown default:
      nil
    }
  }
}

extension DecodingError {

  var codingPath: [any CodingKey]? {
    switch self {
    case .typeMismatch(_, let context):
      context.codingPath
    case .valueNotFound(_, let context):
      context.codingPath
    case .keyNotFound(_, let context):
      context.codingPath
    case .dataCorrupted(let context):
      context.codingPath
    @unknown default:
      nil
    }
  }
}

func verifyCodingPath(
  of decodingError: DecodingError,
  matches expectedKeys: [String],
  interpretAsPrefix: Bool = false,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let codingPath = try #require(
    decodingError.codingPath,
    """
    Couldn't find a coding path on decoding-error \(String(reflecting: decodingError))
    """,
    sourceLocation: sourceLocation
  )

  try verifyCodingPath(
    codingPath,
    matches: expectedKeys,
    interpretAsPrefix: interpretAsPrefix,
    sourceLocation: sourceLocation
  )
}

// MARK: - Round-Trip Verification

/// Verifies a value round-trips correctly through XPC encoding.
/// - Parameters:
///   - value: The value to encode and decode
///   - configuration: The codec-configuration to use.
///   - sourceLocation: Source location for error reporting
/// - Throws: If encoding or decoding fails
func verifyRoundTrip<T: Codable & Equatable>(
  of value: T,
  configuration: XPCCodec.Configuration,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try verifyRoundTrip(
    of: value,
    using: XPCCodec(configuration: configuration),
    sourceLocation: sourceLocation
  )
}

/// Verifies a value round-trips correctly through XPC encoding.
/// - Parameters:
///   - value: The value to encode and decode
///   - configuration: The codec-configuration to use.
///   - sourceLocation: Source location for error reporting
/// - Throws: If encoding or decoding fails
func verifyRoundTrip<T: Codable & Equatable>(
  ofValueAndWrappers value: T,
  configuration: XPCCodec.Configuration,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let codec = XPCCodec(configuration: configuration)
  try verifyRoundTrip(
    of: value,
    using: codec,
    sourceLocation: sourceLocation
  )
  try verifyRoundTrip(
    of: SingleValueWrapper(value),
    using: codec,
    sourceLocation: sourceLocation
  )
  try verifyRoundTrip(
    of: UnkeyedValueWrapper(value),
    using: codec,
    sourceLocation: sourceLocation
  )
  try verifyRoundTrip(
    of: KeyedValueWrapper(value),
    using: codec,
    sourceLocation: sourceLocation
  )
}

/// Verifies a value round-trips correctly through XPC encoding.
/// - Parameters:
///   - value: The value to encode and decode
///   - codec: The codec to use for encoding and decoding
///   - sourceLocation: Source location for error reporting
/// - Throws: If encoding or decoding fails
func verifyRoundTrip<T: Codable & Equatable>(
  of value: T,
  using codec: XPCCodec,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let encoded = try codec.encode(value)
  let decoded = try codec.decode(T.self, from: encoded)
  #expect(decoded == value, sourceLocation: sourceLocation)
}

/// Verifies a value round-trips correctly, using a custom equality check.
///
/// Useful for types like floating point that need special NaN handling.
/// - Parameters:
///   - value: The value to encode and decode
///   - configuration: The codec-configuration to use for encoding and decoding
///   - sourceLocation: Source location for error reporting
///   - areEqual: Custom equality function
/// - Throws: If encoding or decoding fails
func verifyRoundTrip<T: Codable>(
  of value: T,
  configuration: XPCCodec.Configuration,
  sourceLocation: SourceLocation = #_sourceLocation,
  areEqual: (T, T) -> Bool
) throws {
  try verifyRoundTrip(
    of: value,
    using: XPCCodec(configuration: configuration),
    sourceLocation: sourceLocation,
    areEqual: areEqual
  )
}

/// Verifies a value round-trips correctly, using a custom equality check.
///
/// Useful for types like floating point that need special NaN handling.
/// - Parameters:
///   - value: The value to encode and decode
///   - codec: The codec to use for encoding and decoding
///   - sourceLocation: Source location for error reporting
///   - areEqual: Custom equality function
/// - Throws: If encoding or decoding fails
func verifyRoundTrip<T: Codable>(
  of value: T,
  using codec: XPCCodec,
  sourceLocation: SourceLocation = #_sourceLocation,
  areEqual: (T, T) -> Bool
) throws {
  let encoded = try codec.encode(value)
  let decoded = try codec.decode(T.self, from: encoded)
  #expect(areEqual(value, decoded), sourceLocation: sourceLocation)
}

// MARK: - XPC Type Verification

/// Verifies an XPC object has the expected type.
/// - Parameters:
///   - object: The XPC object to check
///   - expectedType: The expected XPC type
///   - sourceLocation: Source location for error reporting
func verifyXPCType(
  _ object: xpc_object_t,
  is expectedType: xpc_type_t,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  let actualType = xpc_get_type(object)
  #expect(
    actualType == expectedType,
    "Expected XPC type \(expectedType.typeDescription) but got \(actualType.typeDescription)",
    sourceLocation: sourceLocation
  )
}

// MARK: - XPC Object Creation Helpers

/// Creates an XPC dictionary from key-value pairs.
/// - Parameter pairs: Array of (key, value) tuples
/// - Returns: An XPC dictionary object
func createXPCDictionary(_ pairs: [(String, xpc_object_t)]) -> xpc_object_t {
  let dict = xpc_dictionary_create(nil, nil, 0)
  for (key, value) in pairs {
    key.withCString { cKey in
      xpc_dictionary_set_value(dict, cKey, value)
    }
  }
  return dict
}

func createXPCString(_ value: String) -> xpc_object_t {
  value.withCString { xpc_string_create($0) }
}

func createXPCDictionary(key: String, value: LosslessXPCObjectConvertible) -> xpc_object_t {
  createXPCDictionary(key: key, value: value.xpcObjectRepresentation)
}

func createXPCDictionary(key: String, value: xpc_object_t) -> xpc_object_t {
  let dict = xpc_dictionary_create(nil, nil, 0)
  key.withCString { cString in
    xpc_dictionary_set_value(dict, cString, value)
  }
  return dict
}

/// Creates an XPC array from values.
/// - Parameter values: Array of XPC objects
/// - Returns: An XPC array object
func createXPCArray(_ values: [xpc_object_t]) -> xpc_object_t {
  let array = xpc_array_create(nil, 0)
  for value in values {
    xpc_array_append_value(array, value)
  }
  return array
}

// MARK: - Floating Point Helpers

/// Compares two floating point values, handling NaN correctly.
/// - Parameters:
///   - a: First value
///   - b: Second value
/// - Returns: true if values are equal (or both NaN)
func equivalentFloats<F: FloatingPoint>(_ a: F, _ b: F) -> Bool {
  if a.isNaN && b.isNaN {
    return true
  }
  return a == b
}

// MARK: - XPC Primitive Creation

/// Creates an XPC string object.
func xpcString(_ value: String) -> xpc_object_t {
  value.withCString { xpc_string_create($0) }
}

/// Creates an XPC int64 object.
func xpcInt64(_ value: Int64) -> xpc_object_t {
  xpc_int64_create(value)
}

/// Creates an XPC uint64 object.
func xpcUInt64(_ value: UInt64) -> xpc_object_t {
  xpc_uint64_create(value)
}

/// Creates an XPC double object.
func xpcDouble(_ value: Double) -> xpc_object_t {
  xpc_double_create(value)
}

/// Creates an XPC bool object.
func xpcBool(_ value: Bool) -> xpc_object_t {
  xpc_bool_create(value)
}

/// Creates an XPC data object.
func xpcData(_ value: Data) -> xpc_object_t {
  value.withUnsafeBytes { buffer in
    xpc_data_create(buffer.baseAddress, buffer.count)
  }
}

/// Creates an XPC null object.
func xpcNull() -> xpc_object_t {
  xpc_null_create()
}

func allCodecs() -> [XPCCodec] {
  XPCCodec.Configuration.allCases.map {
    XPCCodec(configuration: $0)
  }
}
