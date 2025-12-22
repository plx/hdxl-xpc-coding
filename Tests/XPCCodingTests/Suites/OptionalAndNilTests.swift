// Tests/XPCCodingTests/Suites/OptionalAndNilTests.swift
// Comprehensive tests for optional and nil handling
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Optional and Nil Handling Test Suite

@Suite("Optional and Nil Handling", .tags(.optionals))
struct OptionalAndNilTests {

  // MARK: - Basic Optional Property Tests

  @Test("Optional property with value encodes correctly", .tags(.encoding, .roundTrip))
  func optionalPropertyWithValue() throws {
    let value = OptionalFieldStruct.withValue

    // Verify round-trip
    try verifyRoundTrip(of: value)

    // Verify XPC structure - the value should be encoded, not null
    let encoded = try XPCEncoder.encode(value)
    let optionalValue = try #require(xpc_dictionary_get_value(encoded, "optional"))
    verifyXPCType(optionalValue, is: XPC_TYPE_INT64)
    #expect(xpc_int64_get_value(optionalValue) == 42)
  }

  @Test("Optional property with nil encodes correctly", .tags(.encoding, .roundTrip))
  func optionalPropertyWithNil() throws {
    let value = OptionalFieldStruct.withoutValue

    // Verify round-trip
    try verifyRoundTrip(of: value)

    // Verify XPC structure - the value should be null or absent
    let encoded = try XPCEncoder.encode(value)
    let optionalValue = xpc_dictionary_get_value(encoded, "optional")
    // XPC can represent nil as either NULL or by omitting the key
    if let optionalValue {
      verifyXPCType(optionalValue, is: XPC_TYPE_NULL)
    }
  }

  // MARK: - encodeIfPresent Tests for All Types

  @Test("encodeIfPresent for Bool with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentBoolWithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: Bool?
    }

