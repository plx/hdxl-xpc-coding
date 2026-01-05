import Foundation
import XPC

extension String {

  /// Represents the way we want to handle embedded null bytes.
  @usableFromInline
  enum EmbeddedNullByteRepresentation {
    /// Ignore the possibility of embedded null bytes.
    case passthrough

    /// Expect to percent-escape (or percent-unescape) to handle null bytes.
    case percentEscaped
  }

  /// Access the c-string representation of the string, handling null bytes as per the `stringKeyStrategy`.
  /// 
  /// - seealso: `withUTF8CString(embeddedNullByteRepresentation:_:)`
  @usableFromInline
  internal func withUTF8CString<R>(
    stringKeyStrategy: XPCEncoder.StringKeyStrategy,
    _ closure: (UnsafePointer<CChar>) throws -> R
  ) rethrows -> R {
    try withUTF8CString(
      embeddedNullByteRepresentation: stringKeyStrategy.embeddedNullByteRepresentation,
      closure
    )
  }

  /// Access the c-string representation of the string, handling null bytes as per the `stringKeyStrategy`.
  /// 
  /// - seealso: `withUTF8CString(embeddedNullByteRepresentation:_:)`
  @usableFromInline
  internal func withUTF8CString<R>(
    stringKeyStrategy: XPCDecoder.StringKeyStrategy,
    _ closure: (UnsafePointer<CChar>) throws -> R
  ) rethrows -> R {
    try withUTF8CString(
      embeddedNullByteRepresentation: stringKeyStrategy.embeddedNullByteRepresentation,
      closure
    )
  }

  /// Access the c-string representation of the string, handling null bytes as per the `embeddedNullByteRepresentation`.
  @usableFromInline
  internal func withUTF8CString<R>(
    embeddedNullByteRepresentation: EmbeddedNullByteRepresentation,
    _ closure: (UnsafePointer<CChar>) throws -> R
  ) rethrows -> R {
    let nullByteCount = nullByteCount
    let containsNullBytes = nullByteCount > 0
    return switch (embeddedNullByteRepresentation, containsNullBytes) {
    case (.percentEscaped, true):
      try percentEscapingEmbeddedNullBytes(expectedNullByteCount: nullByteCount).withCString(closure)
    case (.passthrough, _): fallthrough
    case (_, false):
      try withCString(closure)
    }
  }

  @usableFromInline
  internal func withStringWithEmbeddedNullBytesPercentEncoded<R>(
    _ closure: (UnsafePointer<CChar>) throws -> R
  ) rethrows -> R {
    switch containsNullBytes {
    case true:
      try percentEscapingEmbeddedNullBytes(expectedNullByteCount: nullByteCount).withCString(closure)
    case false:
      try withCString(closure)
    }
  }

  @usableFromInline
  internal init?(
    cString: UnsafePointer<CChar>, 
    embeddedNullByteRepresentation: EmbeddedNullByteRepresentation
    ) {
    switch embeddedNullByteRepresentation {
    case .passthrough:
      self.init(cString: cString)
    case .percentEscaped:
      guard let result = String(cString: cString).removingPercentEncoding else {
        return nil
      }
      self = result
    }
  }
  
  @usableFromInline
  internal func percentEscapingEmbeddedNullBytes(expectedNullByteCount: Int) -> Self {
    var result = String()
    let percentCount = percentCount
    result.reserveCapacity(count + 2 * expectedNullByteCount + 2 * percentCount)
    for character in self {
      switch character {
      case "\0":
        result.append("%00")
      case "%":
        result.append("%25")
      default:
        result.append(character)
      }
    }
    return result
  }


}

extension CharacterSet {
  
  static let everythingButNull: Self = Self(charactersIn: (.nullByte)...(.nullByte)).inverted
  
}

extension UnicodeScalar {
  
  static let nullByte: Self = UnicodeScalar(0)
}
