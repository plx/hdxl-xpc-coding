
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

struct KeysWithEmbeddedNullStruct: Codable, Equatable {
  let foo: Int
  let bar: Int
  let baz: Int
  let quux: Int
  
  enum CodingKeys: String, CodingKey {
    case foo = "\0"
    case bar = "bar\0"
    case baz = "\0baz"
    case quux = "q\0u\0u\0x"
  }
  
  static let exampleValue = Self(foo: 1, bar: 2, baz: 3, quux: 4)
}
