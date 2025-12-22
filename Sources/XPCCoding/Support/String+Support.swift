import Foundation
import XPC

// auxiliary helper (no specific item)
// put this in a new file inside `XPCCoding` (`Support/String+Support.swift`)
extension String {
  
  /// `true` iff this string can be used by xpc *without* truncation.
  ///
  /// Essentially this is just checking for null-bytes inside the body of `self`.
  @inlinable
  internal var isLosslesslyRepresentableAsXPCStringObject: Bool {
    !containsNullBytes
    // ^ may need further expansion if we discover other problematic content
  }
  
  @inlinable
  internal var containsNullBytes: Bool {
    utf8.contains(0)
  }
  
  @inlinable
  internal func verifyXPCCompatibility() throws(XPCObjectCompatibilityError) {
    guard !isLosslesslyRepresentableAsXPCStringObject else { return }
    // would check each individual condition here if we gained additional ones
    let containsNullBytes = containsNullBytes
    throw XPCObjectCompatibilityError.incompatibleStringContent(
      "Contains null bytes: \(containsNullBytes)",
      self
    )
  }
  
}
