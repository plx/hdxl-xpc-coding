import Foundation
import XPC

// auxiliary helper (no specific item)
// put this in a new file inside `XPCCoding` (`Support/String+Support.swift`)
extension String {

  @usableFromInline
  enum EmbeddedNullByteRepresentation {
    case passthrough
    case percentEscaped
  }
  
  @usableFromInline
  enum StringKeyUsageError: Error {
    case nullBytesDetected(String)
  }
//
//  @usableFromInline
//  internal func withUTF8CString<R>(
//    stringKeyStrategy: XPCCodec.StringKeyStrategy,
//    _ closure: (UnsafePointer<CChar>) throws -> R
//  ) throws -> R {
//    switch stringKeyStrategy {
//    case .assumeAbsent:
//      return try withCString(closure)
//    case .throwOnDiscovery:
//      guard !containsNullBytes else {
//        throw StringKeyUsageError.nullBytesDetected(self)
//      }
//      return try withCString(closure)
//    case .percentEscape:
//      switch containsNullBytes {
//      case true:
//        return try withStringWithEmbeddedNullBytesPercentEncoded(closure)
//      case false:
//        return try withCString(closure)
//      }
//    }
//  }

  @usableFromInline
  internal func withUTF8CString<R>(
    stringKeyStrategy: XPCEncoder.StringKeyStrategy,
    _ closure: (UnsafePointer<CChar>) throws -> R
  ) rethrows -> R {
    switch stringKeyStrategy {
    case .assumeAbsent:
      return try withCString(closure)
    case .percentEscape:
      switch containsNullBytes {
      case true:
        return try withStringWithEmbeddedNullBytesPercentEncoded(closure)
      case false:
        return try withCString(closure)
      }
    }
  }

  @usableFromInline
  internal func withUTF8CString<R>(
    stringKeyStrategy: XPCDecoder.StringKeyStrategy,
    _ closure: (UnsafePointer<CChar>) throws -> R
  ) throws -> R {
    switch stringKeyStrategy {
    case .passthrough:
      return try withCString(closure)
    case .percentEscape:
      switch containsNullBytes {
      case true:
        return try withStringWithEmbeddedNullBytesPercentEncoded(closure)
      case false:
        return try withCString(closure)
      }
    }
  }

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
  internal init?(cString: UnsafePointer<CChar>, embeddedNullByteRepresentation: EmbeddedNullByteRepresentation) {
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

  @usableFromInline
  internal func withModifiedUTF8CString<R>(
    expectedNullByteCount: Int,
    _ closure: (UnsafePointer<CChar>) throws -> R
  ) rethrows -> R {
    let utf8 = utf8
    return try withUnsafeTemporaryAllocation(
      of: CChar.self,
      capacity: utf8.count + expectedNullByteCount
    ) { unsafeMutableBufferPointer in
      var injectionCount: Int = 0
      for (index, character) in utf8.enumerated() {
        let baseIndex = index + injectionCount
        switch character == .zero {
        case true:
          unsafeMutableBufferPointer.initializeElement(
            at: baseIndex,
            to: Int8(bitPattern: 0xC0 as UInt8)
          )
          unsafeMutableBufferPointer.initializeElement(
            at: baseIndex + 1,
            to: Int8(bitPattern: 0x80 as UInt8)
          )
          injectionCount += 1
        case false:
          unsafeMutableBufferPointer.initializeElement(
            at: baseIndex,
            to: Int8(bitPattern: character)
          )
        }
      }
      
      guard let baseAddress = unsafeMutableBufferPointer.baseAddress else {
        fatalError("Couldn't get a base address here!")
      }
      
      return try closure(baseAddress)
    }
  }
  
}

extension CharacterSet {
  
  static let everythingButNull: Self = Self(charactersIn: (.nullByte)...(.nullByte)).inverted
  
}

extension UnicodeScalar {
  
  static let nullByte: Self = UnicodeScalar(0)
}
