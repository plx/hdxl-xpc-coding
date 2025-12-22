// Tests/XPCCodingTests/Suites/NestedContainerTests.swift
// Comprehensive tests for nested container operations
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
@testable import XPCCoding

// MARK: - Helper Types

// MARK: Deep Nesting (Depth 3-5)

/// A type with 3 levels of nested keyed containers.
struct Depth3: Codable, Equatable {
  let outer: String
  let middleValue: Int
  let innerValue: Bool

  enum OuterKeys: String, CodingKey {
    case outer
    case middle
  }

  enum MiddleKeys: String, CodingKey {
    case middleValue
    case inner
  }

  enum InnerKeys: String, CodingKey {
    case innerValue
  }

  init(outer: String, middleValue: Int, innerValue: Bool) {
    self.outer = outer
    self.middleValue = middleValue
    self.innerValue = innerValue
  }

  init(from decoder: Decoder) throws {
    let outerContainer = try decoder.container(keyedBy: OuterKeys.self)
    outer = try outerContainer.decode(String.self, forKey: .outer)

    let middleContainer = try outerContainer.nestedContainer(
      keyedBy: MiddleKeys.self,
      forKey: .middle
    )
    middleValue = try middleContainer.decode(Int.self, forKey: .middleValue)

    let innerContainer = try middleContainer.nestedContainer(
      keyedBy: InnerKeys.self,
      forKey: .inner
    )
    innerValue = try innerContainer.decode(Bool.self, forKey: .innerValue)
  }

  func encode(to encoder: Encoder) throws {
    var outerContainer = encoder.container(keyedBy: OuterKeys.self)
    try outerContainer.encode(outer, forKey: .outer)

    var middleContainer = outerContainer.nestedContainer(
      keyedBy: MiddleKeys.self,
      forKey: .middle
    )
    try middleContainer.encode(middleValue, forKey: .middleValue)

    var innerContainer = middleContainer.nestedContainer(
      keyedBy: InnerKeys.self,
      forKey: .inner
    )
    try innerContainer.encode(innerValue, forKey: .innerValue)
  }
}

/// A type with 5 levels of nested keyed containers.
struct Depth5: Codable, Equatable {
  let level1: String
  let level2: Int
  let level3: Double
  let level4: Bool
  let level5: String

  enum L1Keys: String, CodingKey { case level1, l2 }
  enum L2Keys: String, CodingKey { case level2, l3 }
  enum L3Keys: String, CodingKey { case level3, l4 }
  enum L4Keys: String, CodingKey { case level4, l5 }
  enum L5Keys: String, CodingKey { case level5 }

  init(level1: String, level2: Int, level3: Double, level4: Bool, level5: String) {
    self.level1 = level1
    self.level2 = level2
    self.level3 = level3
    self.level4 = level4
    self.level5 = level5
  }

  init(from decoder: Decoder) throws {
    let c1 = try decoder.container(keyedBy: L1Keys.self)
    level1 = try c1.decode(String.self, forKey: .level1)

    let c2 = try c1.nestedContainer(keyedBy: L2Keys.self, forKey: .l2)
    level2 = try c2.decode(Int.self, forKey: .level2)

    let c3 = try c2.nestedContainer(keyedBy: L3Keys.self, forKey: .l3)
    level3 = try c3.decode(Double.self, forKey: .level3)

    let c4 = try c3.nestedContainer(keyedBy: L4Keys.self, forKey: .l4)
    level4 = try c4.decode(Bool.self, forKey: .level4)

    let c5 = try c4.nestedContainer(keyedBy: L5Keys.self, forKey: .l5)
    level5 = try c5.decode(String.self, forKey: .level5)
  }

  func encode(to encoder: Encoder) throws {
    var c1 = encoder.container(keyedBy: L1Keys.self)
    try c1.encode(level1, forKey: .level1)

    var c2 = c1.nestedContainer(keyedBy: L2Keys.self, forKey: .l2)
    try c2.encode(level2, forKey: .level2)

    var c3 = c2.nestedContainer(keyedBy: L3Keys.self, forKey: .l3)
    try c3.encode(level3, forKey: .level3)

    var c4 = c3.nestedContainer(keyedBy: L4Keys.self, forKey: .l4)
    try c4.encode(level4, forKey: .level4)

    var c5 = c4.nestedContainer(keyedBy: L5Keys.self, forKey: .l5)
    try c5.encode(level5, forKey: .level5)
  }
}

