
// MARK: Level0

/// Base class (Level 0) for inheritance testing.
class Level0: Codable, Equatable, @unchecked Sendable {
  let a: Int
  
  init(a: Int) {
    self.a = a
  }
  
  func isEqual(to other: Level0) -> Bool {
    a == other.a
  }
  
  static func == (lhs: Level0, rhs: Level0) -> Bool {
    lhs === rhs || lhs.isEqual(to: rhs)
  }
}

func exampleLevel0s() -> [Level0] {
  [
    Level0(a: 1),
    Level0(a: 0)
  ]
}

// MARK: - Level1

/// Level 1 subclass using superEncoder.
class Level1: Level0, @unchecked Sendable {
  let b: Int
  
  init(a: Int, b: Int) {
    self.b = b
    super.init(a: a)
  }
  
  enum CodingKeys: String, CodingKey {
    case b
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    b = try container.decode(Int.self, forKey: .b)
    try super.init(from: container.superDecoder())
  }
  
  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(b, forKey: .b)
    try super.encode(to: container.superEncoder())
  }
  
  override func isEqual(to other: Level0) -> Bool {
    guard
      super.isEqual(to: other),
      let other = other as? Level1
    else {
      return false
    }
    
    return b == other.b
  }
  
}

func exampleLevel1s() -> [Level1] {
  [
    Level1(a: 1, b: 2),
    Level1(a: 0, b: 0)
  ]
}

// MARK: - Level2

/// Level 2 subclass.
class Level2: Level1, @unchecked Sendable {
  let c: Int
  
  init(a: Int, b: Int, c: Int) {
    self.c = c
    super.init(a: a, b: b)
  }
  
  enum CodingKeys: String, CodingKey {
    case c
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    c = try container.decode(Int.self, forKey: .c)
    try super.init(from: container.superDecoder())
  }
  
  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(c, forKey: .c)
    try super.encode(to: container.superEncoder())
  }
  
  override func isEqual(to other: Level0) -> Bool {
    guard
      super.isEqual(to: other),
      let other = other as? Level2
    else {
      return false
    }
    
    return c == other.c
  }
  
}

func exampleLevel2s() -> [Level2] {
  [
    Level2(a: 1, b: 2, c: 3),
    Level2(a: 0, b: 0, c: 0)
  ]
}

// MARK: - Level3

/// Level 3 subclass.
class Level3: Level2, @unchecked Sendable {
  let d: Int
  
  init(a: Int, b: Int, c: Int, d: Int) {
    self.d = d
    super.init(a: a, b: b, c: c)
  }
  
  enum CodingKeys: String, CodingKey {
    case d
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    d = try container.decode(Int.self, forKey: .d)
    try super.init(from: container.superDecoder())
  }
  
  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(d, forKey: .d)
    try super.encode(to: container.superEncoder())
  }
  
  override func isEqual(to other: Level0) -> Bool {
    guard
      super.isEqual(to: other),
      let other = other as? Level3
    else {
      return false
    }
    
    return d == other.d
  }
  
}

func exampleLevel3s() -> [Level3] {
  [
    Level3(a: 1, b: 2, c: 3, d: 4),
    Level3(a: 0, b: 0, c: 0, d: 0)
  ]
}

// MARK: - Level4

/// Level 4 subclass.
class Level4: Level3, @unchecked Sendable {
  let e: Int
  
  init(a: Int, b: Int, c: Int, d: Int, e: Int) {
    self.e = e
    super.init(a: a, b: b, c: c, d: d)
  }
  
  enum CodingKeys: String, CodingKey {
    case e
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    e = try container.decode(Int.self, forKey: .e)
    try super.init(from: container.superDecoder())
  }
  
  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(e, forKey: .e)
    try super.encode(to: container.superEncoder())
  }
  
  override func isEqual(to other: Level0) -> Bool {
    guard
      super.isEqual(to: other),
      let other = other as? Level4
    else {
      return false
    }
    
    return e == other.e
  }
  
}

func exampleLevel4s() -> [Level4] {
  [
    Level4(a: 1, b: 2, c: 3, d: 4, e: 5),
    Level4(a: 0, b: 0, c: 0, d: 0, e: 0)
  ]
}

// MARK: - Level5

/// Level 5 subclass.
class Level5: Level4, @unchecked Sendable {
  let f: Int
  
  init(a: Int, b: Int, c: Int, d: Int, e: Int, f: Int) {
    self.f = f
    super.init(a: a, b: b, c: c, d: d, e: e)
  }
  
  enum CodingKeys: String, CodingKey {
    case f
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    f = try container.decode(Int.self, forKey: .f)
    try super.init(from: container.superDecoder())
  }
  
  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(f, forKey: .f)
    try super.encode(to: container.superEncoder())
  }
  
  override func isEqual(to other: Level0) -> Bool {
    guard
      super.isEqual(to: other),
      let other = other as? Level5
    else {
      return false
    }
    
    return f == other.f
  }
  
}


func exampleLevel5s() -> [Level5] {
  [
    Level5(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6),
    Level5(a: 0, b: 0, c: 0, d: 0, e: 0, f: 0)
  ]
}

// MARK: - Level6

/// Level 6 subclass (maximum tested depth).
class Level6: Level5, @unchecked Sendable {
  let g: Int
  
  init(a: Int, b: Int, c: Int, d: Int, e: Int, f: Int, g: Int) {
    self.g = g
    super.init(a: a, b: b, c: c, d: d, e: e, f: f)
  }
  
  enum CodingKeys: String, CodingKey {
    case g
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    g = try container.decode(Int.self, forKey: .g)
    try super.init(from: container.superDecoder())
  }
  
  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(g, forKey: .g)
    try super.encode(to: container.superEncoder())
  }
  
  override func isEqual(to other: Level0) -> Bool {
    guard
      super.isEqual(to: other),
      let other = other as? Level6
    else {
      return false
    }
    
    return g == other.g
  }
}

func exampleLevel6s() -> [Level6] {
  [
    Level6(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7),
    Level6(a: 0, b: 0, c: 0, d: 0, e: 0, f: 0, g: 0)
  ]
}
