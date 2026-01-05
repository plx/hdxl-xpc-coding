import Foundation
import XPC

// MARK: XPCEncoder.StringKeyStrategy

extension XPCEncoder {

  /// The strategy for handling embedded null bytes in string keys during encoding.
  public enum StringKeyStrategy {

    /// Assume no null bytes are present and encode directly.
    ///
    /// This has the lowest performance overhead but will silently truncate
    /// strings at the first null byte. Use only when you're certain your
    /// keys won't contain null bytes.
    case assumeAbsent

    /// Apply percent-encoding to null bytes before encoding.
    ///
    /// This ensures strings with embedded null bytes round-trip correctly,
    /// at the cost of some encoding overhead. This is the default strategy.
    case percentEscape
  }

}

// MARK: - Synthesized Conformances

extension XPCEncoder.StringKeyStrategy: Sendable { }
extension XPCEncoder.StringKeyStrategy: Equatable { }
extension XPCEncoder.StringKeyStrategy: Hashable { }
extension XPCEncoder.StringKeyStrategy: Codable { }
extension XPCEncoder.StringKeyStrategy: CaseIterable { }

// MARK: - CustomStringConvertible

extension XPCEncoder.StringKeyStrategy: CustomStringConvertible {
  public var description: String {
    switch self {
    case .assumeAbsent:
      "assume absent"
    case .percentEscape:
      "%-escape"
    }
  }
}

// MARK: - CustomDebugStringConvertible

extension XPCEncoder.StringKeyStrategy: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .assumeAbsent:
      "\(Self.self).assumeAbsent"
    case .percentEscape:
      "\(Self.self).percentEscape"
    }
  }
}

// MARK: - Well-Known Values

extension XPCEncoder.StringKeyStrategy {

  /// The standard (default) strategy for encoding string keys.
  @usableFromInline
  static let standard: Self = XPCCodec.StringKeyStrategy.standard.encodingStrategy

}

// MARK: - EmbeddedNullByteRepresentation

extension XPCEncoder.StringKeyStrategy {

  @usableFromInline
  internal var embeddedNullByteRepresentation: String.EmbeddedNullByteRepresentation {
    switch self {
    case .assumeAbsent:
      .passthrough
    case .percentEscape:
      .percentEscaped
    }
  }

}

// MARK: - From XPCCodec

extension XPCCodec.StringKeyStrategy {
  
  @usableFromInline
  internal var encodingStrategy: XPCEncoder.StringKeyStrategy {
    switch self {
    case .assumeAbsent:
      .assumeAbsent
    case .percentEscape:
      .percentEscape
    }
  }
  
}

