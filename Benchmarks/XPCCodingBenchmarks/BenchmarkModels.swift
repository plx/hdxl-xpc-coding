import Foundation
import XPCCoding

struct PrimitivePayload: Codable {
  let flag: Bool
  let signed: Int64
  let unsigned: UInt64
  let floatingPoint: Double
  let text: String
}

struct NestedPayload: Codable {
  let identifier: Int
  let name: String
  let children: [NestedPayload]

  static func fixture(depth: Int, breadth: Int = 2) -> Self {
    guard depth > 0 else {
      return Self(identifier: 0, name: "leaf", children: [])
    }
    return Self(
      identifier: depth,
      name: "node-\(depth)",
      children: (0..<breadth).map { _ in
        fixture(depth: depth - 1, breadth: breadth)
      }
    )
  }

  var nodeCount: Int {
    1 + children.reduce(0) { $0 + $1.nodeCount }
  }
}

struct KeyedDataPayload: Codable {
  let bytes: Data
}

struct UnkeyedDataPayload: Codable {
  let bytes: Data

  init(bytes: Data) {
    self.bytes = bytes
  }

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    bytes = try container.decode(Data.self)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(bytes)
  }
}

struct DynamicStringMap: Codable {
  let entries: [String: String]

  init(entries: [String: String]) {
    self.entries = entries
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    entries = try Dictionary(
      uniqueKeysWithValues: container.allKeys.map {
        ($0.stringValue, try container.decode(String.self, forKey: $0))
      }
    )
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    for (key, value) in entries {
      try container.encode(value, forKey: DynamicCodingKey(stringValue: key))
    }
  }
}

struct DynamicCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init?(intValue: Int) {
    stringValue = String(intValue)
    self.intValue = intValue
  }
}

struct DirectDataPayload: Encodable {
  let bytes: Data

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try bytes.withUnsafeBytes {
      try container.efficientlyEncodeBinaryData($0)
    }
  }
}
