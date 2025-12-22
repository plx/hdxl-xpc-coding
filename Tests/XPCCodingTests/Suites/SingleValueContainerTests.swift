// Tests/XPCCodingTests/Suites/SingleValueContainerTests.swift
// Comprehensive tests for single-value container operations
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Test Suite

@Suite("Single Value Container", .tags(.singleValue, .containers))
struct SingleValueContainerTests {

  // MARK: - Helper Types

  /// A wrapper that encodes an Int via single-value container.
  struct IntWrapper: Codable, Equatable {
    let value: Int

    init(_ value: Int) {
      self.value = value
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      value = try container.decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(value)
    }
  }

  /// A wrapper that encodes a String via single-value container.
  struct StringWrapper: Codable, Equatable {
    let value: String

    init(_ value: String) {
      self.value = value
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      value = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(value)
    }
  }

  /// A wrapper that encodes a Double via single-value container.
  struct DoubleWrapper: Codable, Equatable {
    let value: Double

    init(_ value: Double) {
      self.value = value
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      value = try container.decode(Double.self)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(value)
    }

    /// Custom equality that handles NaN correctly.
    static func == (lhs: DoubleWrapper, rhs: DoubleWrapper) -> Bool {
      floatsEqual(lhs.value, rhs.value)
    }
  }

  /// A wrapper that encodes a nested struct via single-value container.
  struct OuterWrapper: Codable, Equatable {
    let inner: SimpleStruct

    init(inner: SimpleStruct) {
      self.inner = inner
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      inner = try container.decode(SimpleStruct.self)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(inner)
    }
  }

  // MARK: - Test Cases

  // MARK: 1. Single Primitive Values

  @Test("Bool via single-value container", .tags(.primitives, .roundTrip))
  func boolValue() throws {
    let switchOn = BoolSwitch.on
    let switchOff = BoolSwitch.off

    // Test round-trip
    try verifyRoundTrip(of: switchOn)
    try verifyRoundTrip(of: switchOff)

    // Verify XPC type for true
    let encodedOn = try XPCEncoder.encode(switchOn)
    verifyXPCType(encodedOn, is: XPC_TYPE_BOOL)
    #expect(xpc_bool_get_value(encodedOn) == true)

    // Verify XPC type for false
    let encodedOff = try XPCEncoder.encode(switchOff)
    verifyXPCType(encodedOff, is: XPC_TYPE_BOOL)
    #expect(xpc_bool_get_value(encodedOff) == false)
  }

