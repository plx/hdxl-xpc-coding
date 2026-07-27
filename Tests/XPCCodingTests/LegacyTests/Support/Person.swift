// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation

/// A simple person class that encodes as a dictionary of values.
class Person: Codable, Equatable, @unchecked Sendable {
  let name: String
  let email: String
  let website: URL?

  init(name: String, email: String, website: URL? = nil) {
    self.name = name
    self.email = email
    self.website = website
  }

  private enum CodingKeys: String, CodingKey {
    case name
    case email
    case website
  }

  // Explicit conformance is intentional: subclasses exercise superclass coder sharing.
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    email = try container.decode(String.self, forKey: .email)
    website = try container.decodeIfPresent(URL.self, forKey: .website)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(email, forKey: .email)
    try container.encodeIfPresent(website, forKey: .website)
  }

  func isEqual(_ other: Person) -> Bool {
    name == other.name && email == other.email && website == other.website
  }

  static func == (_ lhs: Person, _ rhs: Person) -> Bool {
    lhs.isEqual(rhs)
  }

}

func testPersons() -> [Person] {
  [
    Person(name: "Johnny Appleseed", email: "appleseed@apple.com")
  ]
}
