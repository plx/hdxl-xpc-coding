
// MARK: XPCCodec.StringKeyStrategy

extension XPCCodec {

  /// Used to control how the XPC coders should handle strings with embedded null bytes.
  ///
  /// The motivating issue is a mismatch between string representations at the Swift level
  /// and the string representations used by XPC:
  ///
  /// - Swift's internal representation can include null bytes w/out issue
  /// - XPC *only* supports C-style null-terminated strings (and thus *cannot* handle embedded null bytes)
  ///
  /// As such, encoding to XPC requires care around embedded null bytes, especially since
  /// other encoders and decoders handle them correctly (e.g. `JSONEncoder`, `JSONDecoder`).
  ///
  /// This enumeration describes the *strategies* we support vis-a-vis string keys and string values.
  public enum StringKeyStrategy {
    
    /// Encoders will take a naive approach, and skip over any null-byte checks.
    ///
    /// This has the lowest performance impact, but will encode truncated values
    /// when encoding keys or values with embedded null bytes...use with caution.
    case assumeAbsent
    
    /// Encoders will throw an error on discovering embedded null bytes.
    ///
    /// This has zero space overhead on success, at cost of being unable to handle
    /// any strings with embedded null bytes—use at your own risk.
    case throwOnDiscovery
    
    /// Apply percent-escaping to prevent XPC from seeing null bytes.
    ///
    /// This is less-efficient than the "modified utf-8" approach, but has
    /// the benefit that even the escaped values will also be valid UTF-8.
    ///
    /// This configuration is the default for keys and values.
    case percentEscape
  }
}

// MARK: - Synthesized Conformances

extension XPCCodec.StringKeyStrategy: Sendable { }
extension XPCCodec.StringKeyStrategy: Equatable { }
extension XPCCodec.StringKeyStrategy: Hashable { }
extension XPCCodec.StringKeyStrategy: Codable { }
extension XPCCodec.StringKeyStrategy: CaseIterable { }

// MARK: - CustomStringConvertible

extension XPCCodec.StringKeyStrategy: CustomStringConvertible {
  
  public var description: String {
    switch self {
    case .assumeAbsent: "assume absent"
    case .throwOnDiscovery: "throw on discovery"
    case .percentEscape: "%-escape"
    }
  }
  
}

// MARK: - CustomDebugStringConvertible

extension XPCCodec.StringKeyStrategy: CustomDebugStringConvertible {
  
  public var debugDescription: String {
    switch self {
    case .assumeAbsent: ".assumeAbsent"
    case .throwOnDiscovery: ".throwOnDiscovery"
    case .percentEscape: ".percentEscape"
    }
  }
  
}

extension XPCCodec.StringKeyStrategy {
  
  /// "Standard" null-byte strategy for encoding and decoding.
  public static let standard: Self = .percentEscape
  
}
