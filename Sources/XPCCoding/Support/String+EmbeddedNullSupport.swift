import Foundation
import XPC

extension String {

  /// Represents the way we want to handle embedded null bytes.
  @usableFromInline
  enum EmbeddedNullByteRepresentation {
    /// Ignore the possibility of embedded null bytes.
    case passthrough

    /// Apply XPCCoding's reversible percent-escape grammar.
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
    switch embeddedNullByteRepresentation {
    case .passthrough:
      try withCString(closure)
    case .percentEscaped:
      try addingXPCCodingPercentEscapes().withCString(closure)
    }
  }

  @usableFromInline
  internal func withXPCCodingPercentEscapedCString<R>(
    _ closure: (UnsafePointer<CChar>) throws -> R
  ) rethrows -> R {
    try addingXPCCodingPercentEscapes().withCString(closure)
  }

  /// Strictly decodes exactly `byteCount` UTF-8 bytes from a C pointer.
  @usableFromInline
  internal init?(
    validatingUTF8CString cString: UnsafePointer<CChar>,
    byteCount: Int
  ) {
    precondition(byteCount >= 0)
    self.init(
      bytes: UnsafeRawBufferPointer(
        start: cString,
        count: byteCount
      ),
      encoding: .utf8
    )
  }

  /// Encodes the two scalars reserved by XPCCoding's XPC-string grammar.
  ///
  /// This transform is total over `String`: U+0000 becomes `%00`, U+0025
  /// (`%`) becomes `%25`, and every other Unicode scalar is preserved.
  @usableFromInline
  internal func addingXPCCodingPercentEscapes() -> Self {
    var result = String()
    result.reserveCapacity(
      utf8.count + 2 * nullByteCount + 2 * percentCount
    )

    for scalar in unicodeScalars {
      switch scalar.value {
      case 0:
        result.append("%00")
      case 37:
        result.append("%25")
      default:
        result.unicodeScalars.append(scalar)
      }
    }
    return result
  }

  /// Decodes the exact escape sequences emitted by
  /// ``addingXPCCodingPercentEscapes()`` in one pass.
  ///
  /// Literal, dangling, malformed, and unsupported percent sequences are
  /// rejected. In particular, `%2500` becomes the literal string `%00`; the
  /// output is not scanned recursively.
  @usableFromInline
  internal func removingXPCCodingPercentEscapes() -> Self? {
    var result = String()
    result.reserveCapacity(utf8.count)
    var iterator = unicodeScalars.makeIterator()

    while let scalar = iterator.next() {
      guard scalar.value == 37 else {
        result.unicodeScalars.append(scalar)
        continue
      }

      guard
        let firstEscapeScalar = iterator.next(),
        let secondEscapeScalar = iterator.next()
      else {
        return nil
      }

      switch (firstEscapeScalar.value, secondEscapeScalar.value) {
      case (48, 48):
        result.unicodeScalars.append(.nullByte)
      case (50, 53):
        result.unicodeScalars.append(UnicodeScalar(37))
      default:
        return nil
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
