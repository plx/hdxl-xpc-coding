import Foundation
import Testing
import XPC
@testable import XPCCoding

// MARK: - Numeric Representation Tests

@Suite("Numeric Representations", .tags(.primitives, .edgeCases))
struct NumericRepresentationTests {

  @Test
  func `signed integers use checked XPC int64 scalars at every placement`() throws {
    try verifySignedRepresentations(Int.exampleValues)
    try verifySignedRepresentations(Int8.exampleValues)
    try verifySignedRepresentations(Int16.exampleValues)
    try verifySignedRepresentations(Int32.exampleValues)
    try verifySignedRepresentations(Int64.exampleValues)

    try requireDataCorrupted(Int8.self, from: xpc_int64_create(-129))
    try requireDataCorrupted(Int8.self, from: xpc_int64_create(128))
    try requireDataCorrupted(Int16.self, from: xpc_int64_create(-32_769))
    try requireDataCorrupted(Int16.self, from: xpc_int64_create(32_768))
    try requireDataCorrupted(Int32.self, from: xpc_int64_create(Int64(Int32.min) - 1))
    try requireDataCorrupted(Int32.self, from: xpc_int64_create(Int64(Int32.max) + 1))

    try requireTypeMismatch(Int.self, from: xpc_uint64_create(1))
    try requireTypeMismatch(Int8.self, from: xpc_uint64_create(1))
    try requireTypeMismatch(Int16.self, from: xpc_uint64_create(1))
    try requireTypeMismatch(Int32.self, from: xpc_uint64_create(1))
    try requireTypeMismatch(Int64.self, from: xpc_uint64_create(1))
    try requireTypeMismatch(Int8.self, from: xpcDataObject([0]))
    try requireTypeMismatch(Int16.self, from: xpcDataObject([0, 0]))
    try requireTypeMismatch(Int32.self, from: xpcDataObject([0, 0, 0, 0]))
  }

  @Test
  func `unsigned integers use checked XPC uint64 scalars at every placement`() throws {
    try verifyUnsignedRepresentations(UInt.exampleValues)
    try verifyUnsignedRepresentations(UInt8.exampleValues)
    try verifyUnsignedRepresentations(UInt16.exampleValues)
    try verifyUnsignedRepresentations(UInt32.exampleValues)
    try verifyUnsignedRepresentations(UInt64.exampleValues)

    try requireDataCorrupted(UInt8.self, from: xpc_uint64_create(256))
    try requireDataCorrupted(UInt16.self, from: xpc_uint64_create(65_536))
    try requireDataCorrupted(UInt32.self, from: xpc_uint64_create(UInt64(UInt32.max) + 1))

    try requireTypeMismatch(UInt.self, from: xpc_int64_create(1))
    try requireTypeMismatch(UInt8.self, from: xpc_int64_create(1))
    try requireTypeMismatch(UInt16.self, from: xpc_int64_create(1))
    try requireTypeMismatch(UInt32.self, from: xpc_int64_create(1))
    try requireTypeMismatch(UInt64.self, from: xpc_int64_create(1))
    try requireTypeMismatch(UInt8.self, from: xpcDataObject([0]))
    try requireTypeMismatch(UInt16.self, from: xpcDataObject([0, 0]))
    try requireTypeMismatch(UInt32.self, from: xpcDataObject([0, 0, 0, 0]))
  }

  @Test
  func `floating-point values use checked XPC double scalars at every placement`() throws {
    try verifyFloatingRepresentations(Float16.exampleValues + [-Float16.zero])
    try verifyFloatingRepresentations(Float.exampleValues + [-Float.zero])
    try verifyFloatingRepresentations(Double.exampleValues + [-Double.zero])

    try verifyFloatingDecoding(
      Float16.self,
      values: [
        Double(Float16.leastNonzeroMagnitude),
        Double(-Float16.leastNonzeroMagnitude),
        Double(Float16.greatestFiniteMagnitude),
        Double(-Float16.greatestFiniteMagnitude),
        0.0,
        -0.0,
        .infinity,
        -.infinity,
        .nan,
      ]
    )
    try verifyFloatingDecoding(
      Float.self,
      values: [
        Double(Float.leastNonzeroMagnitude),
        Double(-Float.leastNonzeroMagnitude),
        Double(Float.greatestFiniteMagnitude),
        Double(-Float.greatestFiniteMagnitude),
        0.0,
        -0.0,
        .infinity,
        -.infinity,
        .nan,
      ]
    )

    try requireDataCorrupted(Float16.self, from: xpc_double_create(1.1))
    try requireDataCorrupted(Float16.self, from: xpc_double_create(Double.greatestFiniteMagnitude))
    try requireDataCorrupted(Float16.self, from: xpc_double_create(Double.leastNonzeroMagnitude))
    try requireDataCorrupted(Float.self, from: xpc_double_create(Double.pi))
    try requireDataCorrupted(Float.self, from: xpc_double_create(Double.greatestFiniteMagnitude))
    try requireDataCorrupted(Float.self, from: xpc_double_create(Double.leastNonzeroMagnitude))

    try requireTypeMismatch(Float16.self, from: xpcDataObject([0, 0]))
    try requireTypeMismatch(Float.self, from: xpcDataObject([0, 0, 0, 0]))
    try requireTypeMismatch(Double.self, from: xpc_int64_create(1))
  }

