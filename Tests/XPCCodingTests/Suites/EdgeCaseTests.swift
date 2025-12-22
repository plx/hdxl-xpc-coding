// Tests/XPCCodingTests/Suites/EdgeCaseTests.swift
// Comprehensive tests for edge cases and boundary conditions
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Edge Cases Test Suite

@Suite("Edge Cases", .tags(.edgeCases))
struct EdgeCaseTests {

  // MARK: - 1. Numeric Edge Cases

  // MARK: 1.1 Integer Boundaries

  @Test("All integer types at min/max boundaries round-trip correctly", .tags(.roundTrip, .primitives))
  func integerBoundariesRoundTrip() throws {
    // Int8
    try verifyRoundTrip(of: PrimitiveWrapper(Int8.min))
    try verifyRoundTrip(of: PrimitiveWrapper(Int8.max))

    // Int16
    try verifyRoundTrip(of: PrimitiveWrapper(Int16.min))
    try verifyRoundTrip(of: PrimitiveWrapper(Int16.max))

    // Int32
    try verifyRoundTrip(of: PrimitiveWrapper(Int32.min))
    try verifyRoundTrip(of: PrimitiveWrapper(Int32.max))

    // Int64
    try verifyRoundTrip(of: PrimitiveWrapper(Int64.min))
    try verifyRoundTrip(of: PrimitiveWrapper(Int64.max))

    // Int
    try verifyRoundTrip(of: PrimitiveWrapper(Int.min))
    try verifyRoundTrip(of: PrimitiveWrapper(Int.max))

    // UInt8
    try verifyRoundTrip(of: PrimitiveWrapper(UInt8.min))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt8.max))

    // UInt16
    try verifyRoundTrip(of: PrimitiveWrapper(UInt16.min))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt16.max))

    // UInt32
    try verifyRoundTrip(of: PrimitiveWrapper(UInt32.min))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt32.max))

    // UInt64
    try verifyRoundTrip(of: PrimitiveWrapper(UInt64.min))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt64.max))

    // UInt
    try verifyRoundTrip(of: PrimitiveWrapper(UInt.min))
    try verifyRoundTrip(of: PrimitiveWrapper(UInt.max))
  }

  // MARK: 1.2 Floating Point Special Values

  @Test("Float special values round-trip correctly", .tags(.roundTrip, .primitives))
  func floatSpecialValuesRoundTrip() throws {
    // NaN
    try verifyRoundTrip(of: PrimitiveWrapper(Float.nan), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Infinity
    try verifyRoundTrip(of: PrimitiveWrapper(Float.infinity), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    try verifyRoundTrip(of: PrimitiveWrapper(-Float.infinity), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // ULP and smallest magnitude
    try verifyRoundTrip(of: PrimitiveWrapper(Float.ulpOfOne), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    try verifyRoundTrip(of: PrimitiveWrapper(Float.leastNonzeroMagnitude), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    try verifyRoundTrip(of: PrimitiveWrapper(Float.leastNormalMagnitude), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    try verifyRoundTrip(of: PrimitiveWrapper(Float.greatestFiniteMagnitude), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
  }

  @Test("Double special values round-trip correctly", .tags(.roundTrip, .primitives))
  func doubleSpecialValuesRoundTrip() throws {
    // NaN
    try verifyRoundTrip(of: PrimitiveWrapper(Double.nan), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Infinity
    try verifyRoundTrip(of: PrimitiveWrapper(Double.infinity), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    try verifyRoundTrip(of: PrimitiveWrapper(-Double.infinity), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    // Smallest and largest magnitudes
    try verifyRoundTrip(of: PrimitiveWrapper(Double.leastNonzeroMagnitude), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    try verifyRoundTrip(of: PrimitiveWrapper(Double.leastNormalMagnitude), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    try verifyRoundTrip(of: PrimitiveWrapper(Double.greatestFiniteMagnitude), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    try verifyRoundTrip(of: PrimitiveWrapper(Double.ulpOfOne), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
  }

  // MARK: 1.3 Zero Variations

  @Test("Positive and negative zero round-trip for Float", .tags(.roundTrip, .primitives))
  func floatZeroVariationsRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper(Float(0.0)), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    try verifyRoundTrip(of: PrimitiveWrapper(Float(-0.0)), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
  }

  @Test("Positive and negative zero round-trip for Double", .tags(.roundTrip, .primitives))
  func doubleZeroVariationsRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper(Double(0.0)), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })

    try verifyRoundTrip(of: PrimitiveWrapper(Double(-0.0)), areEqual: { a, b in
      floatsEqual(a.value, b.value)
    })
  }

  @Test("Zero for all integer types round-trips correctly", .tags(.roundTrip, .primitives))
  func integerZeroRoundTrip() throws {
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
  }

  // MARK: - 2. String Edge Cases

  // MARK: 2.1 Empty String

  @Test("Empty string round-trips correctly", .tags(.roundTrip, .primitives))
  func emptyStringRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper(""))
  }

  // MARK: 2.2 Unicode Strings

  @Test("Unicode emoji strings round-trip correctly", .tags(.roundTrip, .primitives))
  func unicodeEmojiStringsRoundTrip() throws {
    // Simple emoji
    try verifyRoundTrip(of: PrimitiveWrapper("Hello 🌍"))

    // Multiple emojis
    try verifyRoundTrip(of: PrimitiveWrapper("🎉🎊🎈🎁"))

    // Flag sequences
    try verifyRoundTrip(of: PrimitiveWrapper("🇺🇸🇬🇧🇯🇵🇩🇪🇫🇷"))

    // Family emoji (zero-width joiner sequences)
    try verifyRoundTrip(of: PrimitiveWrapper("\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"))

    // Skin tone modifiers
    try verifyRoundTrip(of: PrimitiveWrapper("👋🏻👋🏽👋🏿"))
  }

  @Test("Unicode RTL strings round-trip correctly", .tags(.roundTrip, .primitives))
  func unicodeRTLStringsRoundTrip() throws {
    // Arabic
    try verifyRoundTrip(of: PrimitiveWrapper("مرحبا"))

    // Hebrew
    try verifyRoundTrip(of: PrimitiveWrapper("שלום"))

    // Mixed RTL and LTR
    try verifyRoundTrip(of: PrimitiveWrapper("Hello مرحبا World"))
  }

  @Test("Unicode CJK strings round-trip correctly", .tags(.roundTrip, .primitives))
  func unicodeCJKStringsRoundTrip() throws {
    // Chinese
    try verifyRoundTrip(of: PrimitiveWrapper("你好"))

    // Japanese
    try verifyRoundTrip(of: PrimitiveWrapper("こんにちは"))

    // Korean
    try verifyRoundTrip(of: PrimitiveWrapper("안녕하세요"))
  }

  @Test("Unicode combining characters round-trip correctly", .tags(.roundTrip, .primitives))
  func unicodeCombiningCharactersRoundTrip() throws {
    // Combining diacriticals
    try verifyRoundTrip(of: PrimitiveWrapper("e\u{0301}"))  // é (e + combining acute accent)

    // Multiple combining marks
    try verifyRoundTrip(of: PrimitiveWrapper("e\u{0301}\u{0302}\u{0308}"))

    // Decomposed text
    try verifyRoundTrip(of: PrimitiveWrapper("café"))
    try verifyRoundTrip(of: PrimitiveWrapper("cafe\u{0301}"))
  }

  // MARK: 2.3 Control Characters

  @Test("Strings with embedded null bytes round-trip correctly", .tags(.roundTrip))
  func stringWithNullByteRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper("Hello\0World"))
  }

  @Test("Strings with newlines round-trip correctly", .tags(.roundTrip))
  func stringWithNewlineRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper("Line1\nLine2"))
    try verifyRoundTrip(of: PrimitiveWrapper("Line1\r\nLine2"))
  }

  @Test("Strings with tabs round-trip correctly", .tags(.roundTrip))
  func stringWithTabRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper("Tab\there"))
  }

  @Test("Strings with various control characters round-trip correctly", .tags(.roundTrip))
  func stringWithControlCharactersRoundTrip() throws {
    // Bell, backspace, form feed, vertical tab
    try verifyRoundTrip(of: PrimitiveWrapper("\u{0007}\u{0008}\u{000C}\u{000B}"))

    // Escape character
    try verifyRoundTrip(of: PrimitiveWrapper("\u{001B}"))

    // Delete character
    try verifyRoundTrip(of: PrimitiveWrapper("\u{007F}"))
  }

  @Test("String with all ASCII control characters round-trips correctly", .tags(.roundTrip))
  func stringWithAllControlCharactersRoundTrip() throws {
    // All control characters 0-31
    let controlChars = (0...31).map { Character(UnicodeScalar($0)!) }
    let controlString = String(controlChars)
    try verifyRoundTrip(of: PrimitiveWrapper(controlString))
  }

  // MARK: 2.4 Very Long String

  @Test("Very long string (100k chars) round-trips correctly", .tags(.roundTrip))
  func veryLongStringRoundTrip() throws {
    let longString = String(repeating: "x", count: 100_000)
    try verifyRoundTrip(of: PrimitiveWrapper(longString))
  }

  @Test("Very long string with unicode round-trips correctly", .tags(.roundTrip))
  func veryLongUnicodeStringRoundTrip() throws {
    let longString = String(repeating: "你好🌍", count: 10_000)
    try verifyRoundTrip(of: PrimitiveWrapper(longString))
  }

  // MARK: - 3. Data Edge Cases

  // MARK: 3.1 Empty Data

  @Test("Empty Data round-trips correctly", .tags(.roundTrip, .primitives))
  func emptyDataRoundTrip() throws {
    try verifyRoundTrip(of: PrimitiveWrapper(Data()))
  }

  // MARK: 3.2 All Byte Values

  @Test("Data with all byte values (0-255) round-trips correctly", .tags(.roundTrip))
  func dataWithAllBytesRoundTrip() throws {
    let data = Data(0...255)
    try verifyRoundTrip(of: PrimitiveWrapper(data))
  }

  // MARK: 3.3 Large Data

  @Test("Large Data (100k bytes) round-trips correctly", .tags(.roundTrip))
  func largeDataRoundTrip() throws {
    let data = Data(repeating: 0xAB, count: 100_000)
    try verifyRoundTrip(of: PrimitiveWrapper(data))
  }

  @Test("Large Data with pattern round-trips correctly", .tags(.roundTrip))
  func largeDataWithPatternRoundTrip() throws {
    var bytes: [UInt8] = []
    for i in 0..<100_000 {
      bytes.append(UInt8(i % 256))
    }
    let data = Data(bytes)
    try verifyRoundTrip(of: PrimitiveWrapper(data))
  }

  // MARK: - 4. Structure Edge Cases

  // MARK: 4.1 Deeply Nested Structures

  @Test("Deeply nested structures (15 levels) round-trip correctly", .tags(.roundTrip, .nested))
  func deeplyNestedStructuresRoundTrip() throws {
    let value = Deep15(
      value: 15,
      inner: Deep14(
        value: 14,
        inner: Deep13(
          value: 13,
          inner: Deep12(
            value: 12,
            inner: Deep11(
              value: 11,
              inner: Deep10(
                value: 10,
                inner: Deep9(
                  value: 9,
                  inner: Deep8(
                    value: 8,
                    inner: Deep7(
                      value: 7,
                      inner: Deep6(
                        value: 6,
                        inner: Deep5(
                          value: 5,
                          inner: Deep4(
                            value: 4,
                            inner: Deep3(
                              value: 3,
                              inner: Deep2(
                                value: 2,
                                inner: Deep1(value: 1)
                              )
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )

    try verifyRoundTrip(of: value)
  }

  // MARK: 4.2 Wide Structure

  @Test("Wide structure with 100 keys round-trips correctly", .tags(.roundTrip, .keyed))
  func wideStructureWith100KeysRoundTrip() throws {
    var dict: [String: Int] = [:]
    for i in 0..<100 {
      dict["key\(i)"] = i
    }

    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  // MARK: 4.3 Many Empty Nested Containers

  @Test("Many empty nested containers round-trip correctly", .tags(.roundTrip, .nested))
  func manyEmptyNestedContainersRoundTrip() throws {
    let value = EmptyContainerStruct(
      emptyDict: [:],
      emptyArray: [],
      nestedEmpty: NestedEmptyContainers(
        emptyDict: [:],
        emptyArray: [],
        doubleNested: DoubleNestedEmpty(
          emptyDict: [:],
          emptyArray: []
        )
      )
    )

    try verifyRoundTrip(of: value)
  }

  // MARK: - 5. Key Edge Cases

  // MARK: 5.1 Keys with Special Characters

  @Test("Keys with spaces round-trip correctly", .tags(.roundTrip, .keyed))
  func keysWithSpacesRoundTrip() throws {
    let value = SpecialKeyStruct1(value: 42)
    try verifyRoundTrip(of: value)
  }

  @Test("Keys with dots round-trip correctly", .tags(.roundTrip, .keyed))
  func keysWithDotsRoundTrip() throws {
    let value = SpecialKeyStruct2(value: 42)
    try verifyRoundTrip(of: value)
  }

  @Test("Keys with slashes round-trip correctly", .tags(.roundTrip, .keyed))
  func keysWithSlashesRoundTrip() throws {
    let value = SpecialKeyStruct3(value: 42)
    try verifyRoundTrip(of: value)
  }

  @Test("Keys with colons round-trip correctly", .tags(.roundTrip, .keyed))
  func keysWithColonsRoundTrip() throws {
    let value = SpecialKeyStruct4(value: 42)
    try verifyRoundTrip(of: value)
  }

  @Test("Keys with unicode round-trip correctly", .tags(.roundTrip, .keyed))
  func keysWithUnicodeRoundTrip() throws {
    let value = SpecialKeyStruct5(value: 42)
    try verifyRoundTrip(of: value)
  }

  // MARK: 5.2 Empty Key

  @Test("Empty key round-trips correctly", .tags(.roundTrip, .keyed))
  func emptyKeyRoundTrip() throws {
    let value = EmptyKeyStruct(value: 42)
    try verifyRoundTrip(of: value)
  }

  // MARK: 5.3 Numeric String Key

  @Test("Numeric string key round-trips correctly", .tags(.roundTrip, .keyed))
  func numericStringKeyRoundTrip() throws {
    let value = NumericKeyStruct(value: 42)
    try verifyRoundTrip(of: value)
  }

  // MARK: - 6. Re-encoding Stability

  @Test("Re-encoding produces identical results", .tags(.roundTrip, .encoding, .decoding))
  func reencodingStability() throws {
    let original = SimpleStruct.testValue

    // First encode-decode cycle
    let encoded1 = try XPCEncoder.encode(original)
    let decoded1 = try XPCDecoder.decode(SimpleStruct.self, message: encoded1)

    // Second encode-decode cycle
    let encoded2 = try XPCEncoder.encode(decoded1)
    let decoded2 = try XPCDecoder.decode(SimpleStruct.self, message: encoded2)

    // Verify both decoded values are equal
    #expect(decoded1 == decoded2)
  }

  @Test("Re-encoding complex nested structures produces identical results", .tags(.roundTrip, .nested))
  func reencodingComplexStructureStability() throws {
    let original = ComplexNestedStruct(
      name: "test",
      values: [1, 2, 3, 4, 5],
      mapping: ["a": 1, "b": 2, "c": 3],
      nested: NestedData(
        id: 42,
        tags: ["swift", "xpc", "testing"],
        metadata: ["version": "1.0", "author": "test"]
      )
    )

    // First encode-decode cycle
    let encoded1 = try XPCEncoder.encode(original)
    let decoded1 = try XPCDecoder.decode(ComplexNestedStruct.self, message: encoded1)

    // Second encode-decode cycle
    let encoded2 = try XPCEncoder.encode(decoded1)
    let decoded2 = try XPCDecoder.decode(ComplexNestedStruct.self, message: encoded2)

    // Third encode-decode cycle for good measure
    let encoded3 = try XPCEncoder.encode(decoded2)
    let decoded3 = try XPCDecoder.decode(ComplexNestedStruct.self, message: encoded3)

    #expect(decoded1 == decoded2)
    #expect(decoded2 == decoded3)
  }

  // MARK: - 7. Concurrent Encoding/Decoding

  @Test("Concurrent encoding and decoding operations produce correct results", .tags(.encoding, .decoding))
  func concurrentEncodingDecodingOperations() async throws {
    let values = (0..<100).map { i in
      SimpleStruct(
        stringField: "test\(i)",
        intField: i,
        doubleField: Double(i) * 3.14,
        boolField: i % 2 == 0
      )
    }

    // Encode and decode all values concurrently, verifying round-trip
    try await withThrowingTaskGroup(of: (Int, Bool).self) { group in
      for (index, value) in values.enumerated() {
        group.addTask {
          // Encode and decode within the same task to avoid Sendable issues with xpc_object_t
          let encoded = try XPCEncoder.encode(value)
          let decoded = try XPCDecoder.decode(SimpleStruct.self, message: encoded)
          let isEqual = (decoded == value)
          return (index, isEqual)
        }
      }

      // Verify all operations succeeded
      var successCount = 0
      for try await (_, isEqual) in group {
        #expect(isEqual)
        successCount += 1
      }

      // Verify we completed all tasks
      #expect(successCount == 100)
    }
  }

  @Test("Concurrent round-trip operations with complex data produce correct results", .tags(.roundTrip))
  func concurrentComplexRoundTrips() async throws {
    let complexValues = (0..<50).map { i in
      ComplexNestedStruct(
        name: "test\(i)",
        values: Array(0..<i),
        mapping: ["key\(i)": i, "double": i * 2, "triple": i * 3],
        nested: NestedData(
          id: i,
          tags: ["tag\(i)", "test", "concurrent"],
          metadata: ["index": "\(i)", "type": "test"]
        )
      )
    }

    try await withThrowingTaskGroup(of: Bool.self) { group in
      for value in complexValues {
        group.addTask {
          let encoded = try XPCEncoder.encode(value)
          let decoded = try XPCDecoder.decode(ComplexNestedStruct.self, message: encoded)
          return decoded == value
        }
      }

      // Verify all succeeded
      var successCount = 0
      for try await isEqual in group {
        #expect(isEqual)
        successCount += 1
      }

      #expect(successCount == 50)
    }
  }

  @Test("Multiple concurrent encoders do not interfere with each other", .tags(.encoding))
  func concurrentEncodersNoInterference() async throws {
    // Create different types of values to encode concurrently
    let intValues = (0..<25).map { PrimitiveWrapper($0) }
    let stringValues = (0..<25).map { PrimitiveWrapper("string\($0)") }
    let doubleValues = (0..<25).map { PrimitiveWrapper(Double($0) * 3.14) }
    let boolValues = (0..<25).map { PrimitiveWrapper($0 % 2 == 0) }

    try await withThrowingTaskGroup(of: Bool.self) { group in
      // Encode integers
      for value in intValues {
        group.addTask {
          let encoded = try XPCEncoder.encode(value)
          let decoded = try XPCDecoder.decode(PrimitiveWrapper<Int>.self, message: encoded)
          return decoded == value
        }
      }

      // Encode strings
      for value in stringValues {
        group.addTask {
          let encoded = try XPCEncoder.encode(value)
          let decoded = try XPCDecoder.decode(PrimitiveWrapper<String>.self, message: encoded)
          return decoded == value
        }
      }

      // Encode doubles
      for value in doubleValues {
        group.addTask {
          let encoded = try XPCEncoder.encode(value)
          let decoded = try XPCDecoder.decode(PrimitiveWrapper<Double>.self, message: encoded)
          return decoded == value
        }
      }

      // Encode bools
      for value in boolValues {
        group.addTask {
          let encoded = try XPCEncoder.encode(value)
          let decoded = try XPCDecoder.decode(PrimitiveWrapper<Bool>.self, message: encoded)
          return decoded == value
        }
      }

      // Verify all succeeded
      var successCount = 0
      for try await isEqual in group {
        #expect(isEqual)
        successCount += 1
      }

      #expect(successCount == 100)
    }
  }
}

// MARK: - Helper Types for Edge Case Tests

// MARK: Deeply Nested Structures

struct Deep1: Codable, Equatable {
  let value: Int
}

struct Deep2: Codable, Equatable {
  let value: Int
  let inner: Deep1
}

struct Deep3: Codable, Equatable {
  let value: Int
  let inner: Deep2
}

struct Deep4: Codable, Equatable {
  let value: Int
  let inner: Deep3
}

struct Deep5: Codable, Equatable {
  let value: Int
  let inner: Deep4
}

struct Deep6: Codable, Equatable {
  let value: Int
  let inner: Deep5
}

struct Deep7: Codable, Equatable {
  let value: Int
  let inner: Deep6
}

struct Deep8: Codable, Equatable {
  let value: Int
  let inner: Deep7
}

struct Deep9: Codable, Equatable {
  let value: Int
  let inner: Deep8
}

struct Deep10: Codable, Equatable {
  let value: Int
  let inner: Deep9
}

struct Deep11: Codable, Equatable {
  let value: Int
  let inner: Deep10
}

struct Deep12: Codable, Equatable {
  let value: Int
  let inner: Deep11
}

struct Deep13: Codable, Equatable {
  let value: Int
  let inner: Deep12
}

struct Deep14: Codable, Equatable {
  let value: Int
  let inner: Deep13
}

struct Deep15: Codable, Equatable {
  let value: Int
  let inner: Deep14
}

// MARK: Empty Container Structures

struct DoubleNestedEmpty: Codable, Equatable {
  let emptyDict: [String: Int]
  let emptyArray: [Int]
}

struct NestedEmptyContainers: Codable, Equatable {
  let emptyDict: [String: Int]
  let emptyArray: [Int]
  let doubleNested: DoubleNestedEmpty
}

struct EmptyContainerStruct: Codable, Equatable {
  let emptyDict: [String: Int]
  let emptyArray: [Int]
  let nestedEmpty: NestedEmptyContainers
}

// MARK: Special Key Structures

struct SpecialKeyStruct1: Codable, Equatable {
  let value: Int

  enum CodingKeys: String, CodingKey {
    case value = "hello world"
  }
}

struct SpecialKeyStruct2: Codable, Equatable {
  let value: Int

  enum CodingKeys: String, CodingKey {
    case value = "key.with.dots"
  }
}

struct SpecialKeyStruct3: Codable, Equatable {
  let value: Int

  enum CodingKeys: String, CodingKey {
    case value = "key/with/slashes"
  }
}

struct SpecialKeyStruct4: Codable, Equatable {
  let value: Int

  enum CodingKeys: String, CodingKey {
    case value = "key:colon"
  }
}

struct SpecialKeyStruct5: Codable, Equatable {
  let value: Int

  enum CodingKeys: String, CodingKey {
    case value = "日本語key"
  }
}

struct EmptyKeyStruct: Codable, Equatable {
  let value: Int

  enum CodingKeys: String, CodingKey {
    case value = ""
  }
}

struct NumericKeyStruct: Codable, Equatable {
  let value: Int

  enum CodingKeys: String, CodingKey {
    case value = "123"
  }
}

// MARK: Complex Nested Structure

struct NestedData: Codable, Equatable {
  let id: Int
  let tags: [String]
  let metadata: [String: String]
}

struct ComplexNestedStruct: Codable, Equatable {
  let name: String
  let values: [Int]
  let mapping: [String: Int]
  let nested: NestedData
}