// MARK: Unkeyed in Unkeyed

/// A type that explicitly nests unkeyed containers within unkeyed containers.
struct NestedArrays: Codable, Equatable {
  let matrix: [[Int]]

  init(matrix: [[Int]]) {
    self.matrix = matrix
  }

  init(from decoder: Decoder) throws {
    var outerContainer = try decoder.unkeyedContainer()
    var result: [[Int]] = []

    while !outerContainer.isAtEnd {
      var innerContainer = try outerContainer.nestedUnkeyedContainer()
      var row: [Int] = []

      while !innerContainer.isAtEnd {
        row.append(try innerContainer.decode(Int.self))
      }
      result.append(row)
    }

    matrix = result
  }

  func encode(to encoder: Encoder) throws {
    var outerContainer = encoder.unkeyedContainer()

    for row in matrix {
      var innerContainer = outerContainer.nestedUnkeyedContainer()
      for value in row {
        try innerContainer.encode(value)
      }
    }
  }
}

// MARK: Alternating Pattern (Depth 6)

/// A type with alternating keyed/unkeyed nesting pattern.
/// Structure: { "a": [ { "b": [ { "c": 42 } ] } ] }
struct AlternatingNested: Codable, Equatable {
  let value: Int

  enum Level1Keys: String, CodingKey { case a }
  enum Level3Keys: String, CodingKey { case b }
  enum Level5Keys: String, CodingKey { case c }

  init(value: Int) {
    self.value = value
  }

  init(from decoder: Decoder) throws {
    // Level 1: Keyed
    let l1 = try decoder.container(keyedBy: Level1Keys.self)

    // Level 2: Unkeyed
    var l2 = try l1.nestedUnkeyedContainer(forKey: .a)

    // Level 3: Keyed
    let l3 = try l2.nestedContainer(keyedBy: Level3Keys.self)

    // Level 4: Unkeyed
    var l4 = try l3.nestedUnkeyedContainer(forKey: .b)

    // Level 5: Keyed
    let l5 = try l4.nestedContainer(keyedBy: Level5Keys.self)

    // Level 6: Value
    value = try l5.decode(Int.self, forKey: .c)
  }

  func encode(to encoder: Encoder) throws {
    // Level 1: Keyed
    var l1 = encoder.container(keyedBy: Level1Keys.self)

    // Level 2: Unkeyed
    var l2 = l1.nestedUnkeyedContainer(forKey: .a)

    // Level 3: Keyed
    var l3 = l2.nestedContainer(keyedBy: Level3Keys.self)

    // Level 4: Unkeyed
    var l4 = l3.nestedUnkeyedContainer(forKey: .b)

    // Level 5: Keyed
    var l5 = l4.nestedContainer(keyedBy: Level5Keys.self)

    // Level 6: Value
    try l5.encode(value, forKey: .c)
  }
}

// MARK: Wide Nesting

/// A type with many keys, each containing a nested container.
struct WideNested: Codable, Equatable {
  let values: [String: Int]

  init(values: [String: Int]) {
    self.values = values
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
    var result: [String: Int] = [:]

    for key in container.allKeys {
      let nested = try container.nestedContainer(
        keyedBy: FlexibleCodingKey.self,
        forKey: key
      )
      let valueKey = FlexibleCodingKey("value")
      result[key.stringValue] = try nested.decode(Int.self, forKey: valueKey)
    }

    values = result
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: FlexibleCodingKey.self)

    for (key, value) in values.sorted(by: { $0.key < $1.key }) {
      var nested = container.nestedContainer(
        keyedBy: FlexibleCodingKey.self,
        forKey: FlexibleCodingKey(key)
      )
      try nested.encode(value, forKey: FlexibleCodingKey("value"))
    }
  }
}

// MARK: Empty Nested Containers

/// A type with an empty nested keyed container.
struct EmptyNestedKeyed: Codable, Equatable {
  let name: String

  enum CodingKeys: String, CodingKey {
    case name
    case empty
  }

  enum EmptyKeys: CodingKey {}

