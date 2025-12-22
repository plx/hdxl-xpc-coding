// Tests/XPCCodingTests/Suites/PrimitiveTypeTests.swift
// Comprehensive tests for primitive type encoding/decoding
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Primitive Types Test Suite

@Suite("Primitive Types", .tags(.primitives))
struct PrimitiveTypeTests {

  // MARK: - Boolean Tests

  @Test("Bool true round-trips correctly", .tags(.roundTrip))
  func boolTrueRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper(true))
  }

  @Test("Bool false round-trips correctly", .tags(.roundTrip))
  func boolFalseRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper(false))
  }

  @Test("Bool encodes to XPC_TYPE_BOOL", .tags(.encoding))
  func boolEncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(true)
    let encoded = try XPCEncoder.encode(wrapper)

    // The wrapper creates a dictionary, so we need to extract the value
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_BOOL)
  }

  // MARK: - Signed Integer Tests

  @Test("Int8 values round-trip correctly", arguments: [Int8.min, -1, 0, 1, Int8.max])
  func int8RoundTrip(value: Int8) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Int8 encodes to XPC_TYPE_DATA", .tags(.encoding))
  func int8EncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(Int8(42))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("Int16 values round-trip correctly", arguments: [Int16.min, -1, 0, 1, Int16.max])
  func int16RoundTrip(value: Int16) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Int16 encodes to XPC_TYPE_DATA", .tags(.encoding))
  func int16EncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(Int16(1000))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("Int32 values round-trip correctly", arguments: [Int32.min, -1, 0, 1, Int32.max])
  func int32RoundTrip(value: Int32) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Int32 encodes to XPC_TYPE_DATA", .tags(.encoding))
  func int32EncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(Int32(100000))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("Int64 values round-trip correctly", arguments: [Int64.min, -1, 0, 1, Int64.max])
  func int64RoundTrip(value: Int64) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Int64 encodes to XPC_TYPE_INT64", .tags(.encoding))
  func int64EncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(Int64(1234567890))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_INT64)
  }

  @Test("Int values round-trip correctly", arguments: [Int.min, -1, 0, 1, Int.max])
  func intRoundTrip(value: Int) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Int encodes to XPC_TYPE_INT64", .tags(.encoding))
  func intEncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(Int(9876543210))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_INT64)
  }

  // MARK: - Unsigned Integer Tests

  @Test("UInt8 values round-trip correctly", arguments: [UInt8.min, 1, UInt8.max / 2, UInt8.max])
  func uint8RoundTrip(value: UInt8) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("UInt8 encodes to XPC_TYPE_DATA", .tags(.encoding))
  func uint8EncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(UInt8(200))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("UInt16 values round-trip correctly", arguments: [UInt16.min, 1, UInt16.max / 2, UInt16.max])
  func uint16RoundTrip(value: UInt16) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("UInt16 encodes to XPC_TYPE_DATA", .tags(.encoding))
  func uint16EncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(UInt16(50000))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("UInt32 values round-trip correctly", arguments: [UInt32.min, 1, UInt32.max / 2, UInt32.max])
  func uint32RoundTrip(value: UInt32) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("UInt32 encodes to XPC_TYPE_DATA", .tags(.encoding))
  func uint32EncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(UInt32(3000000000))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("UInt64 values round-trip correctly", arguments: [UInt64.min, 1, UInt64.max / 2, UInt64.max])
  func uint64RoundTrip(value: UInt64) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("UInt64 encodes to XPC_TYPE_UINT64", .tags(.encoding))
  func uint64EncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(UInt64(18446744073709551615))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_UINT64)
  }

  @Test("UInt values round-trip correctly", arguments: [UInt.min, 1, UInt.max / 2, UInt.max])
  func uintRoundTrip(value: UInt) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("UInt encodes to XPC_TYPE_UINT64", .tags(.encoding))
  func uintEncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(UInt(12345678901234567890))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_UINT64)
  }

  // MARK: - Floating Point Tests

  @Test("Float16 special values round-trip correctly", arguments: [
    Float16(0.0),
    Float16(-0.0),
    Float16(1.0),
    Float16(-1.0),
    Float16.pi,
    Float16.infinity,
    -Float16.infinity,
    Float16.nan,
    Float16.leastNormalMagnitude,
    Float16.greatestFiniteMagnitude
  ])
  func float16RoundTrip(value: Float16) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
  }

  @Test("Float16 encodes to XPC_TYPE_DATA", .tags(.encoding))
  func float16EncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(Float16(3.14))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("Float special values round-trip correctly", arguments: [
    Float(0.0),
    Float(-0.0),
    Float(1.0),
    Float(-1.0),
    Float.pi,
    Float.infinity,
    -Float.infinity,
    Float.nan,
    Float.leastNormalMagnitude,
    Float.greatestFiniteMagnitude
  ])
  func floatRoundTrip(value: Float) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
  }

  @Test("Float encodes to XPC_TYPE_DATA", .tags(.encoding))
  func floatEncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(Float(2.71828))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("Double special values round-trip correctly", arguments: [
    Double(0.0),
    Double(-0.0),
    Double(1.0),
    Double(-1.0),
    Double.pi,
    Double.infinity,
    -Double.infinity,
    Double.nan,
    Double.leastNormalMagnitude,
    Double.greatestFiniteMagnitude
  ])
  func doubleRoundTrip(value: Double) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
  }

  @Test("Double encodes to XPC_TYPE_DOUBLE", .tags(.encoding))
  func doubleEncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(Double(1.4142135623730951))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DOUBLE)
  }

  // MARK: - String Tests

  @Test("Empty string round-trips correctly", .tags(.roundTrip))
  func emptyStringRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper(""))
  }

  @Test("Single character string round-trips correctly", .tags(.roundTrip))
  func singleCharStringRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper("a"))
  }

  @Test("Normal string round-trips correctly", .tags(.roundTrip))
  func normalStringRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper("Hello, World!"))
  }

  @Test("Unicode emoji string round-trips correctly", .tags(.roundTrip, .edgeCases))
  func emojiStringRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper("Hello 👋 World 🌍 🎉"))
  }

  @Test("Unicode CJK string round-trips correctly", .tags(.roundTrip, .edgeCases))
  func cjkStringRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper("你好世界 こんにちは世界 안녕하세요"))
  }

  @Test("Unicode RTL string round-trips correctly", .tags(.roundTrip, .edgeCases))
  func rtlStringRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper("مرحبا بالعالم שלום עולם"))
  }

  @Test("Very long string round-trips correctly", .tags(.roundTrip, .edgeCases))
  func longStringRoundTrip() throws {
    let longString = String(repeating: "a", count: 10000)
    try verifyRoundTrip(of: PrimitiveWrapper(longString))
  }

  @Test("String encodes to XPC_TYPE_STRING", .tags(.encoding))
  func stringEncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper("test string")
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_STRING)
  }

  // MARK: - Data Tests

  @Test("Empty Data round-trips correctly", .tags(.roundTrip))
  func emptyDataRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper(Data()))
  }

  @Test("Small Data round-trips correctly", .tags(.roundTrip))
  func smallDataRoundTrip() throws {
    let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A])
    try verifyRoundTrip(of: PrimitiveWrapper(data))
  }

  @Test("Data with all byte values round-trips correctly", .tags(.roundTrip, .edgeCases))
  func allBytesDataRoundTrip() throws {
    let data = Data((0...255).map { UInt8($0) })
    try verifyRoundTrip(of: PrimitiveWrapper(data))
  }

  @Test("Data encodes to XPC_TYPE_DATA", .tags(.encoding))
  func dataEncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(Data([0xDE, 0xAD, 0xBE, 0xEF]))
    let encoded = try XPCEncoder.encode(wrapper)

    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  // MARK: - Edge Case Tests

  @Test("Zero values round-trip correctly for all numeric types", .tags(.roundTrip, .edgeCases))
  func zeroValuesRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper(Int8(0)))
    try verifyRoundTrip(of: PrimitiveWrapper(Int16(0)))
    try verifyRoundTrip(of: PrimitiveWrapper(Int32(0)))
    try verifyRoundTrip(of: PrimitiveWrapper(Int64(0)))
    try verifyRoundTrip(of: PrimitiveWrapper(Int(0)))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt8(0)))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt16(0)))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt32(0)))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt64(0)))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt(0)))
    try verifyRoundTrip(of: PrimitiveWrapper(Float16(0.0)), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
    try verifyRoundTrip(of: PrimitiveWrapper(Float(0.0)), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
    try verifyRoundTrip(of: PrimitiveWrapper(Double(0.0)), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
  }

  @Test("Maximum values round-trip correctly for all integer types", .tags(.roundTrip, .edgeCases))
  func maxValuesRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper(Int8.max))
    try verifyRoundTrip(of: PrimitiveWrapper(Int16.max))
    try verifyRoundTrip(of: PrimitiveWrapper(Int32.max))
    try verifyRoundTrip(of: PrimitiveWrapper(Int64.max))
    try verifyRoundTrip(of: PrimitiveWrapper(Int.max))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt8.max))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt16.max))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt32.max))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt64.max))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt.max))
  }

  @Test("Minimum values round-trip correctly for all signed integer types", .tags(.roundTrip, .edgeCases))
  func minValuesRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper(Int8.min))
    try verifyRoundTrip(of: PrimitiveWrapper(Int16.min))
    try verifyRoundTrip(of: PrimitiveWrapper(Int32.min))
    try verifyRoundTrip(of: PrimitiveWrapper(Int64.min))
    try verifyRoundTrip(of: PrimitiveWrapper(Int.min))
  }

  @Test("Negative zero equals positive zero for floating point types", .tags(.roundTrip, .edgeCases))
  func negativeZeroEqualsPositiveZero() throws {
    // For Float16
    try verifyRoundTrip(of: PrimitiveWrapper(Float16(-0.0)), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // For Float
    try verifyRoundTrip(of: PrimitiveWrapper(Float(-0.0)), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // For Double
    try verifyRoundTrip(of: PrimitiveWrapper(Double(-0.0)), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
  }

  @Test("NaN round-trips correctly for all floating point types", .tags(.roundTrip, .edgeCases))
  func nanRoundTrips() throws {
    // Float16 NaN
    try verifyRoundTrip(of: PrimitiveWrapper(Float16.nan), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Float NaN
    try verifyRoundTrip(of: PrimitiveWrapper(Float.nan), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Double NaN
    try verifyRoundTrip(of: PrimitiveWrapper(Double.nan), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
  }

  @Test("Infinity round-trips correctly for all floating point types", .tags(.roundTrip, .edgeCases))
  func infinityRoundTrips() throws {
    // Float16 positive infinity
    try verifyRoundTrip(of: PrimitiveWrapper(Float16.infinity), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Float16 negative infinity
    try verifyRoundTrip(of: PrimitiveWrapper(-Float16.infinity), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Float positive infinity
    try verifyRoundTrip(of: PrimitiveWrapper(Float.infinity), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Float negative infinity
    try verifyRoundTrip(of: PrimitiveWrapper(-Float.infinity), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Double positive infinity
    try verifyRoundTrip(of: PrimitiveWrapper(Double.infinity), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Double negative infinity
    try verifyRoundTrip(of: PrimitiveWrapper(-Double.infinity), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
  }
}
