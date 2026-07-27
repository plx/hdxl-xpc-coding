import Testing

// MARK: SharedEncoderBase

/// A base class for shared encoder testing.
class SharedEncoderBase: Codable, Equatable, @unchecked Sendable {
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

  func isEqual(to other: SharedEncoderBase) -> Bool {
    baseValue == other.baseValue
  }

  static func == (lhs: SharedEncoderBase, rhs: SharedEncoderBase) -> Bool {
    lhs === rhs || lhs.isEqual(to: rhs)
  }
}

func exampleSharedEncoderBases() -> [SharedEncoderBase] {
  [
    SharedEncoderBase(baseValue: "foo"),
    SharedEncoderBase(baseValue: "bar"),
  ]
}

// MARK: - SharedEncoderChild

/// A subclass that shares the encoder with its parent.
final class SharedEncoderChild: SharedEncoderBase, @unchecked Sendable {
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

  override func isEqual(to other: SharedEncoderBase) -> Bool {
    guard
      super.isEqual(to: other),
      let other = other as? SharedEncoderChild
    else {
      return false
    }

    return childValue == other.childValue
  }

}

func exampleSharedEncoderChildren() -> [SharedEncoderChild] {
  [
    SharedEncoderChild(baseValue: "foo", childValue: 0),
    SharedEncoderChild(baseValue: "bar", childValue: 1),
  ]
}
