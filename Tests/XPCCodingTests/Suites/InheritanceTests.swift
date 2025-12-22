// Tests/XPCCodingTests/Suites/InheritanceTests.swift
// Comprehensive tests for class inheritance encoding/decoding
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Inheritance Test Suite

@Suite("Inheritance", .tags(.inheritance))
struct InheritanceTests {

  // MARK: - Base Class Tests

  @Test("Base class (Level0) round-trips correctly", .tags(.roundTrip))
  func baseClassRoundTrip() throws {
    let value = Level0(a: 42)
    try verifyRoundTrip(of: value)
  }

  @Test("Base class encodes to XPC dictionary", .tags(.encoding))
  func baseClassEncodesToDictionary() throws {
    let value = Level0(a: 42)
    let encoded = try XPCEncoder.encode(value)
    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)
  }

  // MARK: - Depth 1 Inheritance Tests (Level0 -> Level1)

  @Test("Level1 round-trips correctly", .tags(.roundTrip))
  func level1RoundTrip() throws {
    let value = Level1(a: 1, b: 2)
    try verifyRoundTrip(of: value)
  }

  @Test("Level1 preserves all properties through round-trip", .tags(.roundTrip))
  func level1PreservesProperties() throws {
    let original = Level1(a: 10, b: 20)
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(Level1.self, message: encoded)

    #expect(decoded.a == 10)
    #expect(decoded.b == 20)
  }

  @Test("Level1 has proper super key structure", .tags(.encoding))
  func level1HasSuperKey() throws {
    let value = Level1(a: 1, b: 2)
    let encoded = try XPCEncoder.encode(value)

    // Level1 should have "b" and "super" keys
    let bValue = xpc_dictionary_get_value(encoded, "b")
    let superValue = try #require(xpc_dictionary_get_value(encoded, "super"))

    #expect(bValue != nil, "Level1 should have 'b' key")
    verifyXPCType(superValue, is: XPC_TYPE_DICTIONARY)
  }

  // MARK: - Depth 2 Inheritance Tests (Level0 -> Level1 -> Level2)

  @Test("Level2 round-trips correctly", .tags(.roundTrip))
  func level2RoundTrip() throws {
    let value = Level2(a: 1, b: 2, c: 3)
    try verifyRoundTrip(of: value)
  }

  @Test("Level2 preserves all properties through round-trip", .tags(.roundTrip))
  func level2PreservesProperties() throws {
    let original = Level2(a: 100, b: 200, c: 300)
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(Level2.self, message: encoded)

    #expect(decoded.a == 100)
    #expect(decoded.b == 200)
    #expect(decoded.c == 300)
  }

  @Test("Level2 has nested super key structure", .tags(.encoding))
  func level2HasNestedSuperKeys() throws {
    let value = Level2(a: 1, b: 2, c: 3)
    let encoded = try XPCEncoder.encode(value)

    // Level2 should have "c" and "super" keys
    let cValue = xpc_dictionary_get_value(encoded, "c")
    let superValue = try #require(xpc_dictionary_get_value(encoded, "super"))

    #expect(cValue != nil, "Level2 should have 'c' key")
    verifyXPCType(superValue, is: XPC_TYPE_DICTIONARY)

    // The super dictionary should have "b" and "super" keys
    let bValue = xpc_dictionary_get_value(superValue, "b")
    let nestedSuperValue = try #require(xpc_dictionary_get_value(superValue, "super"))

    #expect(bValue != nil, "Level2's super should have 'b' key")
    verifyXPCType(nestedSuperValue, is: XPC_TYPE_DICTIONARY)
  }

  // MARK: - Depth 3 Inheritance Tests (Level0 -> Level1 -> Level2 -> Level3)

  @Test("Level3 round-trips correctly", .tags(.roundTrip))
  func level3RoundTrip() throws {
    let value = Level3(a: 1, b: 2, c: 3, d: 4)
    try verifyRoundTrip(of: value)
  }

  @Test("Level3 preserves all properties through round-trip", .tags(.roundTrip))
  func level3PreservesProperties() throws {
    let original = Level3(a: 111, b: 222, c: 333, d: 444)
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(Level3.self, message: encoded)

    #expect(decoded.a == 111)
    #expect(decoded.b == 222)
    #expect(decoded.c == 333)
    #expect(decoded.d == 444)
  }

  // MARK: - Depth 4 Inheritance Tests

  @Test("Level4 round-trips correctly", .tags(.roundTrip))
  func level4RoundTrip() throws {
    let value = Level4(a: 1, b: 2, c: 3, d: 4, e: 5)
    try verifyRoundTrip(of: value)
  }

  @Test("Level4 preserves all properties through round-trip", .tags(.roundTrip))
  func level4PreservesProperties() throws {
    let original = Level4(a: 10, b: 20, c: 30, d: 40, e: 50)
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(Level4.self, message: encoded)

    #expect(decoded.a == 10)
    #expect(decoded.b == 20)
    #expect(decoded.c == 30)
    #expect(decoded.d == 40)
    #expect(decoded.e == 50)
  }

  // MARK: - Depth 5 Inheritance Tests

  @Test("Level5 round-trips correctly", .tags(.roundTrip))
  func level5RoundTrip() throws {
    let value = Level5(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6)
    try verifyRoundTrip(of: value)
  }

  @Test("Level5 preserves all properties through round-trip", .tags(.roundTrip))
  func level5PreservesProperties() throws {
    let original = Level5(a: 100, b: 200, c: 300, d: 400, e: 500, f: 600)
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(Level5.self, message: encoded)

    #expect(decoded.a == 100)
    #expect(decoded.b == 200)
    #expect(decoded.c == 300)
    #expect(decoded.d == 400)
    #expect(decoded.e == 500)
    #expect(decoded.f == 600)
  }

  // MARK: - Depth 6 Inheritance Tests (Maximum Depth)

  @Test("Level6 round-trips correctly", .tags(.roundTrip))
  func level6RoundTrip() throws {
    let value = Level6(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7)
    try verifyRoundTrip(of: value)
  }

  @Test("Level6 preserves all properties through round-trip", .tags(.roundTrip))
  func level6PreservesProperties() throws {
    let original = Level6(a: 1000, b: 2000, c: 3000, d: 4000, e: 5000, f: 6000, g: 7000)
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(Level6.self, message: encoded)

    #expect(decoded.a == 1000)
    #expect(decoded.b == 2000)
    #expect(decoded.c == 3000)
    #expect(decoded.d == 4000)
    #expect(decoded.e == 5000)
    #expect(decoded.f == 6000)
    #expect(decoded.g == 7000)
  }

  @Test("Level6 with negative values round-trips correctly", .tags(.roundTrip, .edgeCases))
  func level6WithNegativeValues() throws {
    let value = Level6(a: -1, b: -2, c: -3, d: -4, e: -5, f: -6, g: -7)
    try verifyRoundTrip(of: value)
  }

  @Test("Level6 with zero values round-trips correctly", .tags(.roundTrip, .edgeCases))
  func level6WithZeroValues() throws {
    let value = Level6(a: 0, b: 0, c: 0, d: 0, e: 0, f: 0, g: 0)
    try verifyRoundTrip(of: value)
  }

  @Test("Level6 with maximum integer values round-trips correctly", .tags(.roundTrip, .edgeCases))
  func level6WithMaxValues() throws {
    let value = Level6(
      a: Int.max,
      b: Int.max - 1,
      c: Int.max - 2,
      d: Int.max - 3,
      e: Int.max - 4,
      f: Int.max - 5,
      g: Int.max - 6
    )
    try verifyRoundTrip(of: value)
  }

  // MARK: - Shared Encoder Pattern Tests

  @Test("SharedEncoderBase round-trips correctly", .tags(.roundTrip))
  func sharedEncoderBaseRoundTrip() throws {
    let value = SharedEncoderBase(baseValue: "test")
    try verifyRoundTrip(of: value)
  }

  @Test("SharedEncoderChild round-trips correctly", .tags(.roundTrip))
  func sharedEncoderChildRoundTrip() throws {
    let value = SharedEncoderChild(baseValue: "parent", childValue: 42)
    try verifyRoundTrip(of: value)
  }

  @Test("SharedEncoderChild preserves both parent and child properties", .tags(.roundTrip))
  func sharedEncoderChildPreservesProperties() throws {
    let original = SharedEncoderChild(baseValue: "inheritance", childValue: 999)
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(SharedEncoderChild.self, message: encoded)

    #expect(decoded.baseValue == "inheritance")
    #expect(decoded.childValue == 999)
  }

  @Test("SharedEncoderChild shares encoder keys with parent", .tags(.encoding))
  func sharedEncoderChildSharesEncoder() throws {
    let value = SharedEncoderChild(baseValue: "shared", childValue: 123)
    let encoded = try XPCEncoder.encode(value)

    // Both baseValue and childValue should be at the same level
    let baseValue = xpc_dictionary_get_value(encoded, "baseValue")
    let childValue = xpc_dictionary_get_value(encoded, "childValue")

    #expect(baseValue != nil, "SharedEncoderChild should have 'baseValue' key")
    #expect(childValue != nil, "SharedEncoderChild should have 'childValue' key")

    // Should NOT have a 'super' key since they share the encoder
    let superValue = xpc_dictionary_get_value(encoded, "super")
    #expect(superValue == nil, "SharedEncoderChild should not have 'super' key")
  }

  // MARK: - Custom Super Key Tests

  @Test("Custom super key round-trips correctly", .tags(.roundTrip))
  func customSuperKeyRoundTrip() throws {
    let value = CustomSuperKey(a: 10, extra: "custom")
    try verifyRoundTrip(of: value)
  }

  @Test("Custom super key preserves all properties", .tags(.roundTrip))
  func customSuperKeyPreservesProperties() throws {
    let original = CustomSuperKey(a: 99, extra: "special")
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(CustomSuperKey.self, message: encoded)

    #expect(decoded.a == 99)
    #expect(decoded.extra == "special")
  }

  @Test("Custom super key uses custom 'parent' key instead of 'super'", .tags(.encoding))
  func customSuperKeyUsesCustomKey() throws {
    let value = CustomSuperKey(a: 42, extra: "data")
    let encoded = try XPCEncoder.encode(value)

    // Should have "extra" and "parent" keys, not "super"
    let extraValue = xpc_dictionary_get_value(encoded, "extra")
    let parentValue = xpc_dictionary_get_value(encoded, "parent")
    let superValue = xpc_dictionary_get_value(encoded, "super")

    #expect(extraValue != nil, "CustomSuperKey should have 'extra' key")
    let requiredParentValue = try #require(parentValue, "CustomSuperKey should have 'parent' key instead of 'super'")
    #expect(superValue == nil, "CustomSuperKey should not have default 'super' key")
    verifyXPCType(requiredParentValue, is: XPC_TYPE_DICTIONARY)
  }

  // MARK: - Optional Properties Inheritance Tests

  @Test("OptionalBase with non-nil optional round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalBaseWithValueRoundTrip() throws {
    let value = OptionalBase(required: 100, optional: "present")
    try verifyRoundTrip(of: value)
  }

  @Test("OptionalBase with nil optional round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalBaseWithNilRoundTrip() throws {
    let value = OptionalBase(required: 100, optional: nil)
    try verifyRoundTrip(of: value)
  }

  @Test("OptionalChild with all values present round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalChildAllValuesRoundTrip() throws {
    let value = OptionalChild(required: 100, optional: "base", childOptional: 42)
    try verifyRoundTrip(of: value)
  }

  @Test("OptionalChild with base optional nil round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalChildBaseNilRoundTrip() throws {
    let value = OptionalChild(required: 100, optional: nil, childOptional: 42)
    try verifyRoundTrip(of: value)
  }

  @Test("OptionalChild with child optional nil round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalChildChildNilRoundTrip() throws {
    let value = OptionalChild(required: 100, optional: "base", childOptional: nil)
    try verifyRoundTrip(of: value)
  }

  @Test("OptionalChild with all optionals nil round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalChildAllNilRoundTrip() throws {
    let value = OptionalChild(required: 100, optional: nil, childOptional: nil)
    try verifyRoundTrip(of: value)
  }

  @Test("OptionalChild preserves optional states correctly", .tags(.roundTrip, .optionals))
  func optionalChildPreservesOptionalStates() throws {
    let original = OptionalChild(required: 999, optional: "test", childOptional: nil)
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(OptionalChild.self, message: encoded)

    #expect(decoded.required == 999)
    #expect(decoded.optional == "test")
    #expect(decoded.childOptional == nil)
  }

  // MARK: - Mixed Type Inheritance Tests

  @Test("MixedTypeChild round-trips correctly", .tags(.roundTrip))
  func mixedTypeChildRoundTrip() throws {
    let value = MixedTypeChild(
      intValue: 42,
      stringValue: "hello",
      doubleValue: 3.14,
      boolValue: true
    )
    try verifyRoundTrip(of: value)
  }

  @Test("MixedTypeChild preserves all mixed type properties", .tags(.roundTrip))
  func mixedTypeChildPreservesAllTypes() throws {
    let original = MixedTypeChild(
      intValue: 123,
      stringValue: "world",
      doubleValue: 2.718,
      boolValue: false
    )
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(MixedTypeChild.self, message: encoded)

    #expect(decoded.intValue == 123)
    #expect(decoded.stringValue == "world")
    #expect(decoded.doubleValue == 2.718)
    #expect(decoded.boolValue == false)
  }

  // MARK: - Deep Nesting Verification Tests

  @Test("Deeply nested inheritance maintains proper super chain", .tags(.encoding))
  func deepNestingMaintainsSuperChain() throws {
    let value = Level6(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7)
    let encoded = try XPCEncoder.encode(value)

    // Verify the nesting structure: Level6 -> Level5 -> Level4 -> Level3 -> Level2 -> Level1 -> Level0
    var current = encoded

    // Level6 has g and super
    let g = xpc_dictionary_get_value(current, "g")
    #expect(g != nil, "Level6 should have 'g' key")
    current = try #require(xpc_dictionary_get_value(current, "super"))
    verifyXPCType(current, is: XPC_TYPE_DICTIONARY)

    // Level5 has f and super
    let f = xpc_dictionary_get_value(current, "f")
    #expect(f != nil, "Level5 should have 'f' key")
    current = try #require(xpc_dictionary_get_value(current, "super"))
    verifyXPCType(current, is: XPC_TYPE_DICTIONARY)

    // Level4 has e and super
    let e = xpc_dictionary_get_value(current, "e")
    #expect(e != nil, "Level4 should have 'e' key")
    current = try #require(xpc_dictionary_get_value(current, "super"))
    verifyXPCType(current, is: XPC_TYPE_DICTIONARY)

    // Level3 has d and super
    let d = xpc_dictionary_get_value(current, "d")
    #expect(d != nil, "Level3 should have 'd' key")
    current = try #require(xpc_dictionary_get_value(current, "super"))
    verifyXPCType(current, is: XPC_TYPE_DICTIONARY)

    // Level2 has c and super
    let c = xpc_dictionary_get_value(current, "c")
    #expect(c != nil, "Level2 should have 'c' key")
    current = try #require(xpc_dictionary_get_value(current, "super"))
    verifyXPCType(current, is: XPC_TYPE_DICTIONARY)

    // Level1 has b and super
    let b = xpc_dictionary_get_value(current, "b")
    #expect(b != nil, "Level1 should have 'b' key")
    current = try #require(xpc_dictionary_get_value(current, "super"))
    verifyXPCType(current, is: XPC_TYPE_DICTIONARY)

    // Level0 has a only, no super
    let a = xpc_dictionary_get_value(current, "a")
    #expect(a != nil, "Level0 should have 'a' key")
    let noSuper = xpc_dictionary_get_value(current, "super")
    #expect(noSuper == nil, "Level0 should not have super key")
  }

  // MARK: - Parameterized Tests for All Levels

  @Test("All inheritance levels round-trip with consistent values",
        arguments: [
          (level: 0, values: ([1] as [Int])),
          (level: 1, values: ([1, 2] as [Int])),
          (level: 2, values: ([1, 2, 3] as [Int])),
          (level: 3, values: ([1, 2, 3, 4] as [Int])),
          (level: 4, values: ([1, 2, 3, 4, 5] as [Int])),
          (level: 5, values: ([1, 2, 3, 4, 5, 6] as [Int])),
          (level: 6, values: ([1, 2, 3, 4, 5, 6, 7] as [Int]))
        ],
//        .tags(.roundTrip)
  )
  func allLevelsRoundTrip(level: Int, values: [Int]) throws {
    switch level {
    case 0:
      try verifyRoundTrip(of: Level0(a: values[0]))
    case 1:
      try verifyRoundTrip(of: Level1(a: values[0], b: values[1]))
    case 2:
      try verifyRoundTrip(of: Level2(a: values[0], b: values[1], c: values[2]))
    case 3:
      try verifyRoundTrip(of: Level3(a: values[0], b: values[1], c: values[2], d: values[3]))
    case 4:
      try verifyRoundTrip(of: Level4(a: values[0], b: values[1], c: values[2], d: values[3], e: values[4]))
    case 5:
      try verifyRoundTrip(of: Level5(a: values[0], b: values[1], c: values[2], d: values[3], e: values[4], f: values[5]))
    case 6:
      try verifyRoundTrip(of: Level6(a: values[0], b: values[1], c: values[2], d: values[3], e: values[4], f: values[5], g: values[6]))
    default:
      Issue.record("Unexpected level: \(level)")
    }
  }
}

