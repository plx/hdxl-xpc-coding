// Tests/XPCCodingTests/Support/TestTypes.swift
// Shared test type definitions
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Foundation
import XPC
@testable import XPCCoding

// MARK: - Primitive Wrapper

/// A wrapper that holds a single primitive value for keyed container testing.
struct PrimitiveWrapper<T: Codable & Equatable>: Codable, Equatable {
  let value: T

  init(_ value: T) {
    self.value = value
  }
}

extension PrimitiveWrapper: Sendable where T: Sendable { }

// MARK: - Coding Path Tracker

/// A type that records the coding path during encode/decode for verification.
struct CodingPathTracker: Codable, Equatable {
  nonisolated(unsafe) static var lastEncodingPath: [String] = []
  nonisolated(unsafe) static var lastDecodingPath: [String] = []

  let marker: String

  init(marker: String = "tracker") {
    self.marker = marker
  }

  init(from decoder: Decoder) throws {
    Self.lastDecodingPath = decoder.codingPath.map { $0.stringValue }
    let container = try decoder.singleValueContainer()
    marker = try container.decode(String.self)
  }

  func encode(to encoder: Encoder) throws {
    Self.lastEncodingPath = encoder.codingPath.map { $0.stringValue }
    var container = encoder.singleValueContainer()
    try container.encode(marker)
  }
}

// MARK: - Throwing Types

/// A type that always throws during encoding.
struct ThrowsOnEncode: Encodable {
  struct EncodingFailure: Error {
    let message: String
  }

  let message: String

  init(message: String = "Encoding failed") {
    self.message = message
  }

  func encode(to encoder: Encoder) throws {
    throw EncodingFailure(message: message)
  }
}

/// A type that always throws during decoding.
struct ThrowsOnDecode: Decodable {
  struct DecodingFailure: Error {
    let message: String
  }

  init(from decoder: Decoder) throws {
    throw DecodingFailure(message: "Decoding failed")
  }
}

// MARK: - Empty Types

/// An empty struct for testing empty keyed containers.
struct EmptyStruct: Codable, Equatable {}

/// An empty class for testing empty keyed containers.
final class EmptyClass: Codable, Equatable {
  static func == (lhs: EmptyClass, rhs: EmptyClass) -> Bool { true }
}

// MARK: - Single-Value Types

/// A type that encodes as a single Bool value.
enum BoolSwitch: Codable, Equatable {
  case off
  case on

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self = try container.decode(Bool.self) ? .on : .off
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self == .on)
  }
}

/// A type that encodes nil via single-value container.
struct NilWrapper: Codable, Equatable {
  let isNil: Bool

  init(isNil: Bool = true) {
    self.isNil = isNil
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    isNil = container.decodeNil()
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    if isNil {
      try container.encodeNil()
    } else {
      try container.encode(false)
    }
  }
}

// MARK: - Structured Types

/// A simple struct with multiple primitive fields.
struct SimpleStruct: Codable, Equatable {
  let stringField: String
  let intField: Int
  let doubleField: Double
  let boolField: Bool

  static var testValue: SimpleStruct {
    SimpleStruct(
      stringField: "hello",
      intField: 42,
      doubleField: 3.14159,
      boolField: true
    )
  }
}

/// A struct with an optional field.
struct OptionalFieldStruct: Codable, Equatable {
  let required: String
  let optional: Int?

  static var withValue: OptionalFieldStruct {
    OptionalFieldStruct(required: "test", optional: 42)
  }

  static var withoutValue: OptionalFieldStruct {
    OptionalFieldStruct(required: "test", optional: nil)
  }
}

/// A struct that encodes an array via single-value container.
struct ArrayWrapper: Codable, Equatable {
  let items: [Int]

  init(items: [Int]) {
    self.items = items
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    items = try container.decode([Int].self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(items)
  }
}

/// A struct that encodes a dictionary via single-value container.
struct DictionaryWrapper: Codable, Equatable {
  let mapping: [String: Int]

  init(mapping: [String: Int]) {
    self.mapping = mapping
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    mapping = try container.decode([String: Int].self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(mapping)
  }
}

// MARK: - Inheritance Hierarchy (Depth 6)

/// Base class (Level 0) for inheritance testing.
class Level0: Codable, Equatable {
  let a: Int

