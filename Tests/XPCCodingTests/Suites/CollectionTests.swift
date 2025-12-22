// Tests/XPCCodingTests/Suites/CollectionTests.swift
// Comprehensive tests for collection type encoding/decoding
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Collection Types Test Suite

@Suite("Collections", .tags(.collections))
struct CollectionTests {

  // MARK: - Array of Primitives Tests

  @Test("Array of Bool with varying sizes round-trips correctly",
        arguments: [
          [Bool](),
          [true],
          [true, false, true, false, false, true, true, false, true, true],
          Array(repeating: true, count: 100)
        ])
  func boolArrayRoundTrip(value: [Bool]) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Array of Int with varying sizes round-trips correctly",
        arguments: [
          [Int](),
          [42],
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          Array(0..<100)
        ])
  func intArrayRoundTrip(value: [Int]) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Array of String with varying sizes round-trips correctly",
        arguments: [
          [String](),
          ["hello"],
          ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"],
          Array(repeating: "test", count: 100)
        ])
  func stringArrayRoundTrip(value: [String]) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Array of Double with varying sizes round-trips correctly",
        arguments: [
          [Double](),
          [3.14159],
          [1.1, 2.2, 3.3, 4.4, 5.5, 6.6, 7.7, 8.8, 9.9, 10.0],
          Array(repeating: 2.71828, count: 100)
        ])
  func doubleArrayRoundTrip(value: [Double]) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Array of Data with varying sizes round-trips correctly",
        arguments: [
          [Data](),
          [Data([0x01, 0x02, 0x03])],
          [
            Data([0x01]), Data([0x02]), Data([0x03]), Data([0x04]), Data([0x05]),
            Data([0x06]), Data([0x07]), Data([0x08]), Data([0x09]), Data([0x0A])
          ],
          Array(repeating: Data([0xFF, 0xFE, 0xFD]), count: 100)
        ])
  func dataArrayRoundTrip(value: [Data]) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Array encodes to XPC_TYPE_ARRAY", .tags(.encoding))
  func arrayEncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper([1, 2, 3, 4, 5])
    let encoded = try XPCEncoder.encode(wrapper)

    let value = xpc_dictionary_get_value(encoded, "value")!
    verifyXPCType(value, is: XPC_TYPE_ARRAY)
  }

  // MARK: - Array of Codable Structs Tests

  @Test("Array of SimpleStruct with varying sizes round-trips correctly",
        arguments: [0, 1, 5])
  func structArrayRoundTrip(count: Int) throws {
    let array = (0..<count).map { i in
      SimpleStruct(
        stringField: "item\(i)",
        intField: i,
        doubleField: Double(i) * 1.5,
        boolField: i % 2 == 0
      )
    }
    try verifyRoundTrip(of: PrimitiveWrapper(array))
  }

  // MARK: - Dictionary with String Keys Tests

  @Test("Dictionary [String: Int] with varying sizes round-trips correctly",
        arguments: [
          [String: Int](),
          ["one": 1],
          [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10
          ]
        ])
  func stringIntDictRoundTrip(value: [String: Int]) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Dictionary [String: String] with varying sizes round-trips correctly",
        arguments: [
          [String: String](),
          ["key": "value"],
          [
            "a": "alpha", "b": "beta", "c": "gamma", "d": "delta", "e": "epsilon",
            "f": "zeta", "g": "eta", "h": "theta", "i": "iota", "j": "kappa"
          ]
        ])
  func stringStringDictRoundTrip(value: [String: String]) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Dictionary [String: Double] with varying sizes round-trips correctly",
        arguments: [
          [String: Double](),
          ["pi": 3.14159],
          [
            "one": 1.1, "two": 2.2, "three": 3.3, "four": 4.4, "five": 5.5,
            "six": 6.6, "seven": 7.7, "eight": 8.8, "nine": 9.9, "ten": 10.0
          ]
        ])
  func stringDoubleDictRoundTrip(value: [String: Double]) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Dictionary [String: Bool] with varying sizes round-trips correctly",
        arguments: [
          [String: Bool](),
          ["flag": true],
          [
            "a": true, "b": false, "c": true, "d": false, "e": true,
            "f": false, "g": true, "h": false, "i": true, "j": false
          ]
        ])
  func stringBoolDictRoundTrip(value: [String: Bool]) throws {
    try verifyRoundTrip(of: PrimitiveWrapper(value))
  }

  @Test("Dictionary encodes to XPC_TYPE_DICTIONARY", .tags(.encoding))
  func dictionaryEncodesToCorrectXPCType() throws {
    let wrapper = PrimitiveWrapper(["a": 1, "b": 2, "c": 3])
    let encoded = try XPCEncoder.encode(wrapper)

    let value = xpc_dictionary_get_value(encoded, "value")!
    verifyXPCType(value, is: XPC_TYPE_DICTIONARY)
  }

  // MARK: - Dictionary with Codable Values Tests

  @Test("Dictionary [String: SimpleStruct] round-trips correctly", .tags(.roundTrip))
  func structDictRoundTrip() throws {
    let dict: [String: SimpleStruct] = [
      "first": SimpleStruct(stringField: "one", intField: 1, doubleField: 1.1, boolField: true),
      "second": SimpleStruct(stringField: "two", intField: 2, doubleField: 2.2, boolField: false),
      "third": SimpleStruct(stringField: "three", intField: 3, doubleField: 3.3, boolField: true)
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  // MARK: - Set Encoding Tests

  @Test("Set<Int> with varying sizes round-trips correctly",
        arguments: [
          Set<Int>(),
          Set([42]),
          Set([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        ])
  func intSetRoundTrip(value: Set<Int>) throws {
    // Sets encode as arrays, so order may vary - compare sorted arrays
    let wrapper = PrimitiveWrapper(value)
    let encoded = try XPCEncoder.encode(wrapper)
    let decoded = try XPCDecoder.decode(PrimitiveWrapper<Set<Int>>.self, message: encoded)

    #expect(decoded.value.sorted() == value.sorted())
  }

  @Test("Set<String> with varying sizes round-trips correctly",
        arguments: [
          Set<String>(),
          Set(["hello"]),
          Set(["one", "two", "three", "four", "five"])
        ])
  func stringSetRoundTrip(value: Set<String>) throws {
    // Sets encode as arrays, so order may vary - compare sorted arrays
    let wrapper = PrimitiveWrapper(value)
    let encoded = try XPCEncoder.encode(wrapper)
    let decoded = try XPCDecoder.decode(PrimitiveWrapper<Set<String>>.self, message: encoded)

    #expect(decoded.value.sorted() == value.sorted())
  }

  // MARK: - Nested Collections Tests

  @Test("2D array [[Int]] round-trips correctly", .tags(.roundTrip, .nested))
  func twoDimensionalArrayRoundTrip() throws {
    let array: [[Int]] = [
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9]
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(array))
  }

  @Test("3D array [[[String]]] round-trips correctly", .tags(.roundTrip, .nested))
  func threeDimensionalArrayRoundTrip() throws {
    let array: [[[String]]] = [
      [
        ["a", "b"],
        ["c", "d"]
      ],
      [
        ["e", "f"],
        ["g", "h"]
      ]
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(array))
  }

  @Test("Array of dictionaries [[String: Int]] round-trips correctly", .tags(.roundTrip, .nested))
  func arrayOfDictionariesRoundTrip() throws {
    let array: [[String: Int]] = [
      ["one": 1, "two": 2],
      ["three": 3, "four": 4],
      ["five": 5, "six": 6]
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(array))
  }

  @Test("Dictionary of arrays [String: [Int]] round-trips correctly", .tags(.roundTrip, .nested))
  func dictionaryOfArraysRoundTrip() throws {
    let dict: [String: [Int]] = [
      "first": [1, 2, 3],
      "second": [4, 5, 6],
      "third": [7, 8, 9]
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  // MARK: - Empty Collections Tests

  @Test("Empty array [Int]() round-trips correctly", .tags(.roundTrip, .edgeCases))
  func emptyArrayRoundTrip() throws {
    let empty: [Int] = []
    try verifyRoundTrip(of: PrimitiveWrapper(empty))
  }

  @Test("Empty dictionary [String: Int]() round-trips correctly", .tags(.roundTrip, .edgeCases))
  func emptyDictionaryRoundTrip() throws {
    let empty: [String: Int] = [:]
    try verifyRoundTrip(of: PrimitiveWrapper(empty))
  }

  @Test("Empty set Set<Int>() round-trips correctly", .tags(.roundTrip, .edgeCases))
  func emptySetRoundTrip() throws {
    let empty: Set<Int> = []
    let wrapper = PrimitiveWrapper(empty)
    let encoded = try XPCEncoder.encode(wrapper)
    let decoded = try XPCDecoder.decode(PrimitiveWrapper<Set<Int>>.self, message: encoded)

    #expect(decoded.value.isEmpty)
  }

  // MARK: - Large Collections Tests

  @Test("Array with 1000 elements round-trips correctly", .tags(.roundTrip, .edgeCases))
  func largeArrayRoundTrip() throws {
    let largeArray = Array(0..<1000)
    try verifyRoundTrip(of: PrimitiveWrapper(largeArray))
  }

  @Test("Dictionary with 1000 entries round-trips correctly", .tags(.roundTrip, .edgeCases))
  func largeDictionaryRoundTrip() throws {
    let largeDict = Dictionary(uniqueKeysWithValues: (0..<1000).map { ("key\($0)", $0) })
    try verifyRoundTrip(of: PrimitiveWrapper(largeDict))
  }

  // MARK: - Collection of Optionals Tests

  @Test("Array [Int?] with mixed nil/non-nil round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalIntArrayRoundTrip() throws {
    let array: [Int?] = [1, nil, 3, nil, 5, 6, nil, 8, 9, nil]
    try verifyRoundTrip(of: PrimitiveWrapper(array))
  }

  @Test("Dictionary [String: Int?] with mixed nil/non-nil round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalIntDictRoundTrip() throws {
    let dict: [String: Int?] = [
      "one": 1,
      "two": nil,
      "three": 3,
      "four": nil,
      "five": 5
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  // MARK: - Deeply Nested Collections Tests

  @Test("5-level nested array [[[[[Int]]]]] round-trips correctly", .tags(.roundTrip, .nested, .edgeCases))
  func deeplyNestedArrayRoundTrip() throws {
    let deepArray: [[[[[Int]]]]] = [
      [
        [
          [
            [1, 2, 3],
            [4, 5, 6]
          ],
          [
            [7, 8, 9],
            [10, 11, 12]
          ]
        ]
      ]
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(deepArray))
  }

  // MARK: - Mixed Collection Types via Codable Tests

  @Test("Struct with multiple collection types round-trips correctly", .tags(.roundTrip))
  func collectionHolderRoundTrip() throws {
    struct CollectionHolder: Codable, Equatable {
      let array: [Int]
      let dict: [String: String]
      let set: Set<Int>
      let nested: [[String]]

      static func == (lhs: CollectionHolder, rhs: CollectionHolder) -> Bool {
        lhs.array == rhs.array &&
        lhs.dict == rhs.dict &&
        lhs.set == rhs.set &&
        lhs.nested == rhs.nested
      }
    }

    let holder = CollectionHolder(
      array: [1, 2, 3, 4, 5],
      dict: ["a": "alpha", "b": "beta", "c": "gamma"],
      set: Set([10, 20, 30, 40, 50]),
      nested: [
        ["row1col1", "row1col2"],
        ["row2col1", "row2col2"]
      ]
    )

    try verifyRoundTrip(of: holder)
  }

  // MARK: - Special Array Content Tests

  @Test("Array with duplicate values round-trips correctly", .tags(.roundTrip))
  func arrayWithDuplicatesRoundTrip() throws {
    let array = [1, 2, 2, 3, 3, 3, 4, 4, 4, 4]
    try verifyRoundTrip(of: PrimitiveWrapper(array))
  }

  @Test("Array with extreme values round-trips correctly", .tags(.roundTrip, .edgeCases))
  func arrayWithExtremeValuesRoundTrip() throws {
    let array = [Int.min, -1, 0, 1, Int.max]
    try verifyRoundTrip(of: PrimitiveWrapper(array))
  }

  // MARK: - Special Dictionary Content Tests

  @Test("Dictionary with special characters in keys round-trips correctly", .tags(.roundTrip, .edgeCases))
  func dictionaryWithSpecialKeysRoundTrip() throws {
    let dict: [String: Int] = [
      "key with spaces": 1,
      "key-with-dashes": 2,
      "key_with_underscores": 3,
      "key.with.dots": 4,
      "key/with/slashes": 5,
      "🔑emoji-key": 6,
      "你好": 7,
      "": 8  // empty string key
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  @Test("Dictionary with unicode values round-trips correctly", .tags(.roundTrip, .edgeCases))
  func dictionaryWithUnicodeValuesRoundTrip() throws {
    let dict: [String: String] = [
      "emoji": "🎉🌍👋",
      "chinese": "你好世界",
      "japanese": "こんにちは世界",
      "korean": "안녕하세요",
      "arabic": "مرحبا بالعالم",
      "hebrew": "שלום עולם"
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  // MARK: - Nested Collection Combinations Tests

  @Test("Dictionary of dictionaries [String: [String: Int]] round-trips correctly", .tags(.roundTrip, .nested))
  func dictionaryOfDictionariesRoundTrip() throws {
    let dict: [String: [String: Int]] = [
      "first": ["a": 1, "b": 2],
      "second": ["c": 3, "d": 4],
      "third": ["e": 5, "f": 6]
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  @Test("Array of arrays of dictionaries [[String: Int]] round-trips correctly", .tags(.roundTrip, .nested))
  func arrayOfArraysOfDictionariesRoundTrip() throws {
    let row1: [[String: Int]] = [["a": 1, "b": 2], ["c": 3, "d": 4]]
    let row2: [[String: Int]] = [["e": 5, "f": 6], ["g": 7, "h": 8]]
    let array = [row1, row2]
    try verifyRoundTrip(of: PrimitiveWrapper(array))
  }

  // MARK: - Collection of Complex Structs Tests

  @Test("Array of structs with nested collections round-trips correctly", .tags(.roundTrip, .nested))
  func arrayOfStructsWithNestedCollectionsRoundTrip() throws {
    struct ComplexStruct: Codable, Equatable {
      let name: String
      let tags: [String]
      let metadata: [String: Int]
    }

    let array = [
      ComplexStruct(
        name: "first",
        tags: ["tag1", "tag2"],
        metadata: ["count": 10, "priority": 1]
      ),
      ComplexStruct(
        name: "second",
        tags: ["tag3", "tag4", "tag5"],
        metadata: ["count": 20, "priority": 2]
      )
    ]

    try verifyRoundTrip(of: PrimitiveWrapper(array))
  }

  // MARK: - Edge Case: Single Element Collections Tests

  @Test("Single element collections round-trip correctly", .tags(.roundTrip, .edgeCases))
  func singleElementCollectionsRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper([42]))
    try verifyRoundTrip(of: PrimitiveWrapper(["key": "value"]))

    let singleSet: Set<Int> = [42]
    let wrapper = PrimitiveWrapper(singleSet)
    let encoded = try XPCEncoder.encode(wrapper)
    let decoded = try XPCDecoder.decode(PrimitiveWrapper<Set<Int>>.self, message: encoded)
    #expect(decoded.value == singleSet)
  }

  // MARK: - Heterogeneous Dictionary Keys Tests

  @Test("Dictionary with various string key formats round-trips correctly", .tags(.roundTrip))
  func heterogeneousKeysRoundTrip() throws {
    let dict: [String: Int] = [
      "simple": 1,
      "UPPERCASE": 2,
      "camelCase": 3,
      "snake_case": 4,
      "kebab-case": 5,
      "dot.notation": 6,
      "123numeric": 7,
      "a": 8,
      "veryLongKeyNameThatGoesOnAndOnAndOnForQuiteAWhileToTestLongKeyHandling": 9
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  // MARK: - Array of Mixed Sizes Tests

  @Test("Nested arrays with varying sizes round-trip correctly", .tags(.roundTrip, .nested))
  func nestedArraysVaryingSizesRoundTrip() throws {
    let array: [[Int]] = [
      [],
      [1],
      [2, 3],
      [4, 5, 6],
      [7, 8, 9, 10]
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(array))
  }

  // MARK: - Collection Verification Tests

  @Test("Array preserves element order", .tags(.roundTrip))
  func arrayPreservesOrder() throws {
    let original = [5, 3, 8, 1, 9, 2, 7, 4, 6]
    let wrapper = PrimitiveWrapper(original)
    let encoded = try XPCEncoder.encode(wrapper)
    let decoded = try XPCDecoder.decode(PrimitiveWrapper<[Int]>.self, message: encoded)

    #expect(decoded.value == original)
    // Explicitly check order
    for (i, element) in decoded.value.enumerated() {
      #expect(element == original[i])
    }
  }

  @Test("Dictionary preserves all key-value pairs", .tags(.roundTrip))
  func dictionaryPreservesAllPairs() throws {
    let original: [String: Int] = [
      "a": 1, "b": 2, "c": 3, "d": 4, "e": 5,
      "f": 6, "g": 7, "h": 8, "i": 9, "j": 10
    ]
    let wrapper = PrimitiveWrapper(original)
    let encoded = try XPCEncoder.encode(wrapper)
    let decoded = try XPCDecoder.decode(PrimitiveWrapper<[String: Int]>.self, message: encoded)

    #expect(decoded.value.count == original.count)
    for (key, value) in original {
      #expect(decoded.value[key] == value)
    }
  }
}