  @Test
  func `one exact native 16-byte XPC data object represents 128-bit integers`() throws {
    for value in Int128.exampleValues {
      try verifyNative128BitRepresentation(value)
    }
    for value in UInt128.exampleValues {
      try verifyNative128BitRepresentation(value)
    }

    try requireTypeMismatch(Int128.self, from: xpc_int64_create(1))
    try requireTypeMismatch(UInt128.self, from: xpc_uint64_create(1))
    try requireDataCorrupted(Int128.self, from: xpcDataObject([UInt8](repeating: 0, count: 15)))
    try requireDataCorrupted(Int128.self, from: xpcDataObject([UInt8](repeating: 0, count: 17)))
    try requireDataCorrupted(UInt128.self, from: xpcDataObject([UInt8](repeating: 0, count: 15)))
    try requireDataCorrupted(UInt128.self, from: xpcDataObject([UInt8](repeating: 0, count: 17)))
  }

}

// MARK: - Representation Verification

private func verifySignedRepresentations<Value>(
  _ values: [Value]
) throws where Value: Codable & FixedWidthInteger {
  for value in values {
    let expected = try #require(Int64(exactly: value))
    for placement in try encodedPlacements(of: value) {
      try #require(
        xpc_get_type(placement.payload) == XPC_TYPE_INT64,
        "\(Value.self) at \(placement.description) must use XPC_TYPE_INT64."
      )
      #expect(xpc_int64_get_value(placement.payload) == expected)
      #expect(placement.objectCount == placement.expectedObjectCount)
    }
  }
}

private func verifyUnsignedRepresentations<Value>(
  _ values: [Value]
) throws where Value: Codable & FixedWidthInteger {
  for value in values {
    let expected = try #require(UInt64(exactly: value))
    for placement in try encodedPlacements(of: value) {
      try #require(
        xpc_get_type(placement.payload) == XPC_TYPE_UINT64,
        "\(Value.self) at \(placement.description) must use XPC_TYPE_UINT64."
      )
      #expect(xpc_uint64_get_value(placement.payload) == expected)
      #expect(placement.objectCount == placement.expectedObjectCount)
    }
  }
}

private func verifyFloatingRepresentations<Value>(
  _ values: [Value]
) throws where Value: BinaryFloatingPoint & Codable {
  for value in values {
    let expected = Double(value)
    for placement in try encodedPlacements(of: value) {
      try #require(
        xpc_get_type(placement.payload) == XPC_TYPE_DOUBLE,
        "\(Value.self) at \(placement.description) must use XPC_TYPE_DOUBLE."
      )
      let actual = xpc_double_get_value(placement.payload)
      if expected.isNaN {
        #expect(actual.isNaN)
      } else {
        #expect(actual.bitPattern == expected.bitPattern)
      }
      #expect(placement.objectCount == placement.expectedObjectCount)
    }
  }
}

private func verifyNative128BitRepresentation<Value>(
  _ value: Value
) throws where Value: BitwiseCopyable & Codable & Equatable {
  let expectedBytes = withUnsafeBytes(of: value) { [UInt8]($0) }
  try #require(expectedBytes.count == 16)

  for placement in try encodedPlacements(of: value) {
    try #require(
      xpc_get_type(placement.payload) == XPC_TYPE_DATA,
      "\(Value.self) at \(placement.description) must use XPC_TYPE_DATA."
    )
    #expect(xpc_data_get_length(placement.payload) == 16)
    #expect(xpcDataBytes(placement.payload) == expectedBytes)
    #expect(placement.objectCount == placement.expectedObjectCount)
  }
}

// MARK: - Checked Decoding

private func verifyFloatingDecoding<Value>(
  _ valueType: Value.Type,
  values: [Double]
) throws where Value: BinaryFloatingPoint & Codable {
  for encodedValue in values {
    let expected: Value
    if encodedValue.isNaN {
      expected = .nan
    } else {
      expected = try #require(
        Value(exactly: encodedValue),
        "\(encodedValue) should be exactly representable as \(Value.self)."
      )
    }

    for attempt in decodingAttempts(
      valueType,
      from: xpc_double_create(encodedValue)
    ) {
      let decoded = try attempt.decode()
      if expected.isNaN {
        #expect(decoded.isNaN)
      } else {
        #expect(decoded == expected)
        if expected.isZero {
          #expect(decoded.sign == expected.sign)
        }
      }
    }
  }
}

