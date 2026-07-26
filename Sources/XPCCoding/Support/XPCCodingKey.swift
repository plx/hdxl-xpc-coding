// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import XPC

// MARK: XPCCodingKey

/// A `CodingKey` type for use with `XPCCoding`; primarily exists to represent the `super` key.
@usableFromInline
internal struct XPCCodingKey: CodingKey {
  @usableFromInline
  internal let stringValue: String
  
  @usableFromInline
  internal let intValue: Int?

  @usableFromInline
  internal init?(stringValue: String) {
    self.intValue = nil
    self.stringValue = stringValue
  }
  
  @usableFromInline
  internal init(intValue: Int) {
    self.intValue = intValue
    self.stringValue = String(intValue)
  }
  
  @usableFromInline
  internal init(intValue: Int, stringValue: String) {
    self.intValue = intValue
    self.stringValue = stringValue
  }
  
  /// The key used to represent the `super` element in an archive.
  @usableFromInline
  internal static let superKey = XPCCodingKey(
    intValue: 0,
    stringValue: "super"
  )
}

// MARK: - Synthesized Conformances

extension XPCCodingKey: Equatable { }
extension XPCCodingKey: Hashable { }