  init(name: String) {
    self.name = name
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    // Access but don't decode anything from empty nested container
    _ = try container.nestedContainer(keyedBy: EmptyKeys.self, forKey: .empty)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    // Create empty nested container
    _ = container.nestedContainer(keyedBy: EmptyKeys.self, forKey: .empty)
  }
}

/// A type with an empty nested unkeyed container in a keyed container.
struct EmptyNestedUnkeyedInKeyed: Codable, Equatable {
  let id: Int

  enum CodingKeys: String, CodingKey {
    case id
    case emptyArray
  }

  init(id: Int) {
    self.id = id
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(Int.self, forKey: .id)
    // Access but don't decode anything from empty nested container
    let nested = try container.nestedUnkeyedContainer(forKey: .emptyArray)
    #expect(nested.isAtEnd)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    // Create empty nested unkeyed container
    _ = container.nestedUnkeyedContainer(forKey: .emptyArray)
  }
}

/// A type with an empty nested keyed container in an unkeyed container.
struct EmptyNestedKeyedInUnkeyed: Codable, Equatable {
  let count: Int

  enum EmptyKeys: CodingKey {}

  init(count: Int) {
    self.count = count
  }

  init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    count = try container.decode(Int.self)
    // Access but don't decode anything from empty nested container
    _ = try container.nestedContainer(keyedBy: EmptyKeys.self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(count)
    // Create empty nested keyed container
    _ = container.nestedContainer(keyedBy: EmptyKeys.self)
  }
}

// MARK: - Test Suite

@Suite("Nested Containers", .tags(.nested, .containers))
struct NestedContainerTests {

  // MARK: - Keyed in Keyed (Depth 2)

  @Test("Nested keyed container in keyed (depth 2)", .tags(.keyed, .roundTrip))
  func nestedKeyedInKeyedDepth2() throws {
    let value = NestedKeyedContainer(outerValue: "outer", innerValue: 42)
    try verifyRoundTrip(of: value)
  }

  @Test("Multiple nested keyed containers at same level", .tags(.keyed, .roundTrip))
  func multipleNestedKeyedContainers() throws {
    struct MultiNested: Codable, Equatable {
      let first: Int
      let second: String
      let third: Bool

      enum OuterKeys: String, CodingKey {
        case nest1
        case nest2
        case nest3
      }

      enum Nest1Keys: String, CodingKey { case first }
      enum Nest2Keys: String, CodingKey { case second }
      enum Nest3Keys: String, CodingKey { case third }

      init(first: Int, second: String, third: Bool) {
        self.first = first
        self.second = second
        self.third = third
      }

      init(from decoder: Decoder) throws {
        let outer = try decoder.container(keyedBy: OuterKeys.self)
        let n1 = try outer.nestedContainer(keyedBy: Nest1Keys.self, forKey: .nest1)
        first = try n1.decode(Int.self, forKey: .first)
        let n2 = try outer.nestedContainer(keyedBy: Nest2Keys.self, forKey: .nest2)
        second = try n2.decode(String.self, forKey: .second)
        let n3 = try outer.nestedContainer(keyedBy: Nest3Keys.self, forKey: .nest3)
        third = try n3.decode(Bool.self, forKey: .third)
      }

      func encode(to encoder: Encoder) throws {
        var outer = encoder.container(keyedBy: OuterKeys.self)
        var n1 = outer.nestedContainer(keyedBy: Nest1Keys.self, forKey: .nest1)
        try n1.encode(first, forKey: .first)
        var n2 = outer.nestedContainer(keyedBy: Nest2Keys.self, forKey: .nest2)
        try n2.encode(second, forKey: .second)
        var n3 = outer.nestedContainer(keyedBy: Nest3Keys.self, forKey: .nest3)
        try n3.encode(third, forKey: .third)
      }
    }

    let value = MultiNested(first: 100, second: "test", third: true)
    try verifyRoundTrip(of: value)
  }

  // MARK: - Keyed in Keyed (Depth 3-5)

  @Test("Nested keyed container in keyed (depth 3)", .tags(.keyed, .roundTrip))
  func nestedKeyedInKeyedDepth3() throws {
    let value = Depth3(outer: "level1", middleValue: 99, innerValue: false)
    try verifyRoundTrip(of: value)
  }