    let test = TestStruct(value: true)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_BOOL)
    #expect(xpc_bool_get_value(value) == true)
  }

  @Test("encodeIfPresent for Bool with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentBoolWithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: Bool?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = xpc_dictionary_get_value(encoded, "value")
    if let value {
      verifyXPCType(value, is: XPC_TYPE_NULL)
    }
  }

  @Test("encodeIfPresent for Int with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentIntWithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: Int?
    }

    let test = TestStruct(value: 123)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_INT64)
    #expect(xpc_int64_get_value(value) == 123)
  }

  @Test("encodeIfPresent for Int with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentIntWithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: Int?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for Int8 with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentInt8WithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: Int8?
    }

    let test = TestStruct(value: 42)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("encodeIfPresent for Int8 with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentInt8WithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: Int8?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for Int16 with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentInt16WithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: Int16?
    }

    let test = TestStruct(value: 1000)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("encodeIfPresent for Int16 with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentInt16WithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: Int16?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for Int32 with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentInt32WithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: Int32?
    }

    let test = TestStruct(value: 100000)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("encodeIfPresent for Int32 with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentInt32WithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: Int32?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for Int64 with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentInt64WithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: Int64?
    }

    let test = TestStruct(value: 9876543210)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_INT64)
    #expect(xpc_int64_get_value(value) == 9876543210)
  }

  @Test("encodeIfPresent for Int64 with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentInt64WithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: Int64?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for UInt with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentUIntWithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: UInt?
    }

    let test = TestStruct(value: 12345)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_UINT64)
    #expect(xpc_uint64_get_value(value) == 12345)
  }

  @Test("encodeIfPresent for UInt with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentUIntWithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: UInt?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for UInt8 with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentUInt8WithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: UInt8?
    }

    let test = TestStruct(value: 255)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("encodeIfPresent for UInt8 with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentUInt8WithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: UInt8?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for UInt16 with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentUInt16WithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: UInt16?
    }

    let test = TestStruct(value: 50000)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("encodeIfPresent for UInt16 with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentUInt16WithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: UInt16?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for UInt32 with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentUInt32WithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: UInt32?
    }

    let test = TestStruct(value: 3000000000)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("encodeIfPresent for UInt32 with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentUInt32WithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: UInt32?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for UInt64 with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentUInt64WithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: UInt64?
    }

    let test = TestStruct(value: 18446744073709551615)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_UINT64)
    #expect(xpc_uint64_get_value(value) == 18446744073709551615)
  }

  @Test("encodeIfPresent for UInt64 with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentUInt64WithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: UInt64?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for Float with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentFloatWithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: Float?

      static func == (lhs: TestStruct, rhs: TestStruct) -> Bool {
        switch (lhs.value, rhs.value) {
        case (nil, nil): return true
        case let (l?, r?): return floatsEqual(l, r)
        default: return false
        }
      }
    }

    let test = TestStruct(value: 3.14159)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("encodeIfPresent for Float with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentFloatWithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: Float?

      static func == (lhs: TestStruct, rhs: TestStruct) -> Bool {
        switch (lhs.value, rhs.value) {
        case (nil, nil): return true
        case let (l?, r?): return floatsEqual(l, r)
        default: return false
        }
      }
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for Double with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentDoubleWithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: Double?

      static func == (lhs: TestStruct, rhs: TestStruct) -> Bool {
        switch (lhs.value, rhs.value) {
        case (nil, nil): return true
        case let (l?, r?): return floatsEqual(l, r)
        default: return false
        }
      }
    }

    let test = TestStruct(value: 2.71828)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DOUBLE)
  }

  @Test("encodeIfPresent for Double with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentDoubleWithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: Double?

      static func == (lhs: TestStruct, rhs: TestStruct) -> Bool {
        switch (lhs.value, rhs.value) {
        case (nil, nil): return true
        case let (l?, r?): return floatsEqual(l, r)
        default: return false
        }
      }
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for String with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentStringWithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: String?
    }

    let test = TestStruct(value: "hello world")
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_STRING)
  }

  @Test("encodeIfPresent for String with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentStringWithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: String?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  @Test("encodeIfPresent for Data with value", .tags(.encoding, .roundTrip))
  func encodeIfPresentDataWithValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: Data?
    }

    let test = TestStruct(value: Data([0xDE, 0xAD, 0xBE, 0xEF]))
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_DATA)
  }

  @Test("encodeIfPresent for Data with nil", .tags(.encoding, .roundTrip))
  func encodeIfPresentDataWithNil() throws {
    struct TestStruct: Codable, Equatable {
      let value: Data?
    }

    let test = TestStruct(value: nil)
    try verifyRoundTrip(of: test)
  }

  // MARK: - Explicit encodeNil in Keyed Container

  @Test("Explicit encodeNil creates XPC_TYPE_NULL", .tags(.encoding, .decoding))
  func explicitEncodeNil() throws {
    struct ExplicitNil: Codable, Equatable {
      enum CodingKeys: String, CodingKey {
        case nullField
      }

      init() {}

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        #expect(try container.decodeNil(forKey: .nullField) == true)
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeNil(forKey: .nullField)
      }
    }

    let value = ExplicitNil()

    // Verify encoding creates null
    let encoded = try XPCEncoder.encode(value)
    let nullValue = try #require(xpc_dictionary_get_value(encoded, "nullField"))
    verifyXPCType(nullValue, is: XPC_TYPE_NULL)

    // Verify round-trip
    try verifyRoundTrip(of: value)
  }

  // MARK: - Nil in Array

  @Test("Array with nil elements encodes correctly", .tags(.encoding, .decoding, .unkeyed))
  func nilInArray() throws {
    let values: [String?] = ["a", nil, "b", nil, "c"]

    // Verify round-trip
    try verifyRoundTrip(of: values, areEqual: { lhs, rhs in
      guard lhs.count == rhs.count else { return false }
      for (l, r) in zip(lhs, rhs) {
        if l != r { return false }
      }
      return true
    })

    // Verify XPC structure
    let encoded = try XPCEncoder.encode(values)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)

    // Check that indices 1 and 3 are null
    let index1 = xpc_array_get_value(encoded, 1)
    verifyXPCType(index1, is: XPC_TYPE_NULL)

    let index3 = xpc_array_get_value(encoded, 3)
    verifyXPCType(index3, is: XPC_TYPE_NULL)

    // Check that other indices are strings
    let index0 = xpc_array_get_value(encoded, 0)
    verifyXPCType(index0, is: XPC_TYPE_STRING)

    let index2 = xpc_array_get_value(encoded, 2)
    verifyXPCType(index2, is: XPC_TYPE_STRING)

    let index4 = xpc_array_get_value(encoded, 4)
    verifyXPCType(index4, is: XPC_TYPE_STRING)
  }

  @Test("Array with all nil elements", .tags(.encoding, .decoding, .unkeyed))
  func arrayWithAllNils() throws {
    let values: [Int?] = [nil, nil, nil]

    try verifyRoundTrip(of: values, areEqual: { lhs, rhs in
      guard lhs.count == rhs.count else { return false }
      for (l, r) in zip(lhs, rhs) {
        if l != r { return false }
      }
      return true
    })

    let encoded = try XPCEncoder.encode(values)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)

    // All elements should be null
    for i in 0..<3 {
      let element = xpc_array_get_value(encoded, i)
      verifyXPCType(element, is: XPC_TYPE_NULL)
    }
  }

  // MARK: - Nested Optionals

  @Test("Nested optional .some(.some(value))", .tags(.encoding, .roundTrip))
  func nestedOptionalSomeSome() throws {
    struct NestedOptional: Codable, Equatable {
      let value: Int??
    }

    let test = NestedOptional(value: .some(.some(42)))
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    verifyXPCType(value, is: XPC_TYPE_INT64)
    #expect(xpc_int64_get_value(value) == 42)
  }

  @Test("Nested optional .some(.none)", .tags(.encoding, .roundTrip))
  func nestedOptionalSomeNone() throws {
    struct NestedOptional: Codable, Equatable {
      let value: Int??
    }

    let test = NestedOptional(value: .some(.none))
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = try #require(xpc_dictionary_get_value(encoded, "value"))
    // .some(.none) should encode as explicit null
    verifyXPCType(value, is: XPC_TYPE_NULL)
  }

  @Test("Nested optional .none", .tags(.encoding, .roundTrip))
  func nestedOptionalNone() throws {
    struct NestedOptional: Codable, Equatable {
      let value: Int??
    }

    let test = NestedOptional(value: .none)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let value = xpc_dictionary_get_value(encoded, "value")
    // .none can be omitted or null
    if let value {
      verifyXPCType(value, is: XPC_TYPE_NULL)
    }
  }

  // MARK: - decodeIfPresent for Missing Key

  @Test("decodeIfPresent returns nil for missing key", .tags(.decoding))
  func decodeIfPresentMissingKey() throws {
    struct TestStruct: Codable, Equatable {
      let required: String
      let optional: Int?

      init(required: String, optional: Int? = nil) {
        self.required = required
        self.optional = optional
      }

      enum CodingKeys: String, CodingKey {
        case required
        case optional
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        required = try container.decode(String.self, forKey: .required)
        // This should return nil without throwing
        optional = try container.decodeIfPresent(Int.self, forKey: .optional)
      }
    }

    // Create an XPC dictionary with only the required key
    let dict = xpc_dictionary_create(nil, nil, 0)
    "required".withCString { key in
      xpc_dictionary_set_string(dict, key, "test")
    }

    // Decode should succeed with optional = nil
    let decoded = try XPCDecoder.decode(TestStruct.self, message: dict)
    #expect(decoded.required == "test")
    #expect(decoded.optional == nil)
  }

  @Test("decodeIfPresent with null value returns nil", .tags(.decoding))
  func decodeIfPresentNullValue() throws {
    struct TestStruct: Codable, Equatable {
      let value: String?

      init(value: String? = nil) {
        self.value = value
      }
    }

    // Create an XPC dictionary with an explicit null
    let dict = xpc_dictionary_create(nil, nil, 0)
    "value".withCString { key in
      xpc_dictionary_set_value(dict, key, xpcNull())
    }

    let decoded = try XPCDecoder.decode(TestStruct.self, message: dict)
    #expect(decoded.value == nil)
  }

  // MARK: - decodeNil Advances Index

  @Test("decodeNil advances index in unkeyed container", .tags(.decoding, .unkeyed))
  func decodeNilAdvancesIndex() throws {
    struct TestDecoder: Decodable {
      let values: [String]

      init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var results: [String] = []

        // First element should be a string
        results.append(try container.decode(String.self))

        // Second element should be null
        let isNull = try container.decodeNil()
        #expect(isNull == true)

        // Third element should be a string
        results.append(try container.decode(String.self))

        values = results
      }
    }

    // Create an array with ["first", null, "second"]
    let array = xpc_array_create(nil, 0)
    xpc_array_append_value(array, xpcString("first"))
    xpc_array_append_value(array, xpcNull())
    xpc_array_append_value(array, xpcString("second"))

    let decoded = try XPCDecoder.decode(TestDecoder.self, message: array)
    #expect(decoded.values == ["first", "second"])
  }

  @Test("decodeNil returns false for non-null value", .tags(.decoding, .unkeyed))
  func decodeNilReturnsFalseForNonNull() throws {
    struct TestDecoder: Decodable {
      let isNull: Bool
      let value: String

      init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        // Try to decode nil, should return false
        isNull = try container.decodeNil()

        // Value should still be decodable
        value = try container.decode(String.self)
      }
    }

    let array = xpc_array_create(nil, 0)
    xpc_array_append_value(array, xpcString("test"))

    let decoded = try XPCDecoder.decode(TestDecoder.self, message: array)
    #expect(decoded.isNull == false)
    #expect(decoded.value == "test")
  }

  // MARK: - All Optional Struct

  @Test("Struct with all optional fields - all nil", .tags(.encoding, .roundTrip))
  func allOptionalFieldsAllNil() throws {
    struct AllOptional: Codable, Equatable {
      let a: Int?
      let b: String?
      let c: Double?
      let d: Bool?

      static func == (lhs: AllOptional, rhs: AllOptional) -> Bool {
        lhs.a == rhs.a &&
        lhs.b == rhs.b &&
        (lhs.c == rhs.c || (lhs.c == nil && rhs.c == nil) || (lhs.c.map { $0.isNaN } == true && rhs.c.map { $0.isNaN } == true)) &&
        lhs.d == rhs.d
      }
    }

    let test = AllOptional(a: nil, b: nil, c: nil, d: nil)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    // Verify it's still a valid dictionary
    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)
  }

  @Test("Struct with all optional fields - all present", .tags(.encoding, .roundTrip))
  func allOptionalFieldsAllPresent() throws {
    struct AllOptional: Codable, Equatable {
      let a: Int?
      let b: String?
      let c: Double?
      let d: Bool?

      static func == (lhs: AllOptional, rhs: AllOptional) -> Bool {
        lhs.a == rhs.a &&
        lhs.b == rhs.b &&
        (lhs.c == rhs.c || (lhs.c == nil && rhs.c == nil) || (lhs.c.map { $0.isNaN } == true && rhs.c.map { $0.isNaN } == true)) &&
        lhs.d == rhs.d
      }
    }

    let test = AllOptional(a: 42, b: "hello", c: 3.14, d: true)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)

    // Verify all values are present and correct types
    let a = try #require(xpc_dictionary_get_value(encoded, "a"))
    verifyXPCType(a, is: XPC_TYPE_INT64)

    let b = try #require(xpc_dictionary_get_value(encoded, "b"))
    verifyXPCType(b, is: XPC_TYPE_STRING)

    let c = try #require(xpc_dictionary_get_value(encoded, "c"))
    verifyXPCType(c, is: XPC_TYPE_DOUBLE)

    let d = try #require(xpc_dictionary_get_value(encoded, "d"))
    verifyXPCType(d, is: XPC_TYPE_BOOL)
  }

  @Test("Struct with all optional fields - mixed", .tags(.encoding, .roundTrip))
  func allOptionalFieldsMixed() throws {
    struct AllOptional: Codable, Equatable {
      let a: Int?
      let b: String?
      let c: Double?
      let d: Bool?

      static func == (lhs: AllOptional, rhs: AllOptional) -> Bool {
        lhs.a == rhs.a &&
        lhs.b == rhs.b &&
        (lhs.c == rhs.c || (lhs.c == nil && rhs.c == nil) || (lhs.c.map { $0.isNaN } == true && rhs.c.map { $0.isNaN } == true)) &&
        lhs.d == rhs.d
      }
    }

    let test = AllOptional(a: 42, b: nil, c: 2.718, d: nil)
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)

    // Verify present values
    let a = try #require(xpc_dictionary_get_value(encoded, "a"))
    verifyXPCType(a, is: XPC_TYPE_INT64)

    let c = try #require(xpc_dictionary_get_value(encoded, "c"))
    verifyXPCType(c, is: XPC_TYPE_DOUBLE)

    // Verify nil values are null or absent
    let b = xpc_dictionary_get_value(encoded, "b")
    if let b {
      verifyXPCType(b, is: XPC_TYPE_NULL)
    }

    let d = xpc_dictionary_get_value(encoded, "d")
    if let d {
      verifyXPCType(d, is: XPC_TYPE_NULL)
    }
  }

  // MARK: - Optional in Single Value Container

  @Test("NilWrapper with nil encodes correctly", .tags(.encoding, .roundTrip, .singleValue))
  func nilWrapperWithNil() throws {
    let wrapper = NilWrapper(isNil: true)
    try verifyRoundTrip(of: wrapper)

    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_NULL)
  }

  @Test("NilWrapper with value encodes correctly", .tags(.encoding, .roundTrip, .singleValue))
  func nilWrapperWithValue() throws {
    let wrapper = NilWrapper(isNil: false)
    try verifyRoundTrip(of: wrapper)

    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_BOOL)
    #expect(xpc_bool_get_value(encoded) == false)
  }

  // MARK: - Edge Cases

  @Test("Optional array with optional elements", .tags(.encoding, .roundTrip, .edgeCases))
  func optionalArrayWithOptionalElements() throws {
    struct TestStruct: Codable, Equatable {
      let array: [Int?]?

      static func == (lhs: TestStruct, rhs: TestStruct) -> Bool {
        switch (lhs.array, rhs.array) {
        case (nil, nil): return true
        case let (l?, r?):
          guard l.count == r.count else { return false }
          for (left, right) in zip(l, r) {
            if left != right { return false }
          }
          return true
        default: return false
        }
      }
    }

    // Test with array present containing optional elements
    let test1 = TestStruct(array: [1, nil, 3, nil, 5])
    try verifyRoundTrip(of: test1)

    // Test with nil array
    let test2 = TestStruct(array: nil)
    try verifyRoundTrip(of: test2)
  }

  @Test("Optional dictionary with optional values", .tags(.encoding, .roundTrip, .edgeCases))
  func optionalDictionaryWithOptionalValues() throws {
    struct TestStruct: Codable, Equatable {
      let dict: [String: Int?]?

      static func == (lhs: TestStruct, rhs: TestStruct) -> Bool {
        switch (lhs.dict, rhs.dict) {
        case (nil, nil): return true
        case let (l?, r?):
          guard l.count == r.count else { return false }
          for (key, leftValue) in l {
            guard r[key] != nil else { return false }
            if leftValue != r[key]! { return false }
          }
          return true
        default: return false
        }
      }
    }

    // Test with dict present containing optional values
    let test1 = TestStruct(dict: ["a": 1, "b": nil, "c": 3])
    try verifyRoundTrip(of: test1)

    // Test with nil dict
    let test2 = TestStruct(dict: nil)
    try verifyRoundTrip(of: test2)
  }

  @Test("Empty optional array", .tags(.encoding, .roundTrip, .edgeCases))
  func emptyOptionalArray() throws {
    struct TestStruct: Codable, Equatable {
      let array: [Int]?
    }

    let test = TestStruct(array: [])
    try verifyRoundTrip(of: test)

    let encoded = try XPCEncoder.encode(test)
    let array = try #require(xpc_dictionary_get_value(encoded, "array"))
    verifyXPCType(array, is: XPC_TYPE_ARRAY)
    #expect(xpc_array_get_count(array) == 0)
  }

  @Test("Optional struct with optional nested struct", .tags(.encoding, .roundTrip, .edgeCases))
  func optionalStructWithOptionalNested() throws {
    struct Inner: Codable, Equatable {
      let value: Int
    }

    struct Outer: Codable, Equatable {
      let inner: Inner?
    }

    // Test with nested struct present
    let test1 = Outer(inner: Inner(value: 42))
    try verifyRoundTrip(of: test1)

    // Test with nested struct nil
    let test2 = Outer(inner: nil)
    try verifyRoundTrip(of: test2)
  }
}
