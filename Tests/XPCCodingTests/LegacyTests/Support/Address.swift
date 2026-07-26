// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

/// A simple address type that encodes as a dictionary of values.
struct Address : Codable, Equatable {
  let street: String
  let city: String
  let state: String
  let zipCode: Int
  let country: String
  
  init(street: String, city: String, state: String, zipCode: Int, country: String) {
    self.street = street
    self.city = city
    self.state = state
    self.zipCode = zipCode
    self.country = country
  }
  
  static var testValue: Address {
    return Address(
      street: "1 Infinite Loop",
      city: "Cupertino",
      state: "CA",
      zipCode: 95014,
      country: "United States"
    )
  }
  
  static let testValues: [Self] = [testValue]
}
