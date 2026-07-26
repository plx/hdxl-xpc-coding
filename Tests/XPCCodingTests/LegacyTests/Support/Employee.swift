// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation

/// A class which shares its encoder and decoder with its superclass.
class Employee : Person, @unchecked Sendable {
  let id: Int
  
  init(name: String, email: String, website: URL? = nil, id: Int) {
    self.id = id
    super.init(name: name, email: email, website: website)
  }
  
  enum CodingKeys : String, CodingKey {
    case id
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(Int.self, forKey: .id)
    try super.init(from: decoder)
  }
  
  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try super.encode(to: encoder)
  }
  
  override func isEqual(_ other: Person) -> Bool {
    if let employee = other as? Employee {
      guard id == employee.id else { return false }
    }
    
    return super.isEqual(other)
  }
  
}

func testEmployees() -> [Employee] {
  [
    Employee(name: "Johnny Appleseed", email: "appleseed@apple.com", id: 42),
    Employee(name: "J. Random Hacker", email: "random@apple.com", id: 43)
  ]
}