  @Test("Nested keyed container in keyed (depth 5)", .tags(.keyed, .roundTrip))
  func nestedKeyedInKeyedDepth5() throws {
    let value = Depth5(
      level1: "first",
      level2: 42,
      level3: 3.14159,
      level4: true,
      level5: "last"
    )
    try verifyRoundTrip(of: value)
  }

  @Test("Deep nesting with mixed value types", .tags(.keyed, .roundTrip))
  func deepNestingMixedTypes() throws {
    struct DeepMixed: Codable, Equatable {
      let strings: [String]
      let numbers: [Int]
      let flag: Bool

      enum L1Keys: String, CodingKey { case data }
      enum L2Keys: String, CodingKey { case strings, nested }
      enum L3Keys: String, CodingKey { case numbers, final }
      enum L4Keys: String, CodingKey { case flag }

      init(strings: [String], numbers: [Int], flag: Bool) {
        self.strings = strings
        self.numbers = numbers
        self.flag = flag
      }

      init(from decoder: Decoder) throws {
        let l1 = try decoder.container(keyedBy: L1Keys.self)
        let l2 = try l1.nestedContainer(keyedBy: L2Keys.self, forKey: .data)
        strings = try l2.decode([String].self, forKey: .strings)
        let l3 = try l2.nestedContainer(keyedBy: L3Keys.self, forKey: .nested)
        numbers = try l3.decode([Int].self, forKey: .numbers)
        let l4 = try l3.nestedContainer(keyedBy: L4Keys.self, forKey: .final)
        flag = try l4.decode(Bool.self, forKey: .flag)
      }

      func encode(to encoder: Encoder) throws {
        var l1 = encoder.container(keyedBy: L1Keys.self)
        var l2 = l1.nestedContainer(keyedBy: L2Keys.self, forKey: .data)
        try l2.encode(strings, forKey: .strings)
        var l3 = l2.nestedContainer(keyedBy: L3Keys.self, forKey: .nested)
        try l3.encode(numbers, forKey: .numbers)
        var l4 = l3.nestedContainer(keyedBy: L4Keys.self, forKey: .final)
        try l4.encode(flag, forKey: .flag)
      }
    }

    let value = DeepMixed(
      strings: ["a", "b", "c"],
      numbers: [1, 2, 3, 4, 5],
      flag: false
    )
    try verifyRoundTrip(of: value)
  }

  // MARK: - Unkeyed in Keyed

  @Test("Nested unkeyed container in keyed", .tags(.keyed, .unkeyed, .roundTrip))
  func nestedUnkeyedInKeyed() throws {
    let value = NestedUnkeyedInKeyed(name: "test", values: [1, 2, 3, 4, 5])
    try verifyRoundTrip(of: value)
  }

  @Test("Empty nested unkeyed in keyed", .tags(.keyed, .unkeyed, .roundTrip))
  func emptyNestedUnkeyedInKeyed() throws {
    let value = NestedUnkeyedInKeyed(name: "empty", values: [])
    try verifyRoundTrip(of: value)
  }

  @Test("Multiple nested unkeyed containers in keyed", .tags(.keyed, .unkeyed, .roundTrip))
  func multipleNestedUnkeyedInKeyed() throws {
    struct MultiArrays: Codable, Equatable {
      let integers: [Int]
      let strings: [String]
      let doubles: [Double]

      enum CodingKeys: String, CodingKey {
        case integers
        case strings
        case doubles
      }

      init(integers: [Int], strings: [String], doubles: [Double]) {
        self.integers = integers
        self.strings = strings
        self.doubles = doubles
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        var intContainer = try container.nestedUnkeyedContainer(forKey: .integers)
        var ints: [Int] = []
        while !intContainer.isAtEnd {
          ints.append(try intContainer.decode(Int.self))
        }
        integers = ints

        var strContainer = try container.nestedUnkeyedContainer(forKey: .strings)
        var strs: [String] = []
        while !strContainer.isAtEnd {
          strs.append(try strContainer.decode(String.self))
        }
        strings = strs

        var dblContainer = try container.nestedUnkeyedContainer(forKey: .doubles)
        var dbls: [Double] = []
        while !dblContainer.isAtEnd {
          dbls.append(try dblContainer.decode(Double.self))
        }
        doubles = dbls
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        var intContainer = container.nestedUnkeyedContainer(forKey: .integers)
        for int in integers {
          try intContainer.encode(int)
        }

        var strContainer = container.nestedUnkeyedContainer(forKey: .strings)
        for str in strings {
          try strContainer.encode(str)
        }

        var dblContainer = container.nestedUnkeyedContainer(forKey: .doubles)
        for dbl in doubles {
          try dblContainer.encode(dbl)
        }
      }
    }

    let value = MultiArrays(
      integers: [10, 20, 30],
      strings: ["foo", "bar", "baz"],
      doubles: [1.1, 2.2, 3.3]
    )
    try verifyRoundTrip(of: value)
  }

