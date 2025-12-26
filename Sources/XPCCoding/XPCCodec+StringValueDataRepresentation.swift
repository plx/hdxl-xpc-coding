import Foundation

// MARK: StringValueEmbeddedNullByteStrategy

extension XPCCodec {

  public enum StringValueDataRepresentation {
    
    case utf8
    case utf16
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
