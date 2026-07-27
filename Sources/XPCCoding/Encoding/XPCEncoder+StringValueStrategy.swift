import Foundation
import XPC

// MARK: XPCEncoder.StringValueStrategy

extension XPCEncoder {

  /// The strategy for handling embedded null bytes in string values during encoding.
  public enum StringValueStrategy {

    /// Assume no null bytes are present and encode directly.
    ///
    /// This has the lowest performance overhead but will silently truncate
    /// strings at the first null byte. Use only when you're certain your
    /// values won't contain null bytes.
    case assumeAbsent

    /// Throw an error if a null byte is discovered during encoding.
    ///
    /// Use this when you want to explicitly forbid null bytes in string values
    /// and receive an error rather than silent truncation. Discovery produces
    /// `EncodingError.invalidValue` at the string's exact value path. The
    /// low-level conversion cause is retained as `underlyingError`.
    case throwOnDiscovery

    /// Apply XPCCoding's reversible percent-escape grammar before encoding.
    ///
    /// Every null scalar is encoded as `%00` and every literal percent scalar
    /// is encoded as `%25`. This ensures every Swift string has an injective
    /// XPC string representation. This is the default strategy.
    case percentEscape

    /// Encode strings as binary data using the specified encoding.
    ///
    /// This bypasses the XPC string type entirely by encoding strings as
    /// `xpc_data_t` in the specified Unicode encoding. Use this when you
    /// need to preserve arbitrary string content without escaping.
    case useDataRepresentation(XPCCodec.StringValueDataRepresentation)
  }

}

// MARK: - Synthesized Conformances

extension XPCEncoder.StringValueStrategy: Sendable { }
extension XPCEncoder.StringValueStrategy: Equatable { }
extension XPCEncoder.StringValueStrategy: Hashable { }
extension XPCEncoder.StringValueStrategy: Codable { }


// MARK: - CaseIterable

extension XPCEncoder.StringValueStrategy: CaseIterable {
  
  static public let allCases: [Self] = {
    [
      .assumeAbsent,
      .throwOnDiscovery,
      .percentEscape
    ] + XPCCodec.StringValueDataRepresentation.allCases.map {
      Self.useDataRepresentation($0)
    }
  }()
  
}

// MARK: - CustomStringConvertible

extension XPCEncoder.StringValueStrategy: CustomStringConvertible {
  public var description: String {
    switch self {
    case .assumeAbsent:
      "assume absent"
    case .throwOnDiscovery:
      "throw"
    case .percentEscape:
      "%-escape"
    case .useDataRepresentation(let representation):
      "\(representation)-data"
    }
  }
}

// MARK: - CustomDebugStringConvertible

extension XPCEncoder.StringValueStrategy: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .assumeAbsent:
      "\(Self.self).assumeAbsent"
    case .throwOnDiscovery:
      "\(Self.self).throwOnDiscovery"
    case .percentEscape:
      "\(Self.self).percentEscape"
    case .useDataRepresentation(let representation):
      "\(Self.self).useDataRepresentation(\(representation))"
    }
  }
}

// MARK: - Well-Known Values

extension XPCEncoder.StringValueStrategy {

  /// The standard (default) strategy for encoding string values.
  public static let standard: Self = XPCCodec.StringValueStrategy.standard.encodingStrategy

}

// MARK: - From XPCCodec

extension XPCCodec.StringValueStrategy {
  
  internal var encodingStrategy: XPCEncoder.StringValueStrategy {
    switch self {
    case .assumeAbsent:
      .assumeAbsent
    case .throwOnDiscovery:
      .throwOnDiscovery
    case .percentEscape:
      .percentEscape
    case .useDataRepresentation(let representation):
      .useDataRepresentation(representation)
    }
  }
  
}