  init(a: Int) {
    self.a = a
  }

  static func == (lhs: Level0, rhs: Level0) -> Bool {
    lhs.a == rhs.a
  }
}

/// Level 1 subclass using superEncoder.
class Level1: Level0 {
  let b: Int

  init(a: Int, b: Int) {
    self.b = b
    super.init(a: a)
  }

  enum CodingKeys: String, CodingKey {
    case b
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    b = try container.decode(Int.self, forKey: .b)
    try super.init(from: container.superDecoder())
  }

  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(b, forKey: .b)
    try super.encode(to: container.superEncoder())
  }

  static func == (lhs: Level1, rhs: Level1) -> Bool {
    lhs.a == rhs.a && lhs.b == rhs.b
  }
}

/// Level 2 subclass.
class Level2: Level1 {
  let c: Int

  init(a: Int, b: Int, c: Int) {
    self.c = c
    super.init(a: a, b: b)
  }

  enum CodingKeys: String, CodingKey {
    case c
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    c = try container.decode(Int.self, forKey: .c)
    try super.init(from: container.superDecoder())
  }

  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(c, forKey: .c)
    try super.encode(to: container.superEncoder())
  }

  static func == (lhs: Level2, rhs: Level2) -> Bool {
    lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c
  }
}

/// Level 3 subclass.
class Level3: Level2 {
  let d: Int

  init(a: Int, b: Int, c: Int, d: Int) {
    self.d = d
    super.init(a: a, b: b, c: c)
  }

  enum CodingKeys: String, CodingKey {
    case d
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    d = try container.decode(Int.self, forKey: .d)
    try super.init(from: container.superDecoder())
  }

  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(d, forKey: .d)
    try super.encode(to: container.superEncoder())
  }

  static func == (lhs: Level3, rhs: Level3) -> Bool {
    lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d
  }
}

/// Level 4 subclass.
class Level4: Level3 {
  let e: Int

  init(a: Int, b: Int, c: Int, d: Int, e: Int) {
    self.e = e
    super.init(a: a, b: b, c: c, d: d)
  }

  enum CodingKeys: String, CodingKey {
    case e
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    e = try container.decode(Int.self, forKey: .e)
    try super.init(from: container.superDecoder())
  }

  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(e, forKey: .e)
    try super.encode(to: container.superEncoder())
  }

  static func == (lhs: Level4, rhs: Level4) -> Bool {
    lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e
  }
}

/// Level 5 subclass.
class Level5: Level4 {
  let f: Int

  init(a: Int, b: Int, c: Int, d: Int, e: Int, f: Int) {
    self.f = f
    super.init(a: a, b: b, c: c, d: d, e: e)
  }

  enum CodingKeys: String, CodingKey {
    case f
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    f = try container.decode(Int.self, forKey: .f)
    try super.init(from: container.superDecoder())
  }

  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(f, forKey: .f)
    try super.encode(to: container.superEncoder())
  }

  static func == (lhs: Level5, rhs: Level5) -> Bool {
    lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e && lhs.f == rhs.f
  }
}

/// Level 6 subclass (maximum tested depth).
class Level6: Level5 {
  let g: Int

  init(a: Int, b: Int, c: Int, d: Int, e: Int, f: Int, g: Int) {
    self.g = g
    super.init(a: a, b: b, c: c, d: d, e: e, f: f)
  }

  enum CodingKeys: String, CodingKey {
    case g
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    g = try container.decode(Int.self, forKey: .g)
    try super.init(from: container.superDecoder())
  }

  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(g, forKey: .g)
    try super.encode(to: container.superEncoder())
  }

  static func == (lhs: Level6, rhs: Level6) -> Bool {
    lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d &&
    lhs.e == rhs.e && lhs.f == rhs.f && lhs.g == rhs.g
  }
}

// MARK: - Shared Encoder Inheritance

/// A base class for shared encoder testing.
class SharedEncoderBase: Codable, Equatable {
  let baseValue: String

  init(baseValue: String) {
    self.baseValue = baseValue
  }

  enum CodingKeys: String, CodingKey {
    case baseValue
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    baseValue = try container.decode(String.self, forKey: .baseValue)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(baseValue, forKey: .baseValue)
  }