private func requireTypeMismatch<Value>(
  _ valueType: Value.Type,
  from object: xpc_object_t,
  sourceLocation: SourceLocation = #_sourceLocation
) throws where Value: Codable {
  for attempt in decodingAttempts(valueType, from: object) {
    do {
      _ = try attempt.decode()
      Issue.record(
        "\(attempt.description) should reject the wrong XPC kind as typeMismatch.",
        sourceLocation: sourceLocation
      )
    } catch DecodingError.typeMismatch {
      // Expected.
    } catch {
      Issue.record(
        "\(attempt.description) expected typeMismatch, received \(error).",
        sourceLocation: sourceLocation
      )
    }
  }
}

private func requireDataCorrupted<Value>(
  _ valueType: Value.Type,
  from object: xpc_object_t,
  sourceLocation: SourceLocation = #_sourceLocation
) throws where Value: Codable {
  for attempt in decodingAttempts(valueType, from: object) {
    do {
      _ = try attempt.decode()
      Issue.record(
        "\(attempt.description) should reject invalid content as dataCorrupted.",
        sourceLocation: sourceLocation
      )
    } catch DecodingError.dataCorrupted {
      // Expected.
    } catch {
      Issue.record(
        "\(attempt.description) expected dataCorrupted, received \(error).",
        sourceLocation: sourceLocation
      )
    }
  }
}

// MARK: - Placements

private struct NumericEnvelope<Value: Codable>: Codable {
  let value: Value
}

private struct EncodedPlacement {
  let description: String
  let message: xpc_object_t
  let payload: xpc_object_t
  let expectedObjectCount: Int

  var objectCount: Int {
    numericXPCObjectCount(message)
  }
}

private func encodedPlacements<Value>(
  of value: Value
) throws -> [EncodedPlacement] where Value: Codable {
  let encoder = XPCEncoder.standard

  let root = try encoder.encode(value)

  let keyed = try encoder.encode(NumericEnvelope(value: value))
  let keyedPayload = try #require(xpc_dictionary_get_value(keyed, "value"))

  let unkeyed = try encoder.encode([value])
  try #require(xpc_array_get_count(unkeyed) == 1)
  let unkeyedPayload = xpc_array_get_value(unkeyed, 0)

  return [
    EncodedPlacement(
      description: "root",
      message: root,
      payload: root,
      expectedObjectCount: 1
    ),
    EncodedPlacement(
      description: "keyed",
      message: keyed,
      payload: keyedPayload,
      expectedObjectCount: 2
    ),
    EncodedPlacement(
      description: "unkeyed",
      message: unkeyed,
      payload: unkeyedPayload,
      expectedObjectCount: 2
    ),
  ]
}

private struct DecodingAttempt<Value> {
  let description: String
  let decode: () throws -> Value
}

private func decodingAttempts<Value>(
  _ valueType: Value.Type,
  from payload: xpc_object_t
) -> [DecodingAttempt<Value>] where Value: Codable {
  let decoder = XPCDecoder.standard

  let dictionary = xpc_dictionary_create_empty()
  xpc_dictionary_set_value(dictionary, "value", payload)

  let array = xpc_array_create_empty()
  xpc_array_append_value(array, payload)

  return [
    DecodingAttempt(description: "root") {
      try decoder.decode(valueType, from: payload)
    },
    DecodingAttempt(description: "keyed") {
      try decoder.decode(NumericEnvelope<Value>.self, from: dictionary).value
    },
    DecodingAttempt(description: "unkeyed") {
      try decoder.decode([Value].self, from: array)[0]
    },
  ]
}

// MARK: - XPC Helpers

private func xpcDataObject(_ bytes: [UInt8]) -> xpc_object_t {
  bytes.withUnsafeBytes { buffer in
    xpc_data_create(buffer.baseAddress, buffer.count)
  }
}

private func xpcDataBytes(_ object: xpc_object_t) -> [UInt8] {
  let count = xpc_data_get_length(object)
  guard count > 0 else {
    return []
  }

  var result = [UInt8](repeating: 0, count: count)
  result.withUnsafeMutableBytes { buffer in
    let baseAddress = infalliblyUnwrap(
      buffer.baseAddress,
      explanation: "A non-empty byte buffer always has a base address."
    )
    _ = xpc_data_get_bytes(object, baseAddress, 0, count)
  }
  return result
}

private func numericXPCObjectCount(_ object: xpc_object_t) -> Int {
  switch xpc_get_type(object) {
  case XPC_TYPE_ARRAY:
    var result = 1
    for index in 0..<xpc_array_get_count(object) {
      result += numericXPCObjectCount(xpc_array_get_value(object, index))
    }
    return result
  case XPC_TYPE_DICTIONARY:
    var result = 1
    xpc_dictionary_apply(object) { _, child in
      result += numericXPCObjectCount(child)
      return true
    }
    return result
  default:
    return 1
  }
}
