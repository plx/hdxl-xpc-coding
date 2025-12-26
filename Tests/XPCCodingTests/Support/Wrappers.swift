import Foundation

// MARK: SingleValueWrapper

struct SingleValueWrapper<T>: Codable where T: Codable {
  let value: T
  
  init(_ value: T) {
    self.value = value
  }
  
  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(
      try container.decode(T.self)
    )
  }
  
  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(value)
  }
}

extension SingleValueWrapper: Sendable where T: Sendable { }
extension SingleValueWrapper: Equatable where T: Equatable { }

// MARK: - UnkeyedValueWrapper

struct UnkeyedValueWrapper<T>: Codable where T: Codable {
  let value: T
  
  init(_ value: T) {
    self.value = value
  }
  
  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    self.init(
      try container.decode(T.self)
    )
  }
  
  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(value)
  }
}

extension UnkeyedValueWrapper: Sendable where T: Sendable { }
extension UnkeyedValueWrapper: Equatable where T: Equatable { }

// MARK: - KeyedValueWrapper

struct KeyedValueWrapper<T>: Codable where T: Codable {
  let value: T
  
  init(_ value: T) {
    self.value = value
  }
  
  enum CodingKeys: String, CodingKey {
    case value
  }
  
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      try container.decode(
        T.self,
        forKey: .value
      )
    )
  }
  
  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(
      value,
      forKey: .value
    )
  }
}

extension KeyedValueWrapper: Sendable where T: Sendable { }
extension KeyedValueWrapper: Equatable where T: Equatable { }
