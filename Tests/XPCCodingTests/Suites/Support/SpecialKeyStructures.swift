struct KeyWithSpaceStruct: Codable, Equatable {
  let value: Int

  enum CodingKeys: String, CodingKey {
    case value = "hello world"
  }
}

struct KeyWithDotsStruct: Codable, Equatable {
  let value: Int

  enum CodingKeys: String, CodingKey {
    case value = "key.with.dots"
  }
}

struct KeyWithSlashesStruct: Codable, Equatable {
  let value: Int

  enum CodingKeys: String, CodingKey {
    case value = "key/with/slashes"
  }
}

struct KeyWithColonStruct: Codable, Equatable {
  let value: Int

  enum CodingKeys: String, CodingKey {
    case value = "key:colon"
  }
}

struct KeyWithUnicodeStruct: Codable, Equatable {
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

/// A fixture whose coding keys all contain embedded null bytes.
///
/// Under the `.percentEscape` string-key strategy this round-trips exactly.
/// Under the intentionally lossy `.assumeAbsent` strategy the keys truncate at
/// their first null byte:
///
/// | field  | source key   | truncated key |
/// | ------ | ------------ | ------------- |
/// | `foo`  | `"\0"`       | `""`          |
/// | `bar`  | `"bar\0"`    | `"bar"`       |
/// | `baz`  | `"\0baz"`    | `""`          |
/// | `quux` | `"q\0u\0u\0x"` | `"q"`       |
///
/// `foo` and `baz` therefore collide on the empty key. ``encode(to:)`` fixes
/// the write order so the collision resolves deterministically, which is what
/// makes ``assumeAbsentDecodedValue`` an exact expectation rather than a guess.
struct KeysWithEmbeddedNullStruct: Equatable {
  let foo: Int
  let bar: Int
  let baz: Int
  let quux: Int

  /// The source value used by the embedded-null key suites.
  static let exampleValue = Self(foo: 1, bar: 2, baz: 3, quux: 4)

  /// Exactly what ``exampleValue`` decodes to under `.assumeAbsent`: `baz`
  /// overwrites `foo` at the shared empty key, so `foo` reads back as `3`.
  static let assumeAbsentDecodedValue = Self(foo: 3, bar: 2, baz: 3, quux: 4)
}

extension KeysWithEmbeddedNullStruct: Codable {

  enum CodingKeys: String, CodingKey {
    case foo = "\0"
    case bar = "bar\0"
    case baz = "\0baz"
    case quux = "q\0u\0u\0x"
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      foo: try container.decode(Int.self, forKey: .foo),
      bar: try container.decode(Int.self, forKey: .bar),
      baz: try container.decode(Int.self, forKey: .baz),
      quux: try container.decode(Int.self, forKey: .quux)
    )
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    // Written out explicitly, and in this order, so the `.assumeAbsent`
    // collision is a property of the fixture instead of a property of whatever
    // order the compiler happens to synthesize: `.baz` truncates to the same
    // empty key as `.foo`, and deliberately overwrites it.
    try container.encode(foo, forKey: .foo)
    try container.encode(bar, forKey: .bar)
    try container.encode(baz, forKey: .baz)
    try container.encode(quux, forKey: .quux)
  }
}
