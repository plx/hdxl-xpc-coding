
// MARK: XPCCodec.StringKeyStrategy

extension XPCCodec {

  /// Used to control how the XPC coders should handle *string keys* with embedded null bytes.
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
        
    /// Apply XPCCoding's reversible percent-escape grammar.
    ///
    /// Null scalars become `%00` and literal percent scalars become `%25`,
    /// producing an injective XPC string representation that remains UTF-8.
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

  /// A brief, human-readable name for the string-key strategy.
  ///
  /// - Note: Intended for diagnostics and logging. The exact text is not API
  ///   and must not be parsed.
  public var description: String {
    switch self {
    case .assumeAbsent: "assume absent"
    case .percentEscape: "%-escape"
    }
  }
  
}

// MARK: - CustomDebugStringConvertible

extension XPCCodec.StringKeyStrategy: CustomDebugStringConvertible {

  /// A developer-facing description naming the case in source-like form.
  ///
  /// - Note: Intended for diagnostics and logging. The exact text is not API
  ///   and must not be parsed.
  public var debugDescription: String {
    switch self {
    case .assumeAbsent: ".assumeAbsent"
    case .percentEscape: ".percentEscape"
    }
  }
  
}

extension XPCCodec.StringKeyStrategy {
  
  /// "Standard" null-byte strategy for encoding and decoding.
  public static let standard: Self = .percentEscape
  
}
