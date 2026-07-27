// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

/// A simple company struct which encodes as a dictionary of nested values.
struct Company : Sendable, Codable, Equatable {
  let address: Address
  var employees: [Employee]
  
  init(address: Address, employees: [Employee]) {
    self.address = address
    self.employees = employees
  }
  
  static var testValue: Company {
    Company(
      address: Address.testValue,
      employees: testEmployees()
    )
  }
  
  static var testValues: [Self] {
    [testValue]
  }
}