  // MARK: - Keyed in Unkeyed

  @Test("Nested keyed container in unkeyed", .tags(.keyed, .unkeyed, .roundTrip))
  func nestedKeyedInUnkeyed() throws {
    let value = NestedKeyedInUnkeyed(items: [
      (key: "first", value: 1),
      (key: "second", value: 2),
      (key: "third", value: 3)
    ])
    try verifyRoundTrip(of: value)
  }

  @Test("Empty nested keyed in unkeyed", .tags(.keyed, .unkeyed, .roundTrip))
  func emptyNestedKeyedInUnkeyed() throws {
    let value = NestedKeyedInUnkeyed(items: [])
    try verifyRoundTrip(of: value)
  }

  @Test("Complex nested keyed in unkeyed", .tags(.keyed, .unkeyed, .roundTrip))
  func complexNestedKeyedInUnkeyed() throws {
    struct Record: Codable, Equatable {
      let id: Int
      let name: String
      let active: Bool

      enum RecordKeys: String, CodingKey {
        case id, name, active
      }

      init(id: Int, name: String, active: Bool) {
        self.id = id
        self.name = name
        self.active = active
      }
    }

    struct RecordList: Codable, Equatable {
      let records: [Record]

      init(records: [Record]) {
        self.records = records
      }

      init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Record] = []

        while !container.isAtEnd {
          let nested = try container.nestedContainer(keyedBy: Record.RecordKeys.self)
          let id = try nested.decode(Int.self, forKey: .id)
          let name = try nested.decode(String.self, forKey: .name)
          let active = try nested.decode(Bool.self, forKey: .active)
          result.append(Record(id: id, name: name, active: active))
        }

        records = result
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        for record in records {
          var nested = container.nestedContainer(keyedBy: Record.RecordKeys.self)
          try nested.encode(record.id, forKey: .id)
          try nested.encode(record.name, forKey: .name)
          try nested.encode(record.active, forKey: .active)
        }
      }
    }

    let value = RecordList(records: [
      Record(id: 1, name: "Alice", active: true),
      Record(id: 2, name: "Bob", active: false),
      Record(id: 3, name: "Charlie", active: true)
    ])
    try verifyRoundTrip(of: value)
  }

  // MARK: - Unkeyed in Unkeyed

  @Test("Nested unkeyed container in unkeyed", .tags(.unkeyed, .roundTrip))
  func nestedUnkeyedInUnkeyed() throws {
    let value = NestedArrays(matrix: [
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9]
    ])
    try verifyRoundTrip(of: value)
  }

  @Test("Empty nested unkeyed in unkeyed", .tags(.unkeyed, .roundTrip))
  func emptyNestedUnkeyedInUnkeyed() throws {
    let value = NestedArrays(matrix: [])
    try verifyRoundTrip(of: value)
  }

  @Test("Nested unkeyed with empty inner arrays", .tags(.unkeyed, .roundTrip))
  func nestedUnkeyedWithEmptyInner() throws {
    let value = NestedArrays(matrix: [[], [], []])
    try verifyRoundTrip(of: value)
  }

  @Test("Nested unkeyed with mixed sizes", .tags(.unkeyed, .roundTrip))
  func nestedUnkeyedMixedSizes() throws {
    let value = NestedArrays(matrix: [
      [1],
      [2, 3],
      [4, 5, 6],
      [7, 8, 9, 10]
    ])
    try verifyRoundTrip(of: value)
  }

  @Test("Deeply nested unkeyed (3D array)", .tags(.unkeyed, .roundTrip))
  func deeplyNestedUnkeyed3D() throws {
    struct Array3D: Codable, Equatable {
      let cube: [[[Int]]]

      init(cube: [[[Int]]]) {
        self.cube = cube
      }

      init(from decoder: Decoder) throws {
        var l1 = try decoder.unkeyedContainer()
        var result: [[[Int]]] = []

        while !l1.isAtEnd {
          var l2 = try l1.nestedUnkeyedContainer()
          var layer: [[Int]] = []

          while !l2.isAtEnd {
            var l3 = try l2.nestedUnkeyedContainer()
            var row: [Int] = []

            while !l3.isAtEnd {
              row.append(try l3.decode(Int.self))
            }
            layer.append(row)
          }
          result.append(layer)
        }

        cube = result
      }

      func encode(to encoder: Encoder) throws {
        var l1 = encoder.unkeyedContainer()

        for layer in cube {
          var l2 = l1.nestedUnkeyedContainer()
          for row in layer {
            var l3 = l2.nestedUnkeyedContainer()
            for value in row {
              try l3.encode(value)
            }
          }
        }
      }
    }

    let value = Array3D(cube: [
      [[1, 2], [3, 4]],
      [[5, 6], [7, 8]]
    ])
    try verifyRoundTrip(of: value)
  }

  // MARK: - Alternating Pattern (Depth 6)

  @Test("Alternating keyed/unkeyed nesting (depth 6)", .tags(.keyed, .unkeyed, .roundTrip))
  func alternatingKeyedUnkeyedDepth6() throws {
    let value = AlternatingNested(value: 42)
    try verifyRoundTrip(of: value)
  }

  @Test("Alternating with multiple values", .tags(.keyed, .unkeyed, .roundTrip))
  func alternatingMultipleValues() throws {
    struct AlternatingMulti: Codable, Equatable {
      let values: [Int]

      enum L1Keys: String, CodingKey { case data }
      enum L3Keys: String, CodingKey { case items }

      init(values: [Int]) {
        self.values = values
      }

      init(from decoder: Decoder) throws {
        let l1 = try decoder.container(keyedBy: L1Keys.self)
        var l2 = try l1.nestedUnkeyedContainer(forKey: .data)
        var result: [Int] = []

        while !l2.isAtEnd {
          let l3 = try l2.nestedContainer(keyedBy: L3Keys.self)
          var l4 = try l3.nestedUnkeyedContainer(forKey: .items)

          while !l4.isAtEnd {
            result.append(try l4.decode(Int.self))
          }
        }

        values = result
      }

      func encode(to encoder: Encoder) throws {
        var l1 = encoder.container(keyedBy: L1Keys.self)
        var l2 = l1.nestedUnkeyedContainer(forKey: .data)

        // Group values in chunks of 3
        let chunks = stride(from: 0, to: values.count, by: 3).map {
          Array(values[$0..<min($0 + 3, values.count)])
        }

        for chunk in chunks {
          var l3 = l2.nestedContainer(keyedBy: L3Keys.self)
          var l4 = l3.nestedUnkeyedContainer(forKey: .items)

          for value in chunk {
            try l4.encode(value)
          }
        }
      }
    }

    let value = AlternatingMulti(values: [1, 2, 3, 4, 5, 6, 7, 8, 9])
    try verifyRoundTrip(of: value)
  }

  // MARK: - Wide Nesting

  @Test("Wide nesting with many keys", .tags(.keyed, .roundTrip))
  func wideNestingManyKeys() throws {
    var values: [String: Int] = [:]
    for i in 0..<20 {
      values["key\(i)"] = i * 10
    }

    let value = WideNested(values: values)
    try verifyRoundTrip(of: value)
  }

  @Test("Wide nesting single key", .tags(.keyed, .roundTrip))
  func wideNestingSingleKey() throws {
    let value = WideNested(values: ["single": 100])
    try verifyRoundTrip(of: value)
  }

  @Test("Wide nesting empty", .tags(.keyed, .roundTrip))
  func wideNestingEmpty() throws {
    let value = WideNested(values: [:])
    try verifyRoundTrip(of: value)
  }

  // MARK: - Empty Nested Containers

  @Test("Empty nested keyed container", .tags(.keyed, .roundTrip))
  func emptyNestedKeyedContainer() throws {
    let value = EmptyNestedKeyed(name: "test")
    try verifyRoundTrip(of: value)
  }

  @Test("Empty nested unkeyed container in keyed", .tags(.keyed, .unkeyed, .roundTrip))
  func emptyNestedUnkeyedContainerInKeyed() throws {
    let value = EmptyNestedUnkeyedInKeyed(id: 42)
    try verifyRoundTrip(of: value)
  }

  @Test("Empty nested keyed container in unkeyed", .tags(.keyed, .unkeyed, .roundTrip))
  func emptyNestedKeyedContainerInUnkeyed() throws {
    let value = EmptyNestedKeyedInUnkeyed(count: 99)
    try verifyRoundTrip(of: value)
  }

  @Test("Mixed empty and non-empty nested containers", .tags(.keyed, .unkeyed, .roundTrip))
  func mixedEmptyNonEmptyNested() throws {
    struct MixedNested: Codable, Equatable {
      let nonEmpty: [Int]
      let id: String

      enum CodingKeys: String, CodingKey {
        case nonEmpty
        case empty1
        case id
        case empty2
      }

      enum EmptyKeys: CodingKey {}

      init(nonEmpty: [Int], id: String) {
        self.nonEmpty = nonEmpty
        self.id = id
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nonEmpty = try container.decode([Int].self, forKey: .nonEmpty)
        _ = try container.nestedContainer(keyedBy: EmptyKeys.self, forKey: .empty1)
        id = try container.decode(String.self, forKey: .id)
        let empty2 = try container.nestedUnkeyedContainer(forKey: .empty2)
        #expect(empty2.isAtEnd)
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nonEmpty, forKey: .nonEmpty)
        _ = container.nestedContainer(keyedBy: EmptyKeys.self, forKey: .empty1)
        try container.encode(id, forKey: .id)
        _ = container.nestedUnkeyedContainer(forKey: .empty2)
      }
    }

    let value = MixedNested(nonEmpty: [1, 2, 3], id: "mixed")
    try verifyRoundTrip(of: value)
  }

  // MARK: - Edge Cases

  @Test("Nested container with optional values", .tags(.keyed, .optionals, .roundTrip))
  func nestedContainerWithOptionals() throws {
    struct OptionalNested: Codable, Equatable {
      let required: String
      let optional: Int?

      enum OuterKeys: String, CodingKey {
        case required
        case nested
      }

      enum InnerKeys: String, CodingKey {
        case optional
      }

      init(required: String, optional: Int?) {
        self.required = required
        self.optional = optional
      }

      init(from decoder: Decoder) throws {
        let outer = try decoder.container(keyedBy: OuterKeys.self)
        required = try outer.decode(String.self, forKey: .required)
        let inner = try outer.nestedContainer(keyedBy: InnerKeys.self, forKey: .nested)
        optional = try inner.decodeIfPresent(Int.self, forKey: .optional)
      }

      func encode(to encoder: Encoder) throws {
        var outer = encoder.container(keyedBy: OuterKeys.self)
        try outer.encode(required, forKey: .required)
        var inner = outer.nestedContainer(keyedBy: InnerKeys.self, forKey: .nested)
        try inner.encodeIfPresent(optional, forKey: .optional)
      }
    }

    let withValue = OptionalNested(required: "test", optional: 42)
    try verifyRoundTrip(of: withValue)

    let withoutValue = OptionalNested(required: "test", optional: nil)
    try verifyRoundTrip(of: withoutValue)
  }

  @Test("Single element nested arrays", .tags(.unkeyed, .roundTrip))
  func singleElementNestedArrays() throws {
    let value = NestedArrays(matrix: [[42]])
    try verifyRoundTrip(of: value)
  }

  @Test("Large nested structure", .tags(.keyed, .unkeyed, .roundTrip))
  func largeNestedStructure() throws {
    struct LargeNested: Codable, Equatable {
      let arrays: [[Int]]
      let dicts: [String: [String: Int]]

      init(arrays: [[Int]], dicts: [String: [String: Int]]) {
        self.arrays = arrays
        self.dicts = dicts
      }
    }

    let arrays = (0..<10).map { i in
      (0..<10).map { j in i * 10 + j }
    }

    let dicts: [String: [String: Int]] = [
      "group1": ["a": 1, "b": 2, "c": 3],
      "group2": ["x": 10, "y": 20, "z": 30],
      "group3": ["foo": 100, "bar": 200]
    ]

    let value = LargeNested(arrays: arrays, dicts: dicts)
    try verifyRoundTrip(of: value)
  }
}
