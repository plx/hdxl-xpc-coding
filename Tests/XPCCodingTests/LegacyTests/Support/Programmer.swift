import Foundation

/// A derived class
class Programmer : Person, @unchecked Sendable {
  let favoriteIDE: String
  
  init(name: String, email: String, website: URL? = nil, favoriteIDE: String) {
    self.favoriteIDE = favoriteIDE
    super.init(name: name, email: email, website: website)
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    favoriteIDE = try container.decode(String.self, forKey: .favoriteIDE)
    try super.init(from: container.superDecoder())
  }
  
  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(favoriteIDE, forKey: .favoriteIDE)
    try super.encode(to: container.superEncoder())
  }
  
  enum CodingKeys : String, CodingKey {
    case favoriteIDE
  }
  
  override func isEqual(_ other: Person) -> Bool {
    if let programmer = other as? Programmer {
      guard favoriteIDE == programmer.favoriteIDE else { return false }
    }
    
    return super.isEqual(other)
  }
  
}

func testProgrammers() -> [Programmer] {
  [
    Programmer(name: "Johnny Appleseed", email: "appleseed@apple.com", favoriteIDE: "Xcode")
  ]
}
