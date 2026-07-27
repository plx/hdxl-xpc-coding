import Foundation
import XPC

// MARK: XPCDecoder.StringKeyStrategy

extension XPCDecoder {

  /// The strategy for handling encoded null bytes in string keys during decoding.
  public enum StringKeyStrategy {

    /// Decode string keys directly without any transformation.
    ///
    /// Use this when keys were encoded with ``XPCEncoder/StringKeyStrategy/assumeAbsent``
    /// and are known not to contain any encoded null bytes.
    case passthrough

    /// Decode XPCCoding percent escapes in string keys.
    ///
    /// Use this when keys were encoded with ``XPCEncoder/StringKeyStrategy/percentEscape``.
    /// Only `%00` (null) and `%25` (literal percent) are accepted; malformed,
    /// dangling, and unsupported escapes are rejected. This is the default
    /// strategy.
    case percentEscape
  }

}

// MARK: - Synthesized Conformances

extension XPCDecoder.StringKeyStrategy: Sendable { }
extension XPCDecoder.StringKeyStrategy: Equatable { }
extension XPCDecoder.StringKeyStrategy: Hashable { }
extension XPCDecoder.StringKeyStrategy: Codable { }

// MARK: - CaseIterable

extension XPCDecoder.StringKeyStrategy: CaseIterable { }

// MARK: - CustomStringConvertible

extension XPCDecoder.StringKeyStrategy: CustomStringConvertible {

  /// A brief, human-readable name for the string-key decoding strategy.
  ///
  /// - Note: Intended for diagnostics and logging. The exact text is not API
  ///   and must not be parsed.
  public var description: String {
    switch self {
    case .passthrough:
      "passthrough"
    case .percentEscape:
      "%-escape"
    }
  }
}

// MARK: - CustomDebugStringConvertible

extension XPCDecoder.StringKeyStrategy: CustomDebugStringConvertible {

  /// A developer-facing description naming the case in source-like form.
  ///
  /// - Note: Intended for diagnostics and logging. The exact text is not API
  ///   and must not be parsed.
  public var debugDescription: String {
    switch self {
    case .passthrough:
      "\(Self.self).passthrough"
    case .percentEscape:
      "\(Self.self).percentEscape"
    }
  }
}

// MARK: - Well-Known Values

extension XPCDecoder.StringKeyStrategy {

  /// The standard (default) strategy for decoding string keys.
  public static let standard: Self = XPCCodec.StringKeyStrategy.standard.decodingStrategy
  
  internal var embeddedNullByteRepresentation: String.EmbeddedNullByteRepresentation {
    switch self {
    case .passthrough:
      .passthrough
    case .percentEscape:
      .percentEscaped
    }
  }
  
}

// MARK: - From XPCCodec

extension XPCCodec.StringKeyStrategy {
  
  internal var decodingStrategy: XPCDecoder.StringKeyStrategy {
    switch self {
    case .assumeAbsent:
      .passthrough
    case .percentEscape:
      .percentEscape
    }
  }
  
}
