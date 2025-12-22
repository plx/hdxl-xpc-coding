// Tests/XPCCodingTests/Suites/CodingPathTests.swift
// Comprehensive tests for coding path tracking during encode/decode
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Coding Path Test Suite

@Suite("Coding Path", .tags(.codingPath))
struct CodingPathTests {

  // MARK: - Helper Types

  /// Wrapper for single field testing
  struct WithTracker: Codable, Equatable {
    let field: CodingPathTracker

    init(field: CodingPathTracker = CodingPathTracker()) {
      self.field = field
    }
  }

  /// Wrapper for array testing
  struct ArrayOfTrackers: Codable, Equatable {
    let items: [CodingPathTracker]

    init(items: [CodingPathTracker]) {
      self.items = items
    }
  }

  /// Outer container for nested keyed path testing
  struct Outer: Codable, Equatable {
    let inner: Inner

    init(inner: Inner) {
      self.inner = inner
    }
  }

  /// Inner container for nested keyed path testing
  struct Inner: Codable, Equatable {
    let value: CodingPathTracker

    init(value: CodingPathTracker = CodingPathTracker()) {
      self.value = value
    }
  }

  /// Multiple fields for path isolation testing
  struct MultiField: Codable, Equatable {
    let first: CodingPathTracker
    let second: CodingPathTracker

    init(first: CodingPathTracker = CodingPathTracker(marker: "first"),
         second: CodingPathTracker = CodingPathTracker(marker: "second")) {
      self.first = first
      self.second = second
    }
  }

  /// Item with tracker for mixed container testing
  struct ItemWithTracker: Codable, Equatable {
    let tracker: CodingPathTracker

    init(tracker: CodingPathTracker = CodingPathTracker()) {
      self.tracker = tracker
    }
  }

  /// Mixed keyed/unkeyed container
  struct Mixed: Codable, Equatable {
    let items: [ItemWithTracker]

    init(items: [ItemWithTracker]) {
      self.items = items
    }
  }

  /// 5-level nested structure
  struct Level1Container: Codable, Equatable {
    let level2: Level2Container

    init(level2: Level2Container) {
      self.level2 = level2
    }
  }

  struct Level2Container: Codable, Equatable {
    let level3: Level3Container

    init(level3: Level3Container) {
      self.level3 = level3
    }
  }

  struct Level3Container: Codable, Equatable {
    let level4: Level4Container

    init(level4: Level4Container) {
      self.level4 = level4
    }
  }

  struct Level4Container: Codable, Equatable {
    let level5: Level5Container

    init(level5: Level5Container) {
      self.level5 = level5
    }
  }

  struct Level5Container: Codable, Equatable {
    let tracker: CodingPathTracker

    init(tracker: CodingPathTracker = CodingPathTracker()) {
      self.tracker = tracker
    }
  }

  /// Parent class for super encoder testing
  class Parent: Codable, Equatable {
    let parentValue: String

    init(parentValue: String = "parent") {
      self.parentValue = parentValue
    }

    static func == (lhs: Parent, rhs: Parent) -> Bool {
      lhs.parentValue == rhs.parentValue
    }
  }

  /// Child class using superEncoder
  final class Child: Parent {
    let tracker: CodingPathTracker

    init(parentValue: String = "parent", tracker: CodingPathTracker = CodingPathTracker()) {
      self.tracker = tracker
      super.init(parentValue: parentValue)
    }

    enum CodingKeys: String, CodingKey {
      case tracker
    }

    required init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      tracker = try container.decode(CodingPathTracker.self, forKey: .tracker)
      try super.init(from: container.superDecoder())
    }