  @Test("Int via single-value container", .tags(.primitives, .roundTrip))
  func intValue() throws {
    let wrapper = IntWrapper(42)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_INT64)
    #expect(xpc_int64_get_value(encoded) == 42)
  }

  @Test("Int with negative value", .tags(.primitives, .roundTrip))
  func negativeIntValue() throws {
    let wrapper = IntWrapper(-999)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type and value
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_INT64)
    #expect(xpc_int64_get_value(encoded) == -999)
  }

  @Test("Int with zero", .tags(.primitives, .roundTrip))
  func zeroIntValue() throws {
    let wrapper = IntWrapper(0)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type and value
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_INT64)
    #expect(xpc_int64_get_value(encoded) == 0)
  }

  @Test("String via single-value container", .tags(.primitives, .roundTrip))
  func stringValue() throws {
    let wrapper = StringWrapper("Hello, XPC!")

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_STRING)
    let cString = xpc_string_get_string_ptr(encoded)
    #expect(String(cString: cString!) == "Hello, XPC!")
  }

  @Test("Empty string via single-value container", .tags(.primitives, .roundTrip, .edgeCases))
  func emptyStringValue() throws {
    let wrapper = StringWrapper("")

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_STRING)
    let cString = xpc_string_get_string_ptr(encoded)
    #expect(String(cString: cString!) == "")
  }

  @Test("String with special characters", .tags(.primitives, .roundTrip, .edgeCases))
  func stringWithSpecialCharacters() throws {
    let wrapper = StringWrapper("Hello\nWorld\t🎉")

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_STRING)
  }

  @Test("Double via single-value container", .tags(.primitives, .roundTrip))
  func doubleValue() throws {
    let wrapper = DoubleWrapper(3.14159)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DOUBLE)
    #expect(xpc_double_get_value(encoded) == 3.14159)
  }

  @Test("Double with zero", .tags(.primitives, .roundTrip))
  func zeroDoubleValue() throws {
    let wrapper = DoubleWrapper(0.0)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DOUBLE)
    #expect(xpc_double_get_value(encoded) == 0.0)
  }

  @Test("Double with negative value", .tags(.primitives, .roundTrip))
  func negativeDoubleValue() throws {
    let wrapper = DoubleWrapper(-273.15)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DOUBLE)
    #expect(xpc_double_get_value(encoded) == -273.15)
  }

  // MARK: 2. Single Nil Value

  @Test("Nil via single-value container", .tags(.optionals, .roundTrip))
  func nilValue() throws {
    let wrapper = NilWrapper(isNil: true)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_NULL)
  }

  @Test("Non-nil value via NilWrapper", .tags(.optionals, .roundTrip))
  func nonNilValue() throws {
    let wrapper = NilWrapper(isNil: false)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type (should be Bool since it encodes false)
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_BOOL)
    #expect(xpc_bool_get_value(encoded) == false)
  }

  // MARK: 3. Array via Single-Value Container

  @Test("Array via single-value container", .tags(.collections, .roundTrip))
  func arrayValue() throws {
    let wrapper = ArrayWrapper(items: [1, 2, 3, 4, 5])

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)
    #expect(xpc_array_get_count(encoded) == 5)

    // Verify first element
    let firstElement = xpc_array_get_value(encoded, 0)
    #expect(xpc_get_type(firstElement) == XPC_TYPE_INT64)
    #expect(xpc_int64_get_value(firstElement) == 1)
  }

  @Test("Empty array via single-value container", .tags(.collections, .roundTrip, .edgeCases))
  func emptyArrayValue() throws {
    let wrapper = ArrayWrapper(items: [])

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)
    #expect(xpc_array_get_count(encoded) == 0)
  }

  @Test("Large array via single-value container", .tags(.collections, .roundTrip))
  func largeArrayValue() throws {
    let items = Array(0..<100)
    let wrapper = ArrayWrapper(items: items)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)
    #expect(xpc_array_get_count(encoded) == 100)
  }

  // MARK: 4. Dictionary via Single-Value Container

  @Test("Dictionary via single-value container", .tags(.collections, .roundTrip))
  func dictionaryValue() throws {
    let wrapper = DictionaryWrapper(mapping: ["one": 1, "two": 2, "three": 3])

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)
    #expect(xpc_dictionary_get_count(encoded) == 3)

    // Verify a value
    let oneValue = "one".withCString { xpc_dictionary_get_value(encoded, $0) }
    #expect(oneValue != nil)
    #expect(xpc_get_type(oneValue!) == XPC_TYPE_INT64)
    #expect(xpc_int64_get_value(oneValue!) == 1)
  }

  @Test("Empty dictionary via single-value container", .tags(.collections, .roundTrip, .edgeCases))
  func emptyDictionaryValue() throws {
    let wrapper = DictionaryWrapper(mapping: [:])

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)
    #expect(xpc_dictionary_get_count(encoded) == 0)
  }

  @Test("Dictionary with special keys", .tags(.collections, .roundTrip, .edgeCases))
  func dictionaryWithSpecialKeys() throws {
    let wrapper = DictionaryWrapper(mapping: [
      "": 0,
      "key with spaces": 1,
      "key\nwith\nnewlines": 2,
      "🔑": 3
    ])

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)
    #expect(xpc_dictionary_get_count(encoded) == 4)
  }

  // MARK: 5. Complex Nested Type via Single-Value

  @Test("Nested struct via single-value container", .tags(.nested, .roundTrip))
  func nestedStructValue() throws {
    let inner = SimpleStruct(
      stringField: "test",
      intField: 42,
      doubleField: 3.14,
      boolField: true
    )
    let wrapper = OuterWrapper(inner: inner)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type (should be dictionary since SimpleStruct uses keyed container)
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)

    // Verify inner values
    let stringValue = "stringField".withCString { xpc_dictionary_get_value(encoded, $0) }
    #expect(stringValue != nil)
    #expect(xpc_get_type(stringValue!) == XPC_TYPE_STRING)
    let cString = xpc_string_get_string_ptr(stringValue!)
    #expect(String(cString: cString!) == "test")
  }

  @Test("Nested struct with default test value", .tags(.nested, .roundTrip))
  func nestedStructWithTestValue() throws {
    let wrapper = OuterWrapper(inner: SimpleStruct.testValue)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)
    #expect(xpc_dictionary_get_count(encoded) == 4)
  }

  // MARK: 6. decodeNil() Test

  @Test("decodeNil returns true for nil", .tags(.optionals, .decoding))
  func decodeNilReturnsTrue() throws {
    let wrapper = NilWrapper(isNil: true)

    // Encode the nil wrapper
    let encoded = try XPCEncoder.encode(wrapper)

    // Verify it's actually null
    verifyXPCType(encoded, is: XPC_TYPE_NULL)

    // Decode and verify decodeNil() returned true
    let decoded = try XPCDecoder.decode(NilWrapper.self, message: encoded)
    #expect(decoded.isNil == true)
  }

  @Test("decodeNil returns false for non-nil", .tags(.optionals, .decoding))
  func decodeNilReturnsFalse() throws {
    let wrapper = NilWrapper(isNil: false)

    // Encode the non-nil wrapper
    let encoded = try XPCEncoder.encode(wrapper)

    // Verify it's not null (should be bool)
    verifyXPCType(encoded, is: XPC_TYPE_BOOL)

    // Decode and verify decodeNil() returned false
    let decoded = try XPCDecoder.decode(NilWrapper.self, message: encoded)
    #expect(decoded.isNil == false)
  }

  // MARK: 7. Special Float Values

  @Test("Double positive infinity", .tags(.primitives, .roundTrip, .edgeCases))
  func doublePositiveInfinity() throws {
    let wrapper = DoubleWrapper(.infinity)

    // Test round-trip with custom equality
    try verifyRoundTrip(of: wrapper, areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DOUBLE)
    let value = xpc_double_get_value(encoded)
    #expect(value.isInfinite)
    #expect(value > 0)
  }

  @Test("Double negative infinity", .tags(.primitives, .roundTrip, .edgeCases))
  func doubleNegativeInfinity() throws {
    let wrapper = DoubleWrapper(-.infinity)

    // Test round-trip with custom equality
    try verifyRoundTrip(of: wrapper, areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DOUBLE)
    let value = xpc_double_get_value(encoded)
    #expect(value.isInfinite)
    #expect(value < 0)
  }

  @Test("Double NaN", .tags(.primitives, .roundTrip, .edgeCases))
  func doubleNaN() throws {
    let wrapper = DoubleWrapper(.nan)

    // Test round-trip with custom equality that handles NaN
    try verifyRoundTrip(of: wrapper, areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DOUBLE)
    let value = xpc_double_get_value(encoded)
    #expect(value.isNaN)
  }

  @Test("Double signaling NaN", .tags(.primitives, .roundTrip, .edgeCases))
  func doubleSignalingNaN() throws {
    let wrapper = DoubleWrapper(.signalingNaN)

    // Test round-trip with custom equality that handles NaN
    try verifyRoundTrip(of: wrapper, areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DOUBLE)
    let value = xpc_double_get_value(encoded)
    #expect(value.isNaN)
  }

  @Test("Double subnormal", .tags(.primitives, .roundTrip, .edgeCases))
  func doubleSubnormal() throws {
    let wrapper = DoubleWrapper(Double.leastNonzeroMagnitude)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DOUBLE)
    let value = xpc_double_get_value(encoded)
    #expect(value.isSubnormal || value == Double.leastNonzeroMagnitude)
  }

  @Test("Double minimum and maximum", .tags(.primitives, .roundTrip, .edgeCases))
  func doubleMinMax() throws {
    let minWrapper = DoubleWrapper(-Double.greatestFiniteMagnitude)
    let maxWrapper = DoubleWrapper(Double.greatestFiniteMagnitude)

    // Test round-trip
    try verifyRoundTrip(of: minWrapper)
    try verifyRoundTrip(of: maxWrapper)

    // Verify XPC types
    let minEncoded = try XPCEncoder.encode(minWrapper)
    let maxEncoded = try XPCEncoder.encode(maxWrapper)
    verifyXPCType(minEncoded, is: XPC_TYPE_DOUBLE)
    verifyXPCType(maxEncoded, is: XPC_TYPE_DOUBLE)
  }

  // MARK: - Additional Edge Cases

  @Test("Int maximum and minimum values", .tags(.primitives, .roundTrip, .edgeCases))
  func intMinMax() throws {
    let minWrapper = IntWrapper(Int.min)
    let maxWrapper = IntWrapper(Int.max)

    // Test round-trip
    try verifyRoundTrip(of: minWrapper)
    try verifyRoundTrip(of: maxWrapper)

    // Verify XPC types
    let minEncoded = try XPCEncoder.encode(minWrapper)
    let maxEncoded = try XPCEncoder.encode(maxWrapper)
    verifyXPCType(minEncoded, is: XPC_TYPE_INT64)
    verifyXPCType(maxEncoded, is: XPC_TYPE_INT64)
  }

  @Test("String with Unicode characters", .tags(.primitives, .roundTrip, .edgeCases))
  func unicodeString() throws {
    let wrapper = StringWrapper("Hello 世界 🌍 مرحبا Привет")

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_STRING)
  }

  @Test("Very long string", .tags(.primitives, .roundTrip, .edgeCases))
  func veryLongString() throws {
    let longString = String(repeating: "A", count: 10000)
    let wrapper = StringWrapper(longString)

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_STRING)
    let cString = xpc_string_get_string_ptr(encoded)
    #expect(String(cString: cString!).count == 10000)
  }

  @Test("Array with single element", .tags(.collections, .roundTrip, .edgeCases))
  func singleElementArray() throws {
    let wrapper = ArrayWrapper(items: [42])

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)
    #expect(xpc_array_get_count(encoded) == 1)
  }

  @Test("Dictionary with single element", .tags(.collections, .roundTrip, .edgeCases))
  func singleElementDictionary() throws {
    let wrapper = DictionaryWrapper(mapping: ["only": 1])

    // Test round-trip
    try verifyRoundTrip(of: wrapper)

    // Verify XPC type
    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)
    #expect(xpc_dictionary_get_count(encoded) == 1)
  }
}