// MARK: - Helper Types for Custom Tests

/// A class that uses a custom super encoder key.
fileprivate final class CustomSuperKey: Level0 {
  let extra: String

  init(a: Int, extra: String) {
    self.extra = extra
    super.init(a: a)
  }

  enum CodingKeys: String, CodingKey {
    case extra
    case parent
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    extra = try container.decode(String.self, forKey: .extra)
    try super.init(from: container.superDecoder(forKey: .parent))
  }

  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(extra, forKey: .extra)
    try super.encode(to: container.superEncoder(forKey: .parent))
  }

  static func == (lhs: CustomSuperKey, rhs: CustomSuperKey) -> Bool {
    lhs.a == rhs.a && lhs.extra == rhs.extra
  }
}

/// Base class with optional property.
fileprivate class OptionalBase: Codable, Equatable {
  let required: Int
  let optional: String?

  init(required: Int, optional: String?) {
    self.required = required
    self.optional = optional
  }

  static func == (lhs: OptionalBase, rhs: OptionalBase) -> Bool {
    lhs.required == rhs.required && lhs.optional == rhs.optional
  }
}

/// Child class with additional optional property.
fileprivate final class OptionalChild: OptionalBase {
  let childOptional: Int?

  init(required: Int, optional: String?, childOptional: Int?) {
    self.childOptional = childOptional
    super.init(required: required, optional: optional)
  }

  enum CodingKeys: String, CodingKey {
    case childOptional
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    childOptional = try container.decodeIfPresent(Int.self, forKey: .childOptional)
    try super.init(from: container.superDecoder())
  }

  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(childOptional, forKey: .childOptional)
    try super.encode(to: container.superEncoder())
  }

  static func == (lhs: OptionalChild, rhs: OptionalChild) -> Bool {
    lhs.required == rhs.required &&
    lhs.optional == rhs.optional &&
    lhs.childOptional == rhs.childOptional
  }
}

