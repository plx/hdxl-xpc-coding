import Foundation
import XPC

extension String {
  
  /// `true` iff this string can be used by xpc *without* truncation.
  ///
  /// Essentially this is just checking for null-bytes inside the body of `self`.
  internal var isLosslesslyRepresentableAsXPCStringObject: Bool {
    !containsNullBytes
    // ^ may need further expansion if we discover other problematic content
  }
  
  /// `true` iff this string contains null-bytes.
  internal var containsNullBytes: Bool {
    utf8.contains(0)
  }

  // Inlining audit rationale: these two measured scan leaves let the percent-
  // escape path preallocate without exposing the complete string transform.

  /// The number of null-bytes in this string.
  @inlinable
  internal var nullByteCount: Int {
    utf8.count { $0 == 0 }
  }

  /// The number of percent characters in this string.
  @inlinable
  internal var percentCount: Int {
    utf8.count { $0 == UTF8.CodeUnit(ascii: "%") }
  }
  
}
