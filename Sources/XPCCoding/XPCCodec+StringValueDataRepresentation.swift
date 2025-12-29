import Foundation

// MARK: StringValueEmbeddedNullByteStrategy

extension XPCCodec {

  /// Specifies the encoding to use when representing strings as binary data in XPC.
  ///
  /// When using the ``StringValueStrategy/useDataRepresentation(_:)`` strategy,
  /// strings are encoded as binary data rather than as XPC strings. This enumeration
  /// specifies which Unicode encoding to use for that representation.
  public enum StringValueDataRepresentation {

    /// Encode strings as UTF-8 binary data.
    case utf8

    /// Encode strings as UTF-16 binary data.
    case utf16

    /// Encode strings as UTF-32 binary data.
    case utf32

    @usableFromInline
    internal var stringEncoding: String.Encoding {
      switch self {
      case .utf8:
        .utf8
      case .utf16:
        .utf16
      case .utf32:
        .utf32
      }
    }
  }
  
}

// MARK: - Synthesized Conformances

extension XPCCodec.StringValueDataRepresentation: Sendable { }
extension XPCCodec.StringValueDataRepresentation: Equatable { }
extension XPCCodec.StringValueDataRepresentation: Hashable { }
extension XPCCodec.StringValueDataRepresentation: Codable { }
extension XPCCodec.StringValueDataRepresentation: CaseIterable { }

// MARK: - CustomStringConvertible

extension XPCCodec.StringValueDataRepresentation: CustomStringConvertible {
  
  public var description: String {
    switch self {
    case .utf8: "UTF-8"
    case .utf16: "UTF-16"
    case .utf32: "UTF-32"
    }
  }
  
}

// MARK: - CustomDebugStringConvertible

extension XPCCodec.StringValueDataRepresentation: CustomDebugStringConvertible {
  
  public var debugDescription: String {
    switch self {
    case .utf8: ".utf8"
    case .utf16: ".utf16"
    case .utf32: ".utf32"
    }
  }
  
}