/// Base class with mixed primitive types.
fileprivate class MixedTypeBase: Codable, Equatable {
  let intValue: Int
  let stringValue: String

  init(intValue: Int, stringValue: String) {
    self.intValue = intValue
    self.stringValue = stringValue
  }

  static func == (lhs: MixedTypeBase, rhs: MixedTypeBase) -> Bool {
    lhs.intValue == rhs.intValue && lhs.stringValue == rhs.stringValue
  }
}

/// Child class with additional mixed types.
fileprivate final class MixedTypeChild: MixedTypeBase {
  let doubleValue: Double
  let boolValue: Bool

  init(intValue: Int, stringValue: String, doubleValue: Double, boolValue: Bool) {
    self.doubleValue = doubleValue
    self.boolValue = boolValue
    super.init(intValue: intValue, stringValue: stringValue)
  }

  enum CodingKeys: String, CodingKey {
    case doubleValue
    case boolValue
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    doubleValue = try container.decode(Double.self, forKey: .doubleValue)
    boolValue = try container.decode(Bool.self, forKey: .boolValue)
    try super.init(from: container.superDecoder())
  }

  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(doubleValue, forKey: .doubleValue)
    try container.encode(boolValue, forKey: .boolValue)
    try super.encode(to: container.superEncoder())
  }

  static func == (lhs: MixedTypeChild, rhs: MixedTypeChild) -> Bool {
    lhs.intValue == rhs.intValue &&
    lhs.stringValue == rhs.stringValue &&
    lhs.doubleValue == rhs.doubleValue &&
    lhs.boolValue == rhs.boolValue
  }
}
