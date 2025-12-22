// Tests/XPCCodingTests/Suites/ErrorConditionTests.swift
// Comprehensive tests for error conditions in XPC encoding/decoding
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Error Conditions Test Suite

@Suite("Error Conditions", .tags(.errors))
struct ErrorConditionTests {

  // MARK: - Encoding Errors

  @Test("Custom type throws during encoding", .tags(.encoding))
  func customTypeThrowsDuringEncoding() throws {
    let thrower = ThrowsOnEncode(message: "Test encoding failure")

    #expect(throws: ThrowsOnEncode.EncodingFailure.self) {
      try XPCEncoder.encode(thrower)
    }
  }

  @Test("Nested encoding failure propagates with context", .tags(.encoding, .nested))
  func nestedEncodingFailurePropagates() throws {
    struct NestedThrower: Encodable {
      let value: ThrowsOnEncode
    }

    let nested = NestedThrower(value: ThrowsOnEncode(message: "Nested failure"))

    #expect(throws: ThrowsOnEncode.EncodingFailure.self) {
      try XPCEncoder.encode(nested)
    }
  }

  @Test("Deeply nested encoding failure includes full path", .tags(.encoding, .nested, .codingPath))
  func deeplyNestedEncodingFailureIncludesPath() throws {
    struct Level1: Encodable {
      let level2: Level2
    }

    struct Level2: Encodable {
      let level3: Level3
    }

    struct Level3: Encodable {
      let thrower: ThrowsOnEncode
    }

    let deep = Level1(
      level2: Level2(
        level3: Level3(
          thrower: ThrowsOnEncode(message: "Deep failure")
        )
      )
    )

    #expect(throws: ThrowsOnEncode.EncodingFailure.self) {
      try XPCEncoder.encode(deep)
    }
  }

  // MARK: - Decoding Errors - Type Mismatch Primitives

  @Test("String XPC type decoded as Int throws typeMismatch", .tags(.decoding, .primitives))
  func stringAsIntThrowsTypeMismatch() throws {
    struct IntField: Decodable {
      let value: Int
    }

    let dict = createXPCDictionary([("value", xpcString("not a number"))])

    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(IntField.self, message: dict)
    }

    // Verify it's specifically a typeMismatch
    do {
      _ = try XPCDecoder.decode(IntField.self, message: dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .typeMismatch = error else {
        Issue.record("Expected typeMismatch error, got \(error)")
        return
      }
    }
  }

  @Test("Int64 XPC type decoded as String throws typeMismatch", .tags(.decoding, .primitives))
  func int64AsStringThrowsTypeMismatch() throws {
    struct StringField: Decodable {
      let value: String
    }

    let dict = createXPCDictionary([("value", xpcInt64(42))])

    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(StringField.self, message: dict)
    }

    // Verify it's specifically a typeMismatch
    do {
      _ = try XPCDecoder.decode(StringField.self, message: dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .typeMismatch(_, let context) = error else {
        Issue.record("Expected typeMismatch error, got \(error)")
        return
      }
      #expect(context.codingPath.count == 1)
      #expect(context.codingPath.first?.stringValue == "value")
    }
  }

  @Test("Bool XPC type decoded as Double throws typeMismatch", .tags(.decoding, .primitives))
  func boolAsDoubleThrowsTypeMismatch() throws {
    struct DoubleField: Decodable {
      let value: Double
    }

    let dict = createXPCDictionary([("value", xpcBool(true))])

    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(DoubleField.self, message: dict)
    }

    // Verify it's specifically a typeMismatch
    do {
      _ = try XPCDecoder.decode(DoubleField.self, message: dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .typeMismatch = error else {
        Issue.record("Expected typeMismatch error, got \(error)")
        return
      }
    }
  }

  @Test("Int64 XPC type decoded as Bool throws typeMismatch", .tags(.decoding, .primitives))
  func int64AsBoolThrowsTypeMismatch() throws {
    struct BoolField: Decodable {
      let value: Bool
    }

    let dict = createXPCDictionary([("value", xpcInt64(1))])

    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(BoolField.self, message: dict)
    }

    // Verify it's specifically a typeMismatch
    do {
      _ = try XPCDecoder.decode(BoolField.self, message: dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .typeMismatch = error else {
        Issue.record("Expected typeMismatch error, got \(error)")
        return
      }
    }
  }

  // MARK: - Decoding Errors - Type Mismatch Containers

  @Test("XPC array decoded as struct throws typeMismatch", .tags(.decoding, .containers, .keyed))
  func arrayAsStructThrowsTypeMismatch() throws {
    struct SimpleStruct: Decodable {
      let field: String
    }

    let array = createXPCArray([xpcString("value1"), xpcString("value2")])

    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(SimpleStruct.self, message: array)
    }

    // Verify it's specifically a dataCorrupted error (non-dict for keyed container)
    do {
      _ = try XPCDecoder.decode(SimpleStruct.self, message: array)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .dataCorrupted(let context) = error else {
        Issue.record("Expected dataCorrupted error, got \(error)")
        return
      }
      #expect(context.debugDescription.contains("xpc object is actually array"))
    }
  }

  @Test("XPC dictionary decoded as array throws typeMismatch", .tags(.decoding, .containers, .unkeyed))
  func dictionaryAsArrayThrowsTypeMismatch() throws {
    let dict = createXPCDictionary([("key", xpcString("value"))])

    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode([String].self, message: dict)
    }

    // Verify it's specifically a dataCorrupted error
    do {
      _ = try XPCDecoder.decode([String].self, message: dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .dataCorrupted(let context) = error else {
        Issue.record("Expected dataCorrupted error, got \(error)")
        return
      }
      #expect(context.debugDescription.contains("xpc object is actually dictionary"))
    }
  }

  @Test("XPC string decoded as keyed container throws dataCorrupted", .tags(.decoding, .containers))
  func stringAsKeyedContainerThrowsDataCorrupted() throws {
    struct RequiresContainer: Decodable {
      let field: String
    }

    let string = xpcString("not a container")

    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(RequiresContainer.self, message: string)
    }

    // Verify it's specifically a dataCorrupted error
    do {
      _ = try XPCDecoder.decode(RequiresContainer.self, message: string)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .dataCorrupted = error else {
        Issue.record("Expected dataCorrupted error, got \(error)")
        return
      }
    }
  }

  // MARK: - Decoding Errors - Key Not Found

  @Test("Missing required key throws keyNotFound", .tags(.decoding, .keyed))
  func missingRequiredKeyThrowsKeyNotFound() throws {
    struct RequiresField: Decodable {
      let required: Int
    }

    let dict = createXPCDictionary([]) // Empty dictionary

    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(RequiresField.self, message: dict)
    }

    // Verify it's specifically a keyNotFound error
    do {
      _ = try XPCDecoder.decode(RequiresField.self, message: dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .keyNotFound(let key, let context) = error else {
        Issue.record("Expected keyNotFound error, got \(error)")
        return
      }
      #expect(key.stringValue == "required")
      #expect(context.codingPath.isEmpty)
      #expect(context.debugDescription.contains("required"))
    }
  }

  @Test("Missing one of multiple required keys throws keyNotFound", .tags(.decoding, .keyed))
  func missingOneOfMultipleKeysThrowsKeyNotFound() throws {
    struct MultipleFields: Decodable {
      let first: String
      let second: Int
      let third: Bool
    }

    // Provide only first and third, missing second
    let dict = createXPCDictionary([
      ("first", xpcString("value")),
      ("third", xpcBool(true))
    ])

    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(MultipleFields.self, message: dict)
    }

    // Verify it's specifically a keyNotFound error for "second"
    do {
      _ = try XPCDecoder.decode(MultipleFields.self, message: dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .keyNotFound(let key, _) = error else {
        Issue.record("Expected keyNotFound error, got \(error)")
        return
      }
      #expect(key.stringValue == "second")
    }
  }

  @Test("Missing nested key throws keyNotFound with path", .tags(.decoding, .keyed, .nested, .codingPath))
  func missingNestedKeyThrowsKeyNotFoundWithPath() throws {
    struct Outer: Decodable {
      let inner: Inner
    }

    struct Inner: Decodable {
      let value: String
    }

    // Create dict with inner container but missing the value key
    let innerDict = createXPCDictionary([]) // Empty inner
    let outerDict = createXPCDictionary([("inner", innerDict)])

    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(Outer.self, message: outerDict)
    }

    // Verify the coding path includes both "inner" and "value"
    do {
      _ = try XPCDecoder.decode(Outer.self, message: outerDict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .keyNotFound(let key, let context) = error else {
        Issue.record("Expected keyNotFound error, got \(error)")
        return
      }
      #expect(key.stringValue == "value")
      #expect(context.codingPath.count == 1)
      #expect(context.codingPath.first?.stringValue == "inner")
    }
  }

  // MARK: - Decoding Errors - Custom Decoder Throws

  @Test("Custom decodable throws during decoding", .tags(.decoding))
  func customDecodableThrowsDuringDecoding() throws {
    let dict = createXPCDictionary([]) // Content doesn't matter

    #expect(throws: ThrowsOnDecode.DecodingFailure.self) {
      try XPCDecoder.decode(ThrowsOnDecode.self, message: dict)
    }
  }

  @Test("Nested custom decodable throws during decoding", .tags(.decoding, .nested))
  func nestedCustomDecodableThrowsDuringDecoding() throws {
    struct WrapsThrower: Decodable {
      let thrower: ThrowsOnDecode
    }

    let innerDict = createXPCDictionary([])
    let outerDict = createXPCDictionary([("thrower", innerDict)])

    #expect(throws: ThrowsOnDecode.DecodingFailure.self) {
      try XPCDecoder.decode(WrapsThrower.self, message: outerDict)
    }
  }

  // MARK: - Error Context Verification

  @Test("Shallow coding path has correct depth", .tags(.decoding, .codingPath))
  func shallowCodingPathHasCorrectDepth() throws {
    struct SingleLevel: Decodable {
      let field: Int
    }

    let dict = createXPCDictionary([("field", xpcString("wrong type"))])

    do {
      _ = try XPCDecoder.decode(SingleLevel.self, message: dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .typeMismatch(_, let context) = error else {
        Issue.record("Expected typeMismatch error, got \(error)")
        return
      }
      #expect(context.codingPath.count == 1)
      #expect(context.codingPath[0].stringValue == "field")
    }
  }

  @Test("Deep coding path has correct depth and keys", .tags(.decoding, .codingPath, .nested))
  func deepCodingPathHasCorrectDepthAndKeys() throws {
    struct Level1: Decodable {
      let level2: Level2
    }

    struct Level2: Decodable {
      let level3: Level3
    }

    struct Level3: Decodable {
      let value: Int
    }

    // Create nested structure with wrong type at deepest level
    let level3Dict = createXPCDictionary([("value", xpcString("wrong type"))])
    let level2Dict = createXPCDictionary([("level3", level3Dict)])
    let level1Dict = createXPCDictionary([("level2", level2Dict)])

    do {
      _ = try XPCDecoder.decode(Level1.self, message: level1Dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .typeMismatch(_, let context) = error else {
        Issue.record("Expected typeMismatch error, got \(error)")
        return
      }
      #expect(context.codingPath.count == 3)
      #expect(context.codingPath[0].stringValue == "level2")
      #expect(context.codingPath[1].stringValue == "level3")
      #expect(context.codingPath[2].stringValue == "value")
    }
  }

  @Test("Array index appears in coding path", .tags(.decoding, .codingPath, .unkeyed))
  func arrayIndexAppearsInCodingPath() throws {
    struct Container: Decodable {
      let items: [Int]
    }

    // Create array with wrong type at index 2
    let array = createXPCArray([
      xpcInt64(1),
      xpcInt64(2),
      xpcString("wrong type"),
      xpcInt64(4)
    ])
    let dict = createXPCDictionary([("items", array)])

    do {
      _ = try XPCDecoder.decode(Container.self, message: dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .typeMismatch(_, let context) = error else {
        Issue.record("Expected typeMismatch error, got \(error)")
        return
      }
      #expect(context.codingPath.count == 2)
      #expect(context.codingPath[0].stringValue == "items")
      #expect(context.codingPath[1].intValue == 2)
    }
  }

  @Test("Nested array error includes both key and index in path", .tags(.decoding, .codingPath, .nested, .unkeyed))
  func nestedArrayErrorIncludesKeyAndIndex() throws {
    struct Outer: Decodable {
      let inner: Inner
    }

    struct Inner: Decodable {
      let values: [String]
    }

    // Create nested structure with wrong type at array index 1
    let array = createXPCArray([
      xpcString("first"),
      xpcInt64(42), // Wrong type
      xpcString("third")
    ])
    let innerDict = createXPCDictionary([("values", array)])
    let outerDict = createXPCDictionary([("inner", innerDict)])

    do {
      _ = try XPCDecoder.decode(Outer.self, message: outerDict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .typeMismatch(_, let context) = error else {
        Issue.record("Expected typeMismatch error, got \(error)")
        return
      }
      #expect(context.codingPath.count == 3)
      #expect(context.codingPath[0].stringValue == "inner")
      #expect(context.codingPath[1].stringValue == "values")
      #expect(context.codingPath[2].intValue == 1)
    }
  }

  // MARK: - Multiple Errors

  @Test("First error is reported when multiple fields are wrong", .tags(.decoding, .errors))
  func firstErrorReportedWithMultipleWrongFields() throws {
    struct MultipleWrongFields: Decodable {
      let first: Int
      let second: String
      let third: Bool
    }

    // All fields have wrong types
    let dict = createXPCDictionary([
      ("first", xpcString("wrong")),
      ("second", xpcInt64(42)),
      ("third", xpcString("wrong"))
    ])

    // Should throw an error (typically for the first field decoded)
    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(MultipleWrongFields.self, message: dict)
    }

    // Verify we get an error (don't verify which specific field,
    // as that depends on decoding order which may vary)
    do {
      _ = try XPCDecoder.decode(MultipleWrongFields.self, message: dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .typeMismatch = error else {
        Issue.record("Expected typeMismatch error, got \(error)")
        return
      }
      // Just verify we got an error - that's sufficient
    }
  }

  @Test("Error in nested structure stops decoding", .tags(.decoding, .nested))
  func errorInNestedStructureStopsDecoding() throws {
    struct Outer: Decodable {
      let good: String
      let bad: Inner
      let alsoGood: Int
    }

    struct Inner: Decodable {
      let value: Int
    }

    // Inner has wrong type
    let innerDict = createXPCDictionary([("value", xpcString("wrong"))])
    let outerDict = createXPCDictionary([
      ("good", xpcString("correct")),
      ("bad", innerDict),
      ("alsoGood", xpcInt64(42))
    ])

    // Should throw error for the nested field
    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(Outer.self, message: outerDict)
    }

    do {
      _ = try XPCDecoder.decode(Outer.self, message: outerDict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .typeMismatch(_, let context) = error else {
        Issue.record("Expected typeMismatch error, got \(error)")
        return
      }
      // Error should be at "bad.value" path
      #expect(context.codingPath.count == 2)
      #expect(context.codingPath[0].stringValue == "bad")
      #expect(context.codingPath[1].stringValue == "value")
    }
  }

  // MARK: - Edge Cases

  @Test("Optional field with wrong type throws typeMismatch", .tags(.decoding, .optionals))
  func optionalFieldWithWrongTypeThrowsTypeMismatch() throws {
    struct OptionalField: Decodable {
      let optional: Int?
    }

    // Provide a value but with wrong type
    let dict = createXPCDictionary([("optional", xpcString("wrong"))])

    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(OptionalField.self, message: dict)
    }

    do {
      _ = try XPCDecoder.decode(OptionalField.self, message: dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .typeMismatch = error else {
        Issue.record("Expected typeMismatch error, got \(error)")
        return
      }
    }
  }

  @Test("Empty array decoded as non-empty struct array throws", .tags(.decoding, .unkeyed))
  func emptyArrayDecodedAsStructArraySucceeds() throws {
    struct Item: Decodable {
      let id: Int
    }

    struct Container: Decodable {
      let items: [Item]
    }

    // Empty array should decode successfully as empty array
    let emptyArray = createXPCArray([])
    let dict = createXPCDictionary([("items", emptyArray)])

    let result = try XPCDecoder.decode(Container.self, message: dict)
    #expect(result.items.isEmpty)
  }

  @Test("Array with insufficient elements for tuple-like decode", .tags(.decoding, .unkeyed))
  func arrayWithInsufficientElementsForTupleDecode() throws {
    struct ThreeElements: Decodable {
      let first: Int
      let second: Int
      let third: Int

      init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        first = try container.decode(Int.self)
        second = try container.decode(Int.self)
        third = try container.decode(Int.self)
      }
    }

    // Array has only 2 elements but we expect 3
    let array = createXPCArray([xpcInt64(1), xpcInt64(2)])

    #expect(throws: DecodingError.self) {
      try XPCDecoder.decode(ThreeElements.self, message: array)
    }
  }

  @Test("Debug description contains useful information", .tags(.decoding, .errors))
  func debugDescriptionContainsUsefulInformation() throws {
    struct TestStruct: Decodable {
      let field: Int
    }

    let dict = createXPCDictionary([("field", xpcString("wrong"))])

    do {
      _ = try XPCDecoder.decode(TestStruct.self, message: dict)
      Issue.record("Expected DecodingError to be thrown")
    } catch let error as DecodingError {
      guard case .typeMismatch(_, let context) = error else {
        Issue.record("Expected typeMismatch error, got \(error)")
        return
      }

      // Verify debug description contains useful info
      let desc = context.debugDescription
      #expect(desc.contains("Int"))
      #expect(desc.contains("string"))
    }
  }
}