  static func == (lhs: SharedEncoderBase, rhs: SharedEncoderBase) -> Bool {
    lhs.baseValue == rhs.baseValue
  }
}

/// A subclass that shares the encoder with its parent.
final class SharedEncoderChild: SharedEncoderBase {
  let childValue: Int

  init(baseValue: String, childValue: Int) {
    self.childValue = childValue
    super.init(baseValue: baseValue)
  }

  enum ChildCodingKeys: String, CodingKey {
    case childValue
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: ChildCodingKeys.self)
    childValue = try container.decode(Int.self, forKey: .childValue)
    try super.init(from: decoder)
  }

  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: ChildCodingKeys.self)
    try container.encode(childValue, forKey: .childValue)
    try super.encode(to: encoder)
  }

  static func == (lhs: SharedEncoderChild, rhs: SharedEncoderChild) -> Bool {
    lhs.baseValue == rhs.baseValue && lhs.childValue == rhs.childValue
  }
}

// MARK: - Nested Container Types

/// A type that explicitly uses nested keyed containers.
struct NestedKeyedContainer: Codable, Equatable {
  let outerValue: String
  let innerValue: Int

  enum OuterKeys: String, CodingKey {
    case outerValue
    case inner
  }

  enum InnerKeys: String, CodingKey {
    case innerValue
  }

  init(outerValue: String, innerValue: Int) {
    self.outerValue = outerValue
    self.innerValue = innerValue
  }

  init(from decoder: Decoder) throws {
    let outer = try decoder.container(keyedBy: OuterKeys.self)
    outerValue = try outer.decode(String.self, forKey: .outerValue)
    let inner = try outer.nestedContainer(keyedBy: InnerKeys.self, forKey: .inner)
    innerValue = try inner.decode(Int.self, forKey: .innerValue)
  }

  func encode(to encoder: Encoder) throws {
    var outer = encoder.container(keyedBy: OuterKeys.self)
    try outer.encode(outerValue, forKey: .outerValue)
    var inner = outer.nestedContainer(keyedBy: InnerKeys.self, forKey: .inner)
    try inner.encode(innerValue, forKey: .innerValue)
  }
}

/// A type that uses nested unkeyed container inside keyed.
struct NestedUnkeyedInKeyed: Codable, Equatable {
  let name: String
  let values: [Int]

  enum CodingKeys: String, CodingKey {
    case name
    case values
  }

  init(name: String, values: [Int]) {
    self.name = name
    self.values = values
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    var nested = try container.nestedUnkeyedContainer(forKey: .values)
    var items: [Int] = []
    while !nested.isAtEnd {
      items.append(try nested.decode(Int.self))
    }
    values = items
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    var nested = container.nestedUnkeyedContainer(forKey: .values)
    for value in values {
      try nested.encode(value)
    }
  }
}

/// A type that uses nested keyed container inside unkeyed.
struct NestedKeyedInUnkeyed: Codable, Equatable {
  let items: [(key: String, value: Int)]

  init(items: [(key: String, value: Int)]) {
    self.items = items
  }

  enum ItemKeys: String, CodingKey {
    case key
    case value
  }

  init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    var items: [(key: String, value: Int)] = []
    while !container.isAtEnd {
      let nested = try container.nestedContainer(keyedBy: ItemKeys.self)
      let key = try nested.decode(String.self, forKey: .key)
      let value = try nested.decode(Int.self, forKey: .value)
      items.append((key: key, value: value))
    }
    self.items = items
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.unkeyedContainer()
    for item in items {
      var nested = container.nestedContainer(keyedBy: ItemKeys.self)
      try nested.encode(item.key, forKey: .key)
      try nested.encode(item.value, forKey: .value)
    }
  }

  static func == (lhs: NestedKeyedInUnkeyed, rhs: NestedKeyedInUnkeyed) -> Bool {
    guard lhs.items.count == rhs.items.count else { return false }
    for (l, r) in zip(lhs.items, rhs.items) {
      if l.key != r.key || l.value != r.value { return false }
    }
    return true
  }
}

// MARK: - Custom Coding Key Types

/// A coding key that supports both string and integer values.
struct FlexibleCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int?

  init(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }

  init(_ string: String) {
    self.init(stringValue: string)
  }

  init(_ int: Int) {
    self.init(intValue: int)
  }
}
