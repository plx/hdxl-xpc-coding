// Tests/XPCCodingTests/Suites/KeyedContainerTests.swift
// Comprehensive tests for keyed container operations
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

@Suite("Keyed Container", .tags(.keyed, .containers))
struct KeyedContainerTests {

  // MARK: - 1. Basic Keyed Encoding

  @Test("Basic keyed encoding with multiple primitive fields", .tags(.encoding, .roundTrip))
  func basicKeyedEncoding() throws {
    let value = SimpleStruct.testValue
    try verifyRoundTrip(of: value)
  }

  @Test("Verify XPC dictionary structure for simple struct", .tags(.encoding))
  func verifyXPCDictionaryStructure() throws {
    let value = SimpleStruct.testValue
    let encoded = try XPCEncoder.encode(value)

    // Verify it's a dictionary
    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)

    // Verify all keys are present
    let stringValue = try #require("stringField".withCString { key in
      xpc_dictionary_get_value(encoded, key)
    })
    verifyXPCType(stringValue, is: XPC_TYPE_STRING)

    let intValue = try #require("intField".withCString { key in
      xpc_dictionary_get_value(encoded, key)
    })
    verifyXPCType(intValue, is: XPC_TYPE_INT64)

    let doubleValue = try #require("doubleField".withCString { key in
      xpc_dictionary_get_value(encoded, key)
    })
    verifyXPCType(doubleValue, is: XPC_TYPE_DOUBLE)

    let boolValue = try #require("boolField".withCString { key in
      xpc_dictionary_get_value(encoded, key)
    })
    verifyXPCType(boolValue, is: XPC_TYPE_BOOL)
  }

  // MARK: - 2. Empty Dictionary

  @Test("Empty struct creates valid XPC dictionary", .tags(.encoding, .roundTrip))
  func emptyStructEncoding() throws {
    let empty = EmptyStruct()
    try verifyRoundTrip(of: empty)
  }

  @Test("Empty struct encodes as empty XPC dictionary", .tags(.encoding))
  func verifyEmptyDictionary() throws {
    let empty = EmptyStruct()
    let encoded = try XPCEncoder.encode(empty)

    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)

    let count = xpc_dictionary_get_count(encoded)
    #expect(count == 0)
  }

  // MARK: - 3. Nil Encoding in Keyed Container

  @Test("Optional field with value present", .tags(.encoding, .roundTrip, .optionals))
  func optionalFieldWithValue() throws {
    let value = OptionalFieldStruct.withValue
    try verifyRoundTrip(of: value)
  }

  @Test("Optional field with nil value", .tags(.encoding, .roundTrip, .optionals))
  func optionalFieldWithNil() throws {
    let value = OptionalFieldStruct.withoutValue
    try verifyRoundTrip(of: value)
  }

  @Test("`.none` for `T?` gets omitted from keyed encoders", .tags(.encoding, .optionals))
  func verifyKeyedEncoderOmitsNoneForOptionalValues() throws {
    let value = OptionalFieldStruct.withoutValue
    let encoded = try XPCEncoder.encode(value)

    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)
    let optionalFieldRepresentation = "optional".withCString { keyCString in
      xpc_dictionary_get_value(encoded, keyCString)
    }
    #expect(optionalFieldRepresentation == nil)
  }

  // MARK: - 4. encodeIfPresent Variations

  @Test("encodeIfPresent with optional Bool", .tags(.encoding, .optionals))
  func encodeIfPresentBool() throws {
    struct OptionalBoolTest: Codable, Equatable {
      let value: Bool?

      enum CodingKeys: String, CodingKey {
        case value
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(value, forKey: .value)
      }
    }

    // With value
    let withValue = OptionalBoolTest(value: true)
    try verifyRoundTrip(of: withValue)

    let encodedWithValue = try XPCEncoder.encode(withValue)
    let hasKey1 = "value".withCString { key in
      xpc_dictionary_get_value(encodedWithValue, key) != nil
    }
    #expect(hasKey1)

    // Without value (nil)
    let withoutValue = OptionalBoolTest(value: nil)
    try verifyRoundTrip(of: withoutValue)

    let encodedWithoutValue = try XPCEncoder.encode(withoutValue)
    let hasKey2 = "value".withCString { key in
      xpc_dictionary_get_value(encodedWithoutValue, key) != nil
    }
    #expect(!hasKey2, "Key should not be present when value is nil")
  }

  @Test("encodeIfPresent with optional Int", .tags(.encoding, .optionals))
  func encodeIfPresentInt() throws {
    struct OptionalIntTest: Codable, Equatable {
      let value: Int?

      enum CodingKeys: String, CodingKey {
        case value
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(value, forKey: .value)
      }
    }

    // With value
    let withValue = OptionalIntTest(value: 42)
    try verifyRoundTrip(of: withValue)

    // Without value (nil)
    let withoutValue = OptionalIntTest(value: nil)
    try verifyRoundTrip(of: withoutValue)

    let encodedWithoutValue = try XPCEncoder.encode(withoutValue)
    let hasKey = "value".withCString { key in
      xpc_dictionary_get_value(encodedWithoutValue, key) != nil
    }
    #expect(!hasKey, "Key should not be present when value is nil")
  }

  @Test("encodeIfPresent with optional String", .tags(.encoding, .optionals))
  func encodeIfPresentString() throws {
    struct OptionalStringTest: Codable, Equatable {
      let value: String?

      enum CodingKeys: String, CodingKey {
        case value
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(value, forKey: .value)
      }
    }

    // With value
    let withValue = OptionalStringTest(value: "hello")
    try verifyRoundTrip(of: withValue)

    // Without value (nil)
    let withoutValue = OptionalStringTest(value: nil)
    try verifyRoundTrip(of: withoutValue)

    let encodedWithoutValue = try XPCEncoder.encode(withoutValue)
    let hasKey = "value".withCString { key in
      xpc_dictionary_get_value(encodedWithoutValue, key) != nil
    }
    #expect(!hasKey, "Key should not be present when value is nil")
  }

  @Test("encodeIfPresent with optional Double", .tags(.encoding, .optionals))
  func encodeIfPresentDouble() throws {
    struct OptionalDoubleTest: Codable, Equatable {
      let value: Double?

      enum CodingKeys: String, CodingKey {
        case value
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(value, forKey: .value)
      }
    }

    // With value
    let withValue = OptionalDoubleTest(value: 3.14)
    try verifyRoundTrip(of: withValue)

    // Without value (nil)
    let withoutValue = OptionalDoubleTest(value: nil)
    try verifyRoundTrip(of: withoutValue)

    let encodedWithoutValue = try XPCEncoder.encode(withoutValue)
    let hasKey = "value".withCString { key in
      xpc_dictionary_get_value(encodedWithoutValue, key) != nil
    }
    #expect(!hasKey, "Key should not be present when value is nil")
  }

  // MARK: - 5. Nested Keyed Container

  @Test("Nested keyed container encoding", .tags(.encoding, .roundTrip, .nested))
  func nestedKeyedContainer() throws {
    let value = NestedKeyedContainer(outerValue: "outer", innerValue: 42)
    try verifyRoundTrip(of: value)
  }

  @Test("Verify nested XPC dictionary structure", .tags(.encoding, .nested))
  func verifyNestedDictionaryStructure() throws {
    let value = NestedKeyedContainer(outerValue: "outer", innerValue: 42)
    let encoded = try XPCEncoder.encode(value)

    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)

    // Verify outer value
    let outerValue = try #require("outerValue".withCString { key in
      xpc_dictionary_get_value(encoded, key)
    })
    verifyXPCType(outerValue, is: XPC_TYPE_STRING)

    // Verify inner container is a dictionary
    let innerDict = try #require("inner".withCString { key in
      xpc_dictionary_get_value(encoded, key)
    })
    verifyXPCType(innerDict, is: XPC_TYPE_DICTIONARY)

    // Verify inner value
    let innerValue = try #require("innerValue".withCString { key in
      xpc_dictionary_get_value(innerDict, key)
    })
    verifyXPCType(innerValue, is: XPC_TYPE_INT64)
  }

  // MARK: - 6. Nested Unkeyed Container in Keyed

  @Test("Nested unkeyed container in keyed container", .tags(.encoding, .roundTrip, .nested))
  func nestedUnkeyedInKeyed() throws {
    let value = NestedUnkeyedInKeyed(name: "test", values: [1, 2, 3, 4, 5])
    try verifyRoundTrip(of: value)
  }

  @Test("Verify nested array in dictionary structure", .tags(.encoding, .nested))
  func verifyNestedArrayStructure() throws {
    let value = NestedUnkeyedInKeyed(name: "test", values: [1, 2, 3])
    let encoded = try XPCEncoder.encode(value)

    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)

    // Verify name field
    let nameValue = try #require("name".withCString { key in
      xpc_dictionary_get_value(encoded, key)
    })
    verifyXPCType(nameValue, is: XPC_TYPE_STRING)

    // Verify values field is an array
    let valuesArray = try #require("values".withCString { key in
      xpc_dictionary_get_value(encoded, key)
    })
    verifyXPCType(valuesArray, is: XPC_TYPE_ARRAY)

    // Verify array length
    let count = xpc_array_get_count(valuesArray)
    #expect(count == 3)
  }

  // MARK: - 7. allKeys Verification

  @Test("allKeys contains expected keys", .tags(.decoding))
  func allKeysVerification() throws {
    struct AllKeysCapture: Codable, Equatable {
      var capturedKeys: [String] = []
      let field1: String
      let field2: Int
      let field3: Bool

      enum CodingKeys: String, CodingKey {
        case field1
        case field2
        case field3
      }

      init(field1: String, field2: Int, field3: Bool) {
        self.field1 = field1
        self.field2 = field2
        self.field3 = field3
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Capture all keys
        capturedKeys = container.allKeys.map { $0.stringValue }.sorted()

        field1 = try container.decode(String.self, forKey: .field1)
        field2 = try container.decode(Int.self, forKey: .field2)
        field3 = try container.decode(Bool.self, forKey: .field3)
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(field1, forKey: .field1)
        try container.encode(field2, forKey: .field2)
        try container.encode(field3, forKey: .field3)
      }

      static func == (lhs: AllKeysCapture, rhs: AllKeysCapture) -> Bool {
        lhs.field1 == rhs.field1 && lhs.field2 == rhs.field2 && lhs.field3 == rhs.field3
      }
    }

    let original = AllKeysCapture(field1: "test", field2: 42, field3: true)
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(AllKeysCapture.self, message: encoded)

    #expect(decoded.capturedKeys.count == 3)
    #expect(decoded.capturedKeys.contains("field1"))
    #expect(decoded.capturedKeys.contains("field2"))
    #expect(decoded.capturedKeys.contains("field3"))
    #expect(decoded.capturedKeys == ["field1", "field2", "field3"])
  }

  @Test("allKeys with optional fields", .tags(.decoding, .optionals))
  func allKeysWithOptionals() throws {
    struct OptionalKeysCapture: Codable, Equatable {
      var capturedKeys: [String] = []
      let required: String
      let optional: Int?

      enum CodingKeys: String, CodingKey {
        case required
        case optional
      }

      init(required: String, optional: Int?) {
        self.required = required
        self.optional = optional
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        capturedKeys = ["required"]
        required = try container.decode(String.self, forKey: .required)
        optional = try container.decodeIfPresent(Int.self, forKey: .optional)
        if optional != nil {
          capturedKeys.append("optional")
        }
      }

      static func == (lhs: OptionalKeysCapture, rhs: OptionalKeysCapture) -> Bool {
        lhs.required == rhs.required && lhs.optional == rhs.optional
      }
    }

    // Test with optional value present
    let withValue = OptionalFieldStruct.withValue
    let encodedWithValue = try XPCEncoder.encode(withValue)
    let decodedWithValue = try XPCDecoder.decode(OptionalKeysCapture.self, message: encodedWithValue)

    #expect(decodedWithValue.capturedKeys.contains("required"))
    #expect(
      (decodedWithValue.optional != nil) == decodedWithValue.capturedKeys.contains("optional"),
      "We only expect keys for optional values when the encoded value was non-nil"
    )

    // Test with optional value nil
    let withoutValue = OptionalFieldStruct.withoutValue
    let encodedWithoutValue = try XPCEncoder.encode(withoutValue)
    let decodedWithoutValue = try XPCDecoder.decode(OptionalKeysCapture.self, message: encodedWithoutValue)

    #expect(decodedWithoutValue.capturedKeys.contains("required"))
    #expect(
      (decodedWithoutValue.optional != nil) == decodedWithoutValue.capturedKeys.contains("optional"),
      "We only expect keys for optional values when the encoded value was non-nil"
    )
  }

  // MARK: - 8. contains(_:) Verification

  @Test("contains(_:) returns true for present keys", .tags(.decoding))
  func containsPresentKeys() throws {
    struct ContainsTest: Codable, Equatable {
      var containsField1: Bool = false
      var containsField2: Bool = false
      var containsField3: Bool = false
      var containsMissing: Bool = false

      let field1: String
      let field2: Int

      enum CodingKeys: String, CodingKey {
        case field1
        case field2
        case field3
        case missing
      }

      init(field1: String, field2: Int) {
        self.field1 = field1
        self.field2 = field2
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Check contains for each key
        containsField1 = container.contains(.field1)
        containsField2 = container.contains(.field2)
        containsField3 = container.contains(.field3)
        containsMissing = container.contains(.missing)

        field1 = try container.decode(String.self, forKey: .field1)
        field2 = try container.decode(Int.self, forKey: .field2)
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(field1, forKey: .field1)
        try container.encode(field2, forKey: .field2)
      }

      static func == (lhs: ContainsTest, rhs: ContainsTest) -> Bool {
        lhs.field1 == rhs.field1 && lhs.field2 == rhs.field2
      }
    }

    let original = ContainsTest(field1: "test", field2: 42)
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(ContainsTest.self, message: encoded)

    #expect(decoded.containsField1 == true)
    #expect(decoded.containsField2 == true)
    #expect(decoded.containsField3 == false)
    #expect(decoded.containsMissing == false)
  }

  @Test("contains(_:) with nil values", .tags(.decoding, .optionals))
  func containsNilValues() throws {
    struct ContainsNilTest: Codable, Equatable {
      var containerContainedRequired: Bool = false
      var containerContainedOptional: Bool = false

      let required: String
      let optional: Int?

      enum CodingKeys: String, CodingKey {
        case required
        case optional
      }

      init(required: String, optional: Int?) {
        self.required = required
        self.optional = optional
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        containerContainedRequired = container.contains(.required)
        containerContainedOptional = container.contains(.optional)

        required = try container.decode(String.self, forKey: .required)
        optional = try container.decodeIfPresent(Int.self, forKey: .optional)
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(required, forKey: .required)
        try container.encode(optional, forKey: .optional)
      }

      static func == (lhs: ContainsNilTest, rhs: ContainsNilTest) -> Bool {
        lhs.required == rhs.required && lhs.optional == rhs.optional
      }
    }

    // Test with nil value (encoded as XPC_TYPE_NULL)
    let withNil = OptionalFieldStruct.withoutValue
    let encoded = try XPCEncoder.encode(withNil)
    let decoded = try XPCDecoder.decode(ContainsNilTest.self, message: encoded)

    #expect(decoded.containerContainedRequired == true)
    #expect(
      !decoded.containerContainedOptional == true,
      "Keyed containers should skip over nil values during encoding"
    )
  }

  @Test("contains(_:) returns false for absent keys", .tags(.decoding))
  func containsAbsentKeys() throws {
    struct ContainsAbsentTest: Codable, Equatable {
      var containsPresent: Bool = false
      var containsAbsent1: Bool = false
      var containsAbsent2: Bool = false

      let present: String

      enum CodingKeys: String, CodingKey {
        case present
        case absent1
        case absent2
      }

      init(present: String) {
        self.present = present
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        containsPresent = container.contains(.present)
        containsAbsent1 = container.contains(.absent1)
        containsAbsent2 = container.contains(.absent2)

        present = try container.decode(String.self, forKey: .present)
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(present, forKey: .present)
      }

      static func == (lhs: ContainsAbsentTest, rhs: ContainsAbsentTest) -> Bool {
        lhs.present == rhs.present
      }
    }

    let original = ContainsAbsentTest(present: "here")
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(ContainsAbsentTest.self, message: encoded)

    #expect(decoded.containsPresent == true)
    #expect(decoded.containsAbsent1 == false)
    #expect(decoded.containsAbsent2 == false)
  }

  // MARK: - Additional Edge Cases

  @Test("Multiple optional fields with mixed presence", .tags(.encoding, .roundTrip, .optionals))
  func multipleOptionalFields() throws {
    struct MultiOptional: Codable, Equatable {
      let required: String
      let opt1: Int?
      let opt2: String?
      let opt3: Bool?

      enum CodingKeys: String, CodingKey {
        case required
        case opt1
        case opt2
        case opt3
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(required, forKey: .required)
        try container.encodeIfPresent(opt1, forKey: .opt1)
        try container.encodeIfPresent(opt2, forKey: .opt2)
        try container.encodeIfPresent(opt3, forKey: .opt3)
      }
    }

    let value = MultiOptional(required: "test", opt1: 42, opt2: nil, opt3: true)
    try verifyRoundTrip(of: value)

    let encoded = try XPCEncoder.encode(value)

    // Check which keys are present
    let hasRequired = "required".withCString { key in
      xpc_dictionary_get_value(encoded, key) != nil
    }
    let hasOpt1 = "opt1".withCString { key in
      xpc_dictionary_get_value(encoded, key) != nil
    }
    let hasOpt2 = "opt2".withCString { key in
      xpc_dictionary_get_value(encoded, key) != nil
    }
    let hasOpt3 = "opt3".withCString { key in
      xpc_dictionary_get_value(encoded, key) != nil
    }

    #expect(hasRequired == true)
    #expect(hasOpt1 == true)
    #expect(hasOpt2 == false, "opt2 is nil and should not be present")
    #expect(hasOpt3 == true)
  }

  @Test("Large number of keys", .tags(.encoding, .roundTrip))
  func largeNumberOfKeys() throws {
    struct ManyFields: Codable, Equatable {
      let f01: Int
      let f02: Int
      let f03: Int
      let f04: Int
      let f05: Int
      let f06: Int
      let f07: Int
      let f08: Int
      let f09: Int
      let f10: Int
      let f11: Int
      let f12: Int
      let f13: Int
      let f14: Int
      let f15: Int
      let f16: Int
      let f17: Int
      let f18: Int
      let f19: Int
      let f20: Int

      static var testValue: ManyFields {
        ManyFields(
          f01: 1, f02: 2, f03: 3, f04: 4, f05: 5,
          f06: 6, f07: 7, f08: 8, f09: 9, f10: 10,
          f11: 11, f12: 12, f13: 13, f14: 14, f15: 15,
          f16: 16, f17: 17, f18: 18, f19: 19, f20: 20
        )
      }
    }

    let value = ManyFields.testValue
    try verifyRoundTrip(of: value)

    let encoded = try XPCEncoder.encode(value)
    let count = xpc_dictionary_get_count(encoded)
    #expect(count == 20)
  }

  @Test("Keys with special characters", .tags(.encoding, .roundTrip))
  func keysWithSpecialCharacters() throws {
    struct SpecialKeys: Codable, Equatable {
      let normalKey: String
      let keyWithUnderscore: Int
      let keyWithNumber123: Bool
      let keyWithDash: Double

      enum CodingKeys: String, CodingKey {
        case normalKey
        case keyWithUnderscore = "key_with_underscore"
        case keyWithNumber123 = "key-with-number-123"
        case keyWithDash = "key-with-dash"
      }

      static var testValue: SpecialKeys {
        SpecialKeys(
          normalKey: "test",
          keyWithUnderscore: 42,
          keyWithNumber123: true,
          keyWithDash: 3.14
        )
      }
    }

    let value = SpecialKeys.testValue
    try verifyRoundTrip(of: value)
  }

  @Test("decodeNil on keyed container", .tags(.decoding, .optionals))
  func decodeNilOnKeyedContainer() throws {
    struct NilDecodeTest: Codable, Equatable {
      var wasNil: Bool = false
      let value: String?

      enum CodingKeys: String, CodingKey {
        case value
      }

      init(value: String?) {
        self.value = value
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wasNil = try container.decodeNil(forKey: .value)
        if !wasNil {
          value = try container.decode(String.self, forKey: .value)
        } else {
          value = nil
        }
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let value = value {
          try container.encode(value, forKey: .value)
        } else {
          try container.encodeNil(forKey: .value)
        }
      }

      static func == (lhs: NilDecodeTest, rhs: NilDecodeTest) -> Bool {
        lhs.value == rhs.value
      }
    }

    // Test with nil
    let withNil = NilDecodeTest(value: nil)
    let encodedNil = try XPCEncoder.encode(withNil)
    let decodedNil = try XPCDecoder.decode(NilDecodeTest.self, message: encodedNil)

    #expect(decodedNil.wasNil == true)
    #expect(decodedNil.value == nil)

    // Test with value
    let withValue = NilDecodeTest(value: "hello")
    let encodedValue = try XPCEncoder.encode(withValue)
    let decodedValue = try XPCDecoder.decode(NilDecodeTest.self, message: encodedValue)

    #expect(decodedValue.wasNil == false)
    #expect(decodedValue.value == "hello")
  }
}