    override func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(tracker, forKey: .tracker)
      try super.encode(to: container.superEncoder())
    }

    static func == (lhs: Child, rhs: Child) -> Bool {
      lhs.parentValue == rhs.parentValue && lhs.tracker == rhs.tracker
    }
  }

  /// Type that captures coding path at top level using single value container
  struct TopLevelTracker: Codable, Equatable {
    let marker: String

    init(marker: String = "top") {
      self.marker = marker
    }

    init(from decoder: Decoder) throws {
      CodingPathTracker.lastDecodingPath = decoder.codingPath.map { $0.stringValue }
      let container = try decoder.singleValueContainer()
      marker = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
      CodingPathTracker.lastEncodingPath = encoder.codingPath.map { $0.stringValue }
      var container = encoder.singleValueContainer()
      try container.encode(marker)
    }
  }

  /// Type that captures full CodingKey info including intValue
  struct IndexPathTracker: Codable, Equatable {
    nonisolated(unsafe) static var lastEncodingKeys: [CodingKeyInfo] = []
    nonisolated(unsafe) static var lastDecodingKeys: [CodingKeyInfo] = []

    struct CodingKeyInfo: Equatable {
      let stringValue: String
      let intValue: Int?
    }

    let marker: String

    init(marker: String = "index") {
      self.marker = marker
    }

    init(from decoder: Decoder) throws {
      Self.lastDecodingKeys = decoder.codingPath.map {
        CodingKeyInfo(stringValue: $0.stringValue, intValue: $0.intValue)
      }
      let container = try decoder.singleValueContainer()
      marker = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
      Self.lastEncodingKeys = encoder.codingPath.map {
        CodingKeyInfo(stringValue: $0.stringValue, intValue: $0.intValue)
      }
      var container = encoder.singleValueContainer()
      try container.encode(marker)
    }
  }

  /// Wrapper for index path tracking
  struct ArrayOfIndexTrackers: Codable, Equatable {
    let items: [IndexPathTracker]

    init(items: [IndexPathTracker]) {
      self.items = items
    }
  }

  // MARK: - Test Cases

  @Test("Top-level path is empty", .tags(.encoding, .decoding))
  func topLevelPathIsEmpty() throws {
    // Reset tracking
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let tracker = TopLevelTracker()
    let encoded = try XPCEncoder.encode(tracker)

    // At top level, codingPath should be empty
    #expect(CodingPathTracker.lastEncodingPath.isEmpty)

    let decoded = try XPCDecoder.decode(TopLevelTracker.self, message: encoded)
    #expect(decoded == tracker)
    #expect(CodingPathTracker.lastDecodingPath.isEmpty)
  }

  @Test("Keyed container path contains field name", .tags(.keyed))
  func keyedContainerPath() throws {
    // Reset tracking
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let value = WithTracker()
    let encoded = try XPCEncoder.encode(value)

    // Path should contain the field name
    #expect(CodingPathTracker.lastEncodingPath == ["field"])

    let decoded = try XPCDecoder.decode(WithTracker.self, message: encoded)
    #expect(decoded == value)
    #expect(CodingPathTracker.lastDecodingPath == ["field"])
  }

  @Test("Unkeyed container path contains indices", .tags(.unkeyed))
  func unkeyedContainerPath() throws {
    // Reset tracking
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let trackers = [
      CodingPathTracker(marker: "0"),
      CodingPathTracker(marker: "1"),
      CodingPathTracker(marker: "2")
    ]

    // For verification, encode each individually to track paths
    for index in 0..<trackers.count {
      CodingPathTracker.lastEncodingPath = []
      CodingPathTracker.lastDecodingPath = []

      let singleItem = ArrayOfTrackers(items: [trackers[index]])
      let encoded = try XPCEncoder.encode(singleItem)

      // Path should be ["items", "0"] for the single item
      #expect(CodingPathTracker.lastEncodingPath == ["items", "0"])

      _ = try XPCDecoder.decode(ArrayOfTrackers.self, message: encoded)
      #expect(CodingPathTracker.lastDecodingPath == ["items", "0"])
    }
  }

  @Test("Nested keyed container path accumulates", .tags(.nested, .keyed))
  func nestedKeyedPath() throws {
    // Reset tracking
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let value = Outer(inner: Inner())
    let encoded = try XPCEncoder.encode(value)

    // Path should be ["inner", "value"]
    #expect(CodingPathTracker.lastEncodingPath == ["inner", "value"])

    let decoded = try XPCDecoder.decode(Outer.self, message: encoded)
    #expect(decoded == value)
    #expect(CodingPathTracker.lastDecodingPath == ["inner", "value"])
  }

  @Test("Deep nesting creates 5-element path", .tags(.nested, .keyed))
  func deepNestingPath() throws {
    // Reset tracking
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let value = Level1Container(
      level2: Level2Container(
        level3: Level3Container(
          level4: Level4Container(
            level5: Level5Container()
          )
        )
      )
    )

    let encoded = try XPCEncoder.encode(value)

    // Path should have 5 elements
    let expectedPath = ["level2", "level3", "level4", "level5", "tracker"]
    #expect(CodingPathTracker.lastEncodingPath == expectedPath)

    let decoded = try XPCDecoder.decode(Level1Container.self, message: encoded)
    #expect(decoded == value)
    #expect(CodingPathTracker.lastDecodingPath == expectedPath)
  }

  @Test("Super encoder path includes 'super' key", .tags(.inheritance))
  func superEncoderPath() throws {
    // Reset tracking
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let child = Child()
    let encoded = try XPCEncoder.encode(child)

    // Path should include "tracker" for the child's field
    #expect(CodingPathTracker.lastEncodingPath == ["tracker"])

    let decoded = try XPCDecoder.decode(Child.self, message: encoded)
    #expect(decoded == child)
    #expect(CodingPathTracker.lastDecodingPath == ["tracker"])
  }

  @Test("Path resets after container exit", .tags(.keyed))
  func pathResetsAfterContainerExit() throws {
    // Reset tracking
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    // Create a type that manually tracks paths during encoding
    struct PathRecorder: Codable {
      let first: CodingPathTracker
      let second: CodingPathTracker

      init() {
        self.first = CodingPathTracker(marker: "first")
        self.second = CodingPathTracker(marker: "second")
      }

      enum CodingKeys: String, CodingKey {
        case first
        case second
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode first
        first = try container.decode(CodingPathTracker.self, forKey: .first)
        let firstPath = CodingPathTracker.lastDecodingPath

        // Decode second
        second = try container.decode(CodingPathTracker.self, forKey: .second)
        let secondPath = CodingPathTracker.lastDecodingPath

        // Verify paths are isolated
        #expect(firstPath == ["first"])
        #expect(secondPath == ["second"])
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode first
        try container.encode(first, forKey: .first)
        let firstPath = CodingPathTracker.lastEncodingPath

        // Encode second
        try container.encode(second, forKey: .second)
        let secondPath = CodingPathTracker.lastEncodingPath

        // Verify paths are isolated
        #expect(firstPath == ["first"])
        #expect(secondPath == ["second"])
      }
    }

    let value = PathRecorder()
    let encoded = try XPCEncoder.encode(value)
    _ = try XPCDecoder.decode(PathRecorder.self, message: encoded)
  }

  @Test("Mixed container path alternates keyed and unkeyed", .tags(.nested, .keyed, .unkeyed))
  func mixedContainerPath() throws {
    // Reset tracking
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    // Create a type that tracks each item's path
    struct MixedPathTracker: Codable, Equatable {
      let items: [ItemWithTracker]
      var recordedEncodingPaths: [[String]] = []
      var recordedDecodingPaths: [[String]] = []

      init(items: [ItemWithTracker]) {
        self.items = items
      }

      enum CodingKeys: String, CodingKey {
        case items
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var itemsContainer = try container.nestedUnkeyedContainer(forKey: .items)

        var decodedItems: [ItemWithTracker] = []
        var paths: [[String]] = []

        while !itemsContainer.isAtEnd {
          let item = try itemsContainer.decode(ItemWithTracker.self)
          decodedItems.append(item)
          paths.append(CodingPathTracker.lastDecodingPath)
        }

        self.items = decodedItems
        self.recordedDecodingPaths = paths

        // Verify paths
        for (index, path) in paths.enumerated() {
          #expect(path == ["items", String(index), "tracker"])
        }
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var itemsContainer = container.nestedUnkeyedContainer(forKey: .items)

        var paths: [[String]] = []

        for item in items {
          try itemsContainer.encode(item)
          paths.append(CodingPathTracker.lastEncodingPath)
        }

        // Verify paths
        for (index, path) in paths.enumerated() {
          #expect(path == ["items", String(index), "tracker"])
        }
      }
    }

    let value = MixedPathTracker(items: [
      ItemWithTracker(tracker: CodingPathTracker(marker: "0")),
      ItemWithTracker(tracker: CodingPathTracker(marker: "1")),
      ItemWithTracker(tracker: CodingPathTracker(marker: "2"))
    ])

    let encoded = try XPCEncoder.encode(value)
    let decoded = try XPCDecoder.decode(MixedPathTracker.self, message: encoded)
    #expect(decoded.items == value.items)
  }

  @Test("Decoding path matches encoding path", .tags(.roundTrip))
  func decodingPathMatchesEncodingPath() throws {
    // Test various scenarios to ensure encoding and decoding paths match

    // Scenario 1: Simple keyed container
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let simple = WithTracker()
    let encoded1 = try XPCEncoder.encode(simple)
    let encodingPath1 = CodingPathTracker.lastEncodingPath

    _ = try XPCDecoder.decode(WithTracker.self, message: encoded1)
    let decodingPath1 = CodingPathTracker.lastDecodingPath

    #expect(encodingPath1 == decodingPath1)

    // Scenario 2: Nested keyed containers
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let nested = Outer(inner: Inner())
    let encoded2 = try XPCEncoder.encode(nested)
    let encodingPath2 = CodingPathTracker.lastEncodingPath

    _ = try XPCDecoder.decode(Outer.self, message: encoded2)
    let decodingPath2 = CodingPathTracker.lastDecodingPath

    #expect(encodingPath2 == decodingPath2)

    // Scenario 3: Deep nesting
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let deep = Level1Container(
      level2: Level2Container(
        level3: Level3Container(
          level4: Level4Container(
            level5: Level5Container()
          )
        )
      )
    )
    let encoded3 = try XPCEncoder.encode(deep)
    let encodingPath3 = CodingPathTracker.lastEncodingPath

    _ = try XPCDecoder.decode(Level1Container.self, message: encoded3)
    let decodingPath3 = CodingPathTracker.lastDecodingPath

    #expect(encodingPath3 == decodingPath3)
  }

  @Test("Integer keys have correct intValue in path", .tags(.unkeyed))
  func integerKeysHaveIntValue() throws {
    // Reset tracking
    IndexPathTracker.lastEncodingKeys = []
    IndexPathTracker.lastDecodingKeys = []

    let trackers = [
      IndexPathTracker(marker: "0"),
      IndexPathTracker(marker: "1"),
      IndexPathTracker(marker: "2")
    ]

    // Test each index individually
    for (_, tracker) in trackers.enumerated() {
      IndexPathTracker.lastEncodingKeys = []
      IndexPathTracker.lastDecodingKeys = []

      let value = ArrayOfIndexTrackers(items: [tracker])
      let encoded = try XPCEncoder.encode(value)

      // Verify encoding path has correct structure
      #expect(IndexPathTracker.lastEncodingKeys.count == 2)

      if IndexPathTracker.lastEncodingKeys.count >= 2 {
        // First key should be "items" (string key, no int value)
        #expect(IndexPathTracker.lastEncodingKeys[0].stringValue == "items")
        #expect(IndexPathTracker.lastEncodingKeys[0].intValue == nil)

        // Second key should be "0" (for the first/only item in the single-item array)
        #expect(IndexPathTracker.lastEncodingKeys[1].stringValue == "0")
        #expect(IndexPathTracker.lastEncodingKeys[1].intValue == 0)
      }

      let decoded = try XPCDecoder.decode(ArrayOfIndexTrackers.self, message: encoded)

      // Verify decoding path matches
      #expect(IndexPathTracker.lastDecodingKeys.count == 2)

      if IndexPathTracker.lastDecodingKeys.count >= 2 {
        #expect(IndexPathTracker.lastDecodingKeys[0].stringValue == "items")
        #expect(IndexPathTracker.lastDecodingKeys[0].intValue == nil)

        #expect(IndexPathTracker.lastDecodingKeys[1].stringValue == "0")
        #expect(IndexPathTracker.lastDecodingKeys[1].intValue == 0)
      }

      #expect(decoded.items == [tracker])
    }
  }

  @Test("Path is correct for optional values", .tags(.optionals, .keyed))
  func pathForOptionalValues() throws {
    struct OptionalTracker: Codable, Equatable {
      let value: CodingPathTracker?

      init(value: CodingPathTracker?) {
        self.value = value
      }
    }

    // Test with non-nil value
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let withValue = OptionalTracker(value: CodingPathTracker())
    let encoded1 = try XPCEncoder.encode(withValue)

    #expect(CodingPathTracker.lastEncodingPath == ["value"])

    let decoded1 = try XPCDecoder.decode(OptionalTracker.self, message: encoded1)
    #expect(decoded1 == withValue)
    #expect(CodingPathTracker.lastDecodingPath == ["value"])

    // Test with nil value - path tracking won't be triggered for nil
    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let withoutValue = OptionalTracker(value: nil)
    let encoded2 = try XPCEncoder.encode(withoutValue)

    // When encoding nil, the tracker's encode method is not called
    // so the path remains empty from the reset
    #expect(CodingPathTracker.lastEncodingPath.isEmpty)

    let decoded2 = try XPCDecoder.decode(OptionalTracker.self, message: encoded2)
    #expect(decoded2 == withoutValue)
    #expect(CodingPathTracker.lastDecodingPath.isEmpty)
  }

  @Test("Path is correct in nested unkeyed containers", .tags(.nested, .unkeyed))
  func pathInNestedUnkeyedContainers() throws {
    struct NestedArrays: Codable, Equatable {
      let outer: [[CodingPathTracker]]

      init(outer: [[CodingPathTracker]]) {
        self.outer = outer
      }
    }

    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    // Create nested array with single tracker to test path
    let value = NestedArrays(outer: [[CodingPathTracker()]])
    let encoded = try XPCEncoder.encode(value)

    // Path should be ["outer", "0", "0"]
    #expect(CodingPathTracker.lastEncodingPath == ["outer", "0", "0"])

    let decoded = try XPCDecoder.decode(NestedArrays.self, message: encoded)
    #expect(decoded == value)
    #expect(CodingPathTracker.lastDecodingPath == ["outer", "0", "0"])
  }

  @Test("Path is correct with explicit nested containers", .tags(.nested))
  func pathWithExplicitNestedContainers() throws {
    // Type that uses nestedContainer(keyedBy:forKey:)
    struct ExplicitNested: Codable, Equatable {
      let tracker: CodingPathTracker

      enum OuterKeys: String, CodingKey {
        case nested
      }

      enum InnerKeys: String, CodingKey {
        case tracker
      }

      init(tracker: CodingPathTracker = CodingPathTracker()) {
        self.tracker = tracker
      }

      init(from decoder: Decoder) throws {
        let outer = try decoder.container(keyedBy: OuterKeys.self)
        let inner = try outer.nestedContainer(keyedBy: InnerKeys.self, forKey: .nested)
        tracker = try inner.decode(CodingPathTracker.self, forKey: .tracker)
      }

      func encode(to encoder: Encoder) throws {
        var outer = encoder.container(keyedBy: OuterKeys.self)
        var inner = outer.nestedContainer(keyedBy: InnerKeys.self, forKey: .nested)
        try inner.encode(tracker, forKey: .tracker)
      }
    }

    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let value = ExplicitNested()
    let encoded = try XPCEncoder.encode(value)

    // Path should be ["nested", "tracker"]
    #expect(CodingPathTracker.lastEncodingPath == ["nested", "tracker"])

    let decoded = try XPCDecoder.decode(ExplicitNested.self, message: encoded)
    #expect(decoded == value)
    #expect(CodingPathTracker.lastDecodingPath == ["nested", "tracker"])
  }

  @Test("Path is correct with nested unkeyed in keyed", .tags(.nested, .keyed, .unkeyed))
  func pathWithNestedUnkeyedInKeyed() throws {
    // Type that uses nestedUnkeyedContainer(forKey:)
    struct KeyedToUnkeyed: Codable, Equatable {
      let trackers: [CodingPathTracker]

      enum CodingKeys: String, CodingKey {
        case trackers
      }

      init(trackers: [CodingPathTracker]) {
        self.trackers = trackers
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var nested = try container.nestedUnkeyedContainer(forKey: .trackers)

        var items: [CodingPathTracker] = []
        while !nested.isAtEnd {
          items.append(try nested.decode(CodingPathTracker.self))
        }
        trackers = items
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var nested = container.nestedUnkeyedContainer(forKey: .trackers)

        for tracker in trackers {
          try nested.encode(tracker)
        }
      }
    }

    CodingPathTracker.lastEncodingPath = []
    CodingPathTracker.lastDecodingPath = []

    let value = KeyedToUnkeyed(trackers: [CodingPathTracker()])
    let encoded = try XPCEncoder.encode(value)

    // Path should be ["trackers", "0"]
    #expect(CodingPathTracker.lastEncodingPath == ["trackers", "0"])

    let decoded = try XPCDecoder.decode(KeyedToUnkeyed.self, message: encoded)
    #expect(decoded == value)
    #expect(CodingPathTracker.lastDecodingPath == ["trackers", "0"])
  }
}
