// Tests/XPCCodingTests/Suites/UnkeyedContainerTests.swift
// Comprehensive tests for unkeyed container operations
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Test Suite

@Suite("Unkeyed Container", .tags(.unkeyed, .containers))
struct UnkeyedContainerTests {

  // MARK: - 1. Empty Array

  @Test("Empty array encoding", .tags(.encoding, .edgeCases))
  func testEmptyArray() throws {
    struct EmptyArrayWrapper: Codable, Equatable {
      let items: [Int]
    }

    let empty = EmptyArrayWrapper(items: [])
    let encoded = try XPCEncoder.encode(empty)

    // Verify it's a dictionary with an array field
    verifyXPCType(encoded, is: XPC_TYPE_DICTIONARY)

    let arrayField = try #require("items".withCString { key in
      xpc_dictionary_get_value(encoded, key)
    })
    verifyXPCType(arrayField, is: XPC_TYPE_ARRAY)
    #expect(xpc_array_get_count(arrayField) == 0)

    // Verify round-trip
    try verifyRoundTrip(of: empty)
  }

  // MARK: - 2. Homogeneous Primitive Arrays

  struct ArraySize {
    let size: Int
    let name: String

    static let testSizes = [
      ArraySize(size: 0, name: "empty"),
      ArraySize(size: 1, name: "single"),
      ArraySize(size: 10, name: "medium"),
      ArraySize(size: 100, name: "large")
    ]
  }

  @Test("Bool array round-trip", arguments: ArraySize.testSizes)
  func testBoolArray(size: ArraySize) throws {
    let values = (0..<size.size).map { $0 % 2 == 0 }
    try verifyRoundTrip(of: values)
  }

  @Test("Int array round-trip", arguments: ArraySize.testSizes)
  func testIntArray(size: ArraySize) throws {
    let values = Array(0..<size.size)
    try verifyRoundTrip(of: values)
  }

  @Test("String array round-trip", arguments: ArraySize.testSizes)
  func testStringArray(size: ArraySize) throws {
    let values = (0..<size.size).map { "item_\($0)" }
    try verifyRoundTrip(of: values)
  }

  @Test("Double array round-trip", arguments: ArraySize.testSizes)
  func testDoubleArray(size: ArraySize) throws {
    let values = (0..<size.size).map { Double($0) * 3.14159 }
    try verifyRoundTrip(of: values)
  }

  // MARK: - 3. Array with Nil Elements

  @Test("Array with nil elements", .tags(.encoding, .optionals))
  func testArrayWithNilElements() throws {
    let values: [String?] = ["a", nil, "b", nil, "c"]

    let encoded = try XPCEncoder.encode(values)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)

    #expect(xpc_array_get_count(encoded) == 5)

    // Verify nil elements are encoded as XPC_TYPE_NULL
    #expect(xpc_get_type(xpc_array_get_value(encoded, 0)) == XPC_TYPE_STRING)
    #expect(xpc_get_type(xpc_array_get_value(encoded, 1)) == XPC_TYPE_NULL)
    #expect(xpc_get_type(xpc_array_get_value(encoded, 2)) == XPC_TYPE_STRING)
    #expect(xpc_get_type(xpc_array_get_value(encoded, 3)) == XPC_TYPE_NULL)
    #expect(xpc_get_type(xpc_array_get_value(encoded, 4)) == XPC_TYPE_STRING)

    // Verify round-trip
    let decoded = try XPCDecoder.decode([String?].self, message: encoded)
    #expect(decoded.count == values.count)
    for (index, (expected, actual)) in zip(values, decoded).enumerated() {
      #expect(expected == actual, "Mismatch at index \(index)")
    }
  }

  @Test("Array of all nil elements", .tags(.encoding, .optionals))
  func testArrayOfAllNils() throws {
    let values: [Int?] = [nil, nil, nil]

    let encoded = try XPCEncoder.encode(values)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)

    #expect(xpc_array_get_count(encoded) == 3)

    // All should be NULL
    for i in 0..<3 {
      #expect(xpc_get_type(xpc_array_get_value(encoded, i)) == XPC_TYPE_NULL)
    }

    // Verify round-trip
    let decoded = try XPCDecoder.decode([Int?].self, message: encoded)
    #expect(decoded.count == 3)
    #expect(decoded.allSatisfy { $0 == nil })
  }

  // MARK: - 4. Nested Arrays

  @Test("2D array (nested array)", .tags(.nested, .roundTrip))
  func test2DArray() throws {
    let values: [[Int]] = [
      [1, 2, 3],
      [4, 5],
      [],
      [6, 7, 8, 9]
    ]

    let encoded = try XPCEncoder.encode(values)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)

    #expect(xpc_array_get_count(encoded) == 4)

    // Verify each element is an array
    for i in 0..<4 {
      let innerArray = xpc_array_get_value(encoded, i)
      verifyXPCType(innerArray, is: XPC_TYPE_ARRAY)
    }

    // Verify round-trip
    try verifyRoundTrip(of: values)
  }

  @Test("3D array (deeply nested)", .tags(.nested, .roundTrip))
  func test3DArray() throws {
    let values: [[[String]]] = [
      [
        ["a", "b"],
        ["c"]
      ],
      [
        [],
        ["d", "e", "f"]
      ],
      []
    ]

    let encoded = try XPCEncoder.encode(values)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)

    // Verify round-trip
    try verifyRoundTrip(of: values)
  }

  // MARK: - 5. Array of Structs

  @Test("Array of structs", .tags(.encoding, .roundTrip))
  func testArrayOfStructs() throws {
    let structs = [
      SimpleStruct(stringField: "first", intField: 1, doubleField: 1.1, boolField: true),
      SimpleStruct(stringField: "second", intField: 2, doubleField: 2.2, boolField: false),
      SimpleStruct(stringField: "third", intField: 3, doubleField: 3.3, boolField: true)
    ]

    let encoded = try XPCEncoder.encode(structs)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)

    #expect(xpc_array_get_count(encoded) == 3)

    // Verify each element is a dictionary
    for i in 0..<3 {
      let element = xpc_array_get_value(encoded, i)
      verifyXPCType(element, is: XPC_TYPE_DICTIONARY)
    }

    // Verify round-trip
    try verifyRoundTrip(of: structs)
  }

  // MARK: - 6. Nested Keyed Container in Unkeyed

  @Test("Nested keyed containers in unkeyed", .tags(.nested, .keyed))
  func testNestedKeyedInUnkeyed() throws {
    let items: [(key: String, value: Int)] = [
      (key: "first", value: 100),
      (key: "second", value: 200),
      (key: "third", value: 300)
    ]

    let value = NestedKeyedInUnkeyed(items: items)

    let encoded = try XPCEncoder.encode(value)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)

    #expect(xpc_array_get_count(encoded) == 3)

    // Verify each element is a dictionary with correct keys
    for i in 0..<3 {
      let element = xpc_array_get_value(encoded, i)
      verifyXPCType(element, is: XPC_TYPE_DICTIONARY)

      // Check that "key" and "value" fields exist
      let keyField = try #require("key".withCString { key in
        xpc_dictionary_get_value(element, key)
      })
      let valueField = try #require("value".withCString { key in
        xpc_dictionary_get_value(element, key)
      })

      verifyXPCType(keyField, is: XPC_TYPE_STRING)
      verifyXPCType(valueField, is: XPC_TYPE_INT64)
    }

    // Verify round-trip
    try verifyRoundTrip(of: value)
  }

  // MARK: - 7. Count and isAtEnd Tracking

  @Test("UnkeyedDecodingContainer count and isAtEnd", .tags(.decoding))
  func testCountAndIsAtEnd() throws {
    struct CountTracker: Codable, Equatable {
      let values: [Int]
      var capturedCount: Int?
      var capturedIndices: [Int]?
      var isAtEndValues: [Bool]?

      init(values: [Int]) {
        self.values = values
        self.capturedCount = nil
        self.capturedIndices = nil
        self.isAtEndValues = nil
      }

      init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        // Capture initial count
        capturedCount = container.count

        var decodedValues: [Int] = []
        var indices: [Int] = []
        var isAtEndFlags: [Bool] = []

        // Decode all values while tracking state
        while !container.isAtEnd {
          indices.append(container.currentIndex)
          isAtEndFlags.append(container.isAtEnd)
          let value = try container.decode(Int.self)
          decodedValues.append(value)
        }

        // Final isAtEnd check
        isAtEndFlags.append(container.isAtEnd)

        self.values = decodedValues
        self.capturedIndices = indices
        self.isAtEndValues = isAtEndFlags
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for value in values {
          try container.encode(value)
        }
      }

      static func == (lhs: CountTracker, rhs: CountTracker) -> Bool {
        lhs.values == rhs.values
      }
    }

    let original = CountTracker(values: [10, 20, 30, 40, 50])
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(CountTracker.self, message: encoded)

    // Verify count was captured correctly
    #expect(decoded.capturedCount == 5)

    // Verify values decoded correctly
    #expect(decoded.values == [10, 20, 30, 40, 50])

    // Verify indices incremented correctly
    #expect(decoded.capturedIndices == [0, 1, 2, 3, 4])

    // Verify isAtEnd was false during iteration, true at end
    #expect(decoded.isAtEndValues == [false, false, false, false, false, true])
  }

  @Test("Count property for various array sizes", .tags(.decoding))
  func testCountProperty() throws {
    struct CountCapture: Codable, Equatable {
      let capturedCount: Int?

      init() {
        self.capturedCount = nil
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.unkeyedContainer()
        capturedCount = container.count
      }

      func encode(to encoder: Encoder) throws {
        _ = encoder.unkeyedContainer()
      }
    }

    // Test empty array
    let emptyEncoded = try XPCEncoder.encode([CountCapture]())
    let emptyDecoded = try XPCDecoder.decode([CountCapture].self, message: emptyEncoded)
    #expect(emptyDecoded.count == 0)

    // Test array with elements
    let array = [CountCapture(), CountCapture(), CountCapture()]
    let encoded = try XPCEncoder.encode(array)
    let decoded = try XPCDecoder.decode([CountCapture].self, message: encoded)

    #expect(decoded.count == 3)
    for item in decoded {
      #expect(item.capturedCount == 0) // Each CountCapture encodes empty container
    }
  }

  // MARK: - 8. Nested Unkeyed in Unkeyed

  @Test("Nested unkeyed containers (explicit)", .tags(.nested))
  func testNestedUnkeyedExplicit() throws {
    struct NestedUnkeyedWrapper: Codable, Equatable {
      let matrix: [[Int]]

      init(matrix: [[Int]]) {
        self.matrix = matrix
      }

      init(from decoder: Decoder) throws {
        var outerContainer = try decoder.unkeyedContainer()
        var rows: [[Int]] = []

        while !outerContainer.isAtEnd {
          var innerContainer = try outerContainer.nestedUnkeyedContainer()
          var row: [Int] = []

          while !innerContainer.isAtEnd {
            row.append(try innerContainer.decode(Int.self))
          }

          rows.append(row)
        }

        self.matrix = rows
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

    let matrix = [
      [1, 2, 3],
      [4, 5],
      [6, 7, 8, 9]
    ]

    let value = NestedUnkeyedWrapper(matrix: matrix)

    let encoded = try XPCEncoder.encode(value)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)

    #expect(xpc_array_get_count(encoded) == 3)

    // Verify round-trip
    try verifyRoundTrip(of: value)
  }

  @Test("Empty nested unkeyed containers", .tags(.nested, .edgeCases))
  func testEmptyNestedUnkeyed() throws {
    struct EmptyNestedUnkeyed: Codable, Equatable {
      let data: [[String]]

      init(data: [[String]]) {
        self.data = data
      }

      init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [[String]] = []

        while !container.isAtEnd {
          var nested = try container.nestedUnkeyedContainer()
          var row: [String] = []
          while !nested.isAtEnd {
            row.append(try nested.decode(String.self))
          }
          result.append(row)
        }

        self.data = result
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for row in data {
          var nested = container.nestedUnkeyedContainer()
          for value in row {
            try nested.encode(value)
          }
        }
      }
    }

    // Mix of empty and non-empty rows
    let value = EmptyNestedUnkeyed(data: [
      ["a", "b"],
      [],
      ["c"],
      []
    ])

    try verifyRoundTrip(of: value)
  }

  // MARK: - 9. SuperEncoder in Unkeyed Container

  @Test("SuperEncoder in unkeyed container", .tags(.inheritance))
  func testSuperEncoderInUnkeyed() throws {
    struct UnkeyedSuperEncoder: Codable, Equatable {
      let values: [String]

      init(values: [String]) {
        self.values = values
      }

      init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var items: [String] = []

        while !container.isAtEnd {
          // Use superDecoder to decode each element
          let superDecoder = try container.superDecoder()
          let value = try String(from: superDecoder)
          items.append(value)
        }

        self.values = items
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        for value in values {
          let superEncoder = container.superEncoder()
          try value.encode(to: superEncoder)
        }
      }
    }

    let value = UnkeyedSuperEncoder(values: ["alpha", "beta", "gamma"])
    try verifyRoundTrip(of: value)
  }

  // MARK: - 10. Mixed Types in Array

  @Test("Array with different Codable types", .tags(.encoding))
  func testMixedCodableTypes() throws {
    // Use an enum to represent different types
    enum MixedValue: Codable, Equatable {
      case integer(Int)
      case string(String)
      case boolean(Bool)
      case double(Double)

      init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
          self = .integer(intValue)
        } else if let stringValue = try? container.decode(String.self) {
          self = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
          self = .boolean(boolValue)
        } else if let doubleValue = try? container.decode(Double.self) {
          self = .double(doubleValue)
        } else {
          throw DecodingError.typeMismatch(
            MixedValue.self,
            DecodingError.Context(
              codingPath: decoder.codingPath,
              debugDescription: "Cannot decode MixedValue"
            )
          )
        }
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let value):
          try container.encode(value)
        case .string(let value):
          try container.encode(value)
        case .boolean(let value):
          try container.encode(value)
        case .double(let value):
          try container.encode(value)
        }
      }
    }

    let values: [MixedValue] = [
      .integer(42),
      .string("hello"),
      .boolean(true),
      .double(3.14159)
    ]

    try verifyRoundTrip(of: values)
  }

  // MARK: - 11. Large Array Performance

  @Test("Large array encoding and decoding", .tags(.roundTrip))
  func testLargeArray() throws {
    // Test with 1000 elements
    let values = Array(0..<1000)

    let encoded = try XPCEncoder.encode(values)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)
    #expect(xpc_array_get_count(encoded) == 1000)

    try verifyRoundTrip(of: values)
  }

  // MARK: - 12. Single-Value Container Wrapping Array

  @Test("ArrayWrapper using single-value container", .tags(.singleValue))
  func testArrayWrapperSingleValue() throws {
    let wrapper = ArrayWrapper(items: [1, 2, 3, 4, 5])

    let encoded = try XPCEncoder.encode(wrapper)
    // ArrayWrapper encodes as array via single-value container
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)
    #expect(xpc_array_get_count(encoded) == 5)

    try verifyRoundTrip(of: wrapper)
  }

  @Test("Empty ArrayWrapper", .tags(.singleValue, .edgeCases))
  func testEmptyArrayWrapper() throws {
    let wrapper = ArrayWrapper(items: [])

    let encoded = try XPCEncoder.encode(wrapper)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)
    #expect(xpc_array_get_count(encoded) == 0)

    try verifyRoundTrip(of: wrapper)
  }

  // MARK: - 13. CurrentIndex Verification

  @Test("CurrentIndex increments correctly", .tags(.decoding))
  func testCurrentIndexIncrement() throws {
    struct IndexTracker: Codable, Equatable {
      let data: [Int]
      var indices: [Int]?

      init(data: [Int]) {
        self.data = data
        self.indices = nil
      }

      init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [Int] = []
        var trackedIndices: [Int] = []

        while !container.isAtEnd {
          trackedIndices.append(container.currentIndex)
          values.append(try container.decode(Int.self))
        }

        self.data = values
        self.indices = trackedIndices
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for value in data {
          try container.encode(value)
        }
      }

      static func == (lhs: IndexTracker, rhs: IndexTracker) -> Bool {
        lhs.data == rhs.data
      }
    }

    let original = IndexTracker(data: [100, 200, 300])
    let encoded = try XPCEncoder.encode(original)
    let decoded = try XPCDecoder.decode(IndexTracker.self, message: encoded)

    #expect(decoded.data == [100, 200, 300])
    #expect(decoded.indices == [0, 1, 2])
  }

  // MARK: - 14. EncodeNil Explicit Call

  @Test("Explicit encodeNil calls", .tags(.encoding, .optionals))
  func testExplicitEncodeNil() throws {
    struct NilEncoder: Codable, Equatable {
      let pattern: [Bool] // true = encode value, false = encode nil

      init(pattern: [Bool]) {
        self.pattern = pattern
      }

      init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Bool] = []

        while !container.isAtEnd {
          if try container.decodeNil() {
            result.append(false)
          } else {
            _ = try container.decode(Int.self)
            result.append(true)
          }
        }

        self.pattern = result
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        for shouldEncode in pattern {
          if shouldEncode {
            try container.encode(42)
          } else {
            try container.encodeNil()
          }
        }
      }
    }

    let value = NilEncoder(pattern: [true, false, true, true, false])

    let encoded = try XPCEncoder.encode(value)
    verifyXPCType(encoded, is: XPC_TYPE_ARRAY)
    #expect(xpc_array_get_count(encoded) == 5)

    // Verify the nil pattern
    #expect(xpc_get_type(xpc_array_get_value(encoded, 0)) == XPC_TYPE_INT64)
    #expect(xpc_get_type(xpc_array_get_value(encoded, 1)) == XPC_TYPE_NULL)
    #expect(xpc_get_type(xpc_array_get_value(encoded, 2)) == XPC_TYPE_INT64)
    #expect(xpc_get_type(xpc_array_get_value(encoded, 3)) == XPC_TYPE_INT64)
    #expect(xpc_get_type(xpc_array_get_value(encoded, 4)) == XPC_TYPE_NULL)

    try verifyRoundTrip(of: value)
  }

  // MARK: - 15. DecodeNil Without Consuming

  @Test("DecodeNil returns false without consuming non-nil", .tags(.decoding, .optionals))
  func testDecodeNilNonConsuming() throws {
    struct NilChecker: Codable, Equatable {
      let value: Int
      var wasNil: Bool?

      init(value: Int) {
        self.value = value
        self.wasNil = nil
      }

      init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        // Try to decode nil - should return false and not consume
        wasNil = try container.decodeNil()

        // Now decode the actual value
        value = try container.decode(Int.self)
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(value)
      }

      static func == (lhs: NilChecker, rhs: NilChecker) -> Bool {
        lhs.value == rhs.value
      }
    }

    let original = NilChecker(value: 999)
    let encoded = try XPCEncoder.encode([original])
    let decoded = try XPCDecoder.decode([NilChecker].self, message: encoded)

    #expect(decoded.count == 1)
    #expect(decoded[0].value == 999)
    #expect(decoded[0].wasNil == false)
  }
}
