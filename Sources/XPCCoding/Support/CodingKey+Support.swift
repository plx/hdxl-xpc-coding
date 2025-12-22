import Foundation
import XPC

extension CodingKey {
  
  /// `true` iff this string can be used by xpc *without* truncation.
  ///
  /// Essentially this is just checking for null-bytes inside the body of `self`.
  @inlinable
  internal var isLosslesslyRepresentableAsXPCStringObject: Bool {
    stringValue.isLosslesslyRepresentableAsXPCStringObject
  }
  
  @inlinable
  internal func verifyXPCCompatibility() throws(XPCObjectCompatibilityError) {
    try stringValue.verifyXPCCompatibility()
  }
  
}
