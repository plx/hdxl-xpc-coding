import Foundation

// MARK: - Simple Types

/// A minimal type with just a few fields.
struct SimpleStruct: Codable, Equatable, Sendable {
  let id: Int
  let name: String
  let active: Bool

  static let example = SimpleStruct(id: 42, name: "Test Item", active: true)
}

// MARK: - Types with Many Fields

/// A type with many fields to stress keyed container performance.
struct ManyFieldsStruct: Codable, Equatable, Sendable {
  let field01: Int
  let field02: Int
  let field03: Int
  let field04: Int
  let field05: Int
  let field06: Int
  let field07: Int
  let field08: Int
  let field09: Int
  let field10: Int
  let field11: String
  let field12: String
  let field13: String
  let field14: String
  let field15: String
  let field16: Double
  let field17: Double
  let field18: Double
  let field19: Bool
  let field20: Bool
  let field21: Int64
  let field22: Int64
  let field23: UInt32
  let field24: UInt32
  let field25: Float

  static let example = ManyFieldsStruct(
    field01: 1, field02: 2, field03: 3, field04: 4, field05: 5,
    field06: 6, field07: 7, field08: 8, field09: 9, field10: 10,
    field11: "string11", field12: "string12", field13: "string13",
    field14: "string14", field15: "string15",
    field16: 16.16, field17: 17.17, field18: 18.18,
    field19: true, field20: false,
    field21: 21_000_000_000, field22: 22_000_000_000,
    field23: 23_000, field24: 24_000,
    field25: 25.25
  )
}

// MARK: - Binary Data Types

/// A type containing binary data of various sizes.
struct BinaryDataStruct: Codable, Equatable, Sendable {
  let id: Int
  let smallData: Data   // ~100 bytes
  let mediumData: Data  // ~10KB
  let largeData: Data   // ~100KB

  static func example(
    smallSize: Int = 100,
    mediumSize: Int = 10_000,
    largeSize: Int = 100_000
  ) -> BinaryDataStruct {
    BinaryDataStruct(
      id: 1,
      smallData: Data(repeating: 0xAB, count: smallSize),
      mediumData: Data(repeating: 0xCD, count: mediumSize),
      largeData: Data(repeating: 0xEF, count: largeSize)
    )
  }

  static let example = BinaryDataStruct.example()
}

/// A type with only binary data (no other fields) for focused benchmarking.
struct PureBinaryStruct: Codable, Equatable, Sendable {
  let data: Data

  static func ofSize(_ size: Int) -> PureBinaryStruct {
    PureBinaryStruct(data: Data(repeating: 0xFF, count: size))
  }
}

// MARK: - Nested Types

/// A deeply nested structure to test nested container handling.
struct Level1: Codable, Equatable, Sendable {
  let value: Int
}

struct Level2: Codable, Equatable, Sendable {
  let value: Int
  let inner: Level1
}

struct Level3: Codable, Equatable, Sendable {
  let value: Int
  let inner: Level2
}

struct Level4: Codable, Equatable, Sendable {
  let value: Int
  let inner: Level3
}

struct Level5: Codable, Equatable, Sendable {
  let value: Int
  let inner: Level4
}

struct DeepNesting: Codable, Equatable, Sendable {
  let root: Level5

  static let example = DeepNesting(
    root: Level5(
      value: 5,
      inner: Level4(
        value: 4,
        inner: Level3(
          value: 3,
          inner: Level2(
            value: 2,
            inner: Level1(value: 1)
          )
        )
      )
    )
  )
}

// MARK: - Collection Types

/// A type with arrays of primitives.
struct ArraysStruct: Codable, Equatable, Sendable {
  let integers: [Int]
  let strings: [String]
  let doubles: [Double]

  static func withSize(_ count: Int) -> ArraysStruct {
    ArraysStruct(
      integers: (0..<count).map { $0 },
      strings: (0..<count).map { "string_\($0)" },
      doubles: (0..<count).map { Double($0) * 1.1 }
    )
  }

  static let small = withSize(10)
  static let medium = withSize(100)
  static let large = withSize(1000)
}

/// A type with dictionaries.
struct DictionaryStruct: Codable, Equatable, Sendable {
  let intDict: [String: Int]
  let stringDict: [String: String]

  static func withSize(_ count: Int) -> DictionaryStruct {
    var intDict: [String: Int] = [:]
    var stringDict: [String: String] = [:]
    for i in 0..<count {
      intDict["key_\(i)"] = i
      stringDict["key_\(i)"] = "value_\(i)"
    }
    return DictionaryStruct(intDict: intDict, stringDict: stringDict)
  }

  static let small = withSize(10)
  static let medium = withSize(100)
  static let large = withSize(1000)
}

// MARK: - Complex Composite Type

/// A complex type combining nested structures, arrays, and binary data.
struct ComplexMessage: Codable, Equatable, Sendable {
  let header: MessageHeader
  let payload: MessagePayload
  let metadata: [String: String]
  let attachments: [Attachment]
}

struct MessageHeader: Codable, Equatable, Sendable {
  let messageId: UUID
  let timestamp: Date
  let version: Int
  let sender: String
  let recipient: String
}

struct MessagePayload: Codable, Equatable, Sendable {
  let type: String
  let content: String
  let priority: Int
  let flags: [String]
}

struct Attachment: Codable, Equatable, Sendable {
  let name: String
  let mimeType: String
  let data: Data
}

extension ComplexMessage {
  static func example(attachmentCount: Int = 3, attachmentSize: Int = 1000) -> ComplexMessage {
    ComplexMessage(
      header: MessageHeader(
        messageId: UUID(),
        timestamp: Date(),
        version: 1,
        sender: "sender@example.com",
        recipient: "recipient@example.com"
      ),
      payload: MessagePayload(
        type: "notification",
        content: "This is a test message with some content that represents a typical payload.",
        priority: 5,
        flags: ["urgent", "read-receipt", "encrypted"]
      ),
      metadata: [
        "source": "benchmark",
        "environment": "test",
        "correlation-id": UUID().uuidString,
        "trace-id": UUID().uuidString
      ],
      attachments: (0..<attachmentCount).map { i in
        Attachment(
          name: "attachment_\(i).bin",
          mimeType: "application/octet-stream",
          data: Data(repeating: UInt8(i), count: attachmentSize)
        )
      }
    )
  }

  static let example = ComplexMessage.example()
}

// MARK: - Enum Types

/// An enum with associated values for testing enum encoding.
enum StatusEnum: Codable, Equatable, Sendable {
  case pending
  case inProgress(percentComplete: Int)
  case completed(result: String, duration: Double)
  case failed(error: String, code: Int)

  static let examples: [StatusEnum] = [
    .pending,
    .inProgress(percentComplete: 50),
    .completed(result: "Success", duration: 1.5),
    .failed(error: "Network timeout", code: 408)
  ]
}

struct StatusContainer: Codable, Equatable, Sendable {
  let statuses: [StatusEnum]

  static let example = StatusContainer(statuses: StatusEnum.examples)
}
