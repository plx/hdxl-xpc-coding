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
  internal func withUTF8CString<R>(
    embeddedNullByteRepresentation: String.EmbeddedNullByteRepresentation,
    _ closure: (UnsafePointer<CChar>) throws -> R
  ) rethrows -> R {
    try stringValue.withUTF8CString(
      embeddedNullByteRepresentation: embeddedNullByteRepresentation,
      closure
    )
  }

}
