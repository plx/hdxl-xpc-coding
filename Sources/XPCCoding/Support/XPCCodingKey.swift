import XPC

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
  
  @usableFromInline
  internal static let superKey = XPCCodingKey(
    intValue: 0,
    stringValue: "super"
  )
}

// MARK: - Synthesized Conformances

extension XPCCodingKey: Equatable { }
extension XPCCodingKey: Hashable { }
