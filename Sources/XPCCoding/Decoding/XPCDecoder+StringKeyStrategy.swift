import Foundation
import XPC

extension XPCDecoder {

  /// The strategy for handling encoded null bytes in string keys during decoding.
  ///
  /// This strategy must match the encoding strategy used when the data was created
  /// to ensure correct round-tripping of string keys.
  public enum StringKeyStrategy {

    /// Decode string keys directly without any transformation.
    ///
    /// Use this when keys were encoded with ``XPCEncoder/StringKeyStrategy/assumeAbsent``
    /// and are known not to contain any encoded null bytes.
    case passthrough

    /// Decode percent-encoded null bytes in string keys.
    ///
    /// Use this when keys were encoded with ``XPCEncoder/StringKeyStrategy/percentEscape``.
    /// This is the default strategy.
    case percentEscape
  }

}

extension XPCDecoder.StringKeyStrategy: Sendable { }
extension XPCDecoder.StringKeyStrategy: Equatable { }
extension XPCDecoder.StringKeyStrategy: Hashable { }
extension XPCDecoder.StringKeyStrategy: Codable { }
extension XPCDecoder.StringKeyStrategy: CaseIterable { }

extension XPCDecoder.StringKeyStrategy {

  /// The standard (default) strategy for decoding string keys.
  public static let standard: Self = XPCCodec.StringKeyStrategy.standard.decodingStrategy
  
  @usableFromInline
  internal var embeddedNullByteRepresentation: String.EmbeddedNullByteRepresentation {
    switch self {
    case .passthrough:
      .passthrough
    case .percentEscape:
      .percentEscaped
    }
  }
  
}

extension XPCCodec.StringKeyStrategy {
  
  @usableFromInline
  internal var decodingStrategy: XPCDecoder.StringKeyStrategy {
    switch self {
    case .assumeAbsent:
      .passthrough
    case .percentEscape:
      .percentEscape
    }
  }
  
}
