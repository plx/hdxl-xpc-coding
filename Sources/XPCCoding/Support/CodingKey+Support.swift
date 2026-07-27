import Foundation
import XPC

extension CodingKey {
  
  /// `true` iff this string can be used by xpc *without* truncation.
  ///
  /// Essentially this is just checking for null-bytes inside the body of `self`.
  internal var isLosslesslyRepresentableAsXPCStringObject: Bool {
    stringValue.isLosslesslyRepresentableAsXPCStringObject
  }
  
  /// Access the UTF-8 representation of `self.stringValue` as a null-terminated C string, using the given `embeddedNullByteRepresentation`.
  internal func withUTF8CString<R>(
    embeddedNullByteRepresentation: String.EmbeddedNullByteRepresentation,
    _ closure: (UnsafePointer<CChar>) throws -> R
  ) rethrows -> R {
    try stringValue.withUTF8CString(
      embeddedNullByteRepresentation: embeddedNullByteRepresentation,
      closure
    )
  }

  /// Access the UTF-8 representation of `self.stringValue` as a null-terminated C string, using the given `stringKeyStrategy`.
  internal func withUTF8CString<R>(
    stringKeyStrategy: XPCEncoder.StringKeyStrategy,
    _ closure: (UnsafePointer<CChar>) throws -> R
  ) rethrows -> R {
    try withUTF8CString(
      embeddedNullByteRepresentation: stringKeyStrategy.embeddedNullByteRepresentation,
      closure
    )
  }

  /// Access the UTF-8 representation of `self.stringValue` as a null-terminated C string, using the given `stringKeyStrategy`.
  internal func withUTF8CString<R>(
    stringKeyStrategy: XPCDecoder.StringKeyStrategy,
    _ closure: (UnsafePointer<CChar>) throws -> R
  ) rethrows -> R {
    try withUTF8CString(
      embeddedNullByteRepresentation: stringKeyStrategy.embeddedNullByteRepresentation,
      closure
    )
  }
}
