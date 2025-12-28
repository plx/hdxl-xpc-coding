
// MARK: CustomSuperKey

/// A class that uses a custom super encoder key.
final class CustomSuperKey: Level0, @unchecked Sendable {
  let extra: String
  
  init(a: Int, extra: String) {
    self.extra = extra
    super.init(a: a)
  }
  
  enum CodingKeys: String, CodingKey {
    case extra
    case parent
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    extra = try container.decode(String.self, forKey: .extra)
    try super.init(from: container.superDecoder(forKey: .parent))
  }
  
  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(extra, forKey: .extra)
    try super.encode(to: container.superEncoder(forKey: .parent))
  }
  
  override func isEqual(to other: Level0) -> Bool {
    guard
      super.isEqual(to: other),
      let other = other as? CustomSuperKey
    else {
      return false
    }
    
    return extra == other.extra
  }
  
}

func exampleCustomSuperKeys() -> [CustomSuperKey] {
  [
    CustomSuperKey(a: 0, extra: "a"),
    CustomSuperKey(a: 1, extra: "abcdefg"),
    CustomSuperKey(a: 2, extra: "parent")
  ]
}

// MARK: - OptionalBase

/// Base class with optional property.
class OptionalBase: Codable, Equatable, @unchecked Sendable {
  let required: Int
  let optional: String?
  
  init(required: Int, optional: String?) {
    self.required = required
    self.optional = optional
  }
  
  func isEqual(to other: OptionalBase) -> Bool {
    required == other.required && optional == other.optional
  }
  
  static func == (lhs: OptionalBase, rhs: OptionalBase) -> Bool {
    lhs === rhs || lhs.isEqual(to: rhs)
  }
}

func exampleOptionalBases() -> [OptionalBase] {
  [
    OptionalBase(required: 1, optional: nil),
    OptionalBase(required: 2, optional: "optional")
  ]
}

// MARK: - OptionalChild

/// Child class with additional optional property.
final class OptionalChild: OptionalBase, @unchecked Sendable {
  let childOptional: Int?
  
  init(required: Int, optional: String?, childOptional: Int?) {
    self.childOptional = childOptional
    super.init(required: required, optional: optional)
  }
  
  enum CodingKeys: String, CodingKey {
    case childOptional
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    childOptional = try container.decodeIfPresent(Int.self, forKey: .childOptional)
    try super.init(from: container.superDecoder())
  }
  
  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(childOptional, forKey: .childOptional)
    try super.encode(to: container.superEncoder())
  }
  
  override func isEqual(to other: OptionalBase) -> Bool {
    guard
      super.isEqual(to: other),
      let other = other as? OptionalChild
    else {
      return false
    }
    
    return childOptional == other.childOptional
  }
  
}

func exampleOptionalChildren() -> [OptionalChild] {
  [
    OptionalChild(required: 0, optional: nil, childOptional: nil),
    OptionalChild(required: 1, optional: "optional", childOptional: nil),
    OptionalChild(required: 2, optional: nil, childOptional: 99),
    OptionalChild(required: 3, optional: "optional", childOptional: 101)
  ]
}

// MARK: - MixedTypeBase

/// Base class with mixed primitive types.
class MixedTypeBase: Codable, Equatable, @unchecked Sendable {
  let intValue: Int
  let stringValue: String
  
  init(intValue: Int, stringValue: String) {
    self.intValue = intValue
    self.stringValue = stringValue
  }
  
  func isEqual(to other: MixedTypeBase) -> Bool {
    intValue == other.intValue && stringValue == other.stringValue
  }

  static func == (lhs: MixedTypeBase, rhs: MixedTypeBase) -> Bool {
    lhs === rhs || lhs.isEqual(to: rhs)
  }
}

func exampleMixedTypeBase() -> [MixedTypeBase] {
  [
    MixedTypeBase(intValue: 0, stringValue: "a"),
    MixedTypeBase(intValue: 2, stringValue: "b")
  ]
}


// MARK: - MixedTypeChild

/// Child class with additional mixed types.
final class MixedTypeChild: MixedTypeBase, @unchecked Sendable {
  let doubleValue: Double
  let boolValue: Bool
  
  init(intValue: Int, stringValue: String, doubleValue: Double, boolValue: Bool) {
    self.doubleValue = doubleValue
    self.boolValue = boolValue
    super.init(intValue: intValue, stringValue: stringValue)
  }
  
  enum CodingKeys: String, CodingKey {
    case doubleValue
    case boolValue
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    doubleValue = try container.decode(Double.self, forKey: .doubleValue)
    boolValue = try container.decode(Bool.self, forKey: .boolValue)
    try super.init(from: container.superDecoder())
  }
  
  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(doubleValue, forKey: .doubleValue)
    try container.encode(boolValue, forKey: .boolValue)
    try super.encode(to: container.superEncoder())
  }
  
  override func isEqual(to other: MixedTypeBase) -> Bool {
    guard
      super.isEqual(to: other),
      let other = other as? MixedTypeChild
    else {
      return false
    }
    
    return equivalentFloats(doubleValue, other.doubleValue) && boolValue == other.boolValue
  }
  
}

func exampleMixedTypeChildren() -> [MixedTypeChild] {
  [
    MixedTypeChild(intValue: 0, stringValue: "a", doubleValue: 1.0, boolValue: false),
    MixedTypeChild(intValue: 2, stringValue: "b", doubleValue: 3.0, boolValue: true),
  ]
}
