// Tests/XPCCodingTests/Support/TestHelpers.swift
// Shared test utilities
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Round-Trip Verification

/// Verifies a value round-trips correctly through XPC encoding.
/// - Parameters:
///   - value: The value to encode and decode
///   - sourceLocation: Source location for error reporting
/// - Throws: If encoding or decoding fails
func verifyRoundTrip<T: Codable & Equatable>(
  of value: T,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let encoded = try XPCEncoder.encode(value)
  let decoded = try XPCDecoder.decode(T.self, message: encoded)
  #expect(decoded == value, sourceLocation: sourceLocation)
}

/// Verifies a value round-trips correctly, using a custom equality check.
/// Useful for types like floating point that need special NaN handling.
/// - Parameters:
///   - value: The value to encode and decode
///   - areEqual: Custom equality function
///   - sourceLocation: Source location for error reporting
/// - Throws: If encoding or decoding fails
func verifyRoundTrip<T: Codable>(
  of value: T,
  areEqual: (T, T) -> Bool,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let encoded = try XPCEncoder.encode(value)
  let decoded = try XPCDecoder.decode(T.self, message: encoded)
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
func floatsEqual<F: FloatingPoint>(_ a: F, _ b: F) -> Bool {
  if a.isNaN && b.isNaN {
    return true
  }
  return a == b
}

/// Compares two Float16 values, handling NaN correctly.
func float16Equal(_ a: Float16, _ b: Float16) -> Bool {
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
  return xpc_null_create()
}

// MARK: - XPC Type Description Extension

extension xpc_type_t {
  /// A human-readable description of the XPC type.
  var typeDescription: String {
    switch self {
    case XPC_TYPE_DICTIONARY: return "XPC_TYPE_DICTIONARY"
    case XPC_TYPE_ARRAY: return "XPC_TYPE_ARRAY"
    case XPC_TYPE_STRING: return "XPC_TYPE_STRING"
    case XPC_TYPE_INT64: return "XPC_TYPE_INT64"
    case XPC_TYPE_UINT64: return "XPC_TYPE_UINT64"
    case XPC_TYPE_DOUBLE: return "XPC_TYPE_DOUBLE"
    case XPC_TYPE_BOOL: return "XPC_TYPE_BOOL"
    case XPC_TYPE_DATA: return "XPC_TYPE_DATA"
    case XPC_TYPE_NULL: return "XPC_TYPE_NULL"
    default: return "XPC_TYPE_UNKNOWN"
    }
  }
}
