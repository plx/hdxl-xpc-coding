// MARK: XPCCodec.StringValueStrategy

extension XPCCodec {

  /// Used to control how the XPC coders should handle *string values* with embedded null bytes.
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
  public enum StringValueStrategy {

    /// Encoders will take a naive approach, and skip over any null-byte checks.
    ///
    /// This has the lowest performance impact, but will encode truncated values
    /// when encoding keys or values with embedded null bytes...use with caution.
    case assumeAbsent

    /// Encoders will throw an error on discovering embedded null bytes.
    ///
    /// This has zero space overhead on success, at cost of being unable to handle
    /// any strings with embedded null bytes. Discovery produces
    /// `EncodingError.invalidValue` at the string's exact value path, with the
    /// low-level conversion cause retained as `underlyingError`.
    case throwOnDiscovery

    /// Apply XPCCoding's reversible percent-escape grammar.
    ///
    /// Null scalars become `%00` and literal percent scalars become `%25`,
    /// producing an injective XPC string representation that remains UTF-8.
    ///
    /// This configuration is the default for keys and values.
    case percentEscape

    /// Represent strings as binary data, not as an xpc string.
    case useDataRepresentation(StringValueDataRepresentation)

  }

}

// MARK: - Synthesized Conformances

extension XPCCodec.StringValueStrategy: Sendable {}
extension XPCCodec.StringValueStrategy: Equatable {}
extension XPCCodec.StringValueStrategy: Hashable {}
extension XPCCodec.StringValueStrategy: Codable {}

// MARK: - CaseIterable

extension XPCCodec.StringValueStrategy: CaseIterable {

  /// Every string-value strategy, including one
  /// ``XPCCodec/StringValueStrategy/useDataRepresentation(_:)`` case per
  /// ``XPCCodec/StringValueDataRepresentation``.
  ///
  /// The order is an implementation detail; treat this as a set. It exists so
  /// exhaustive tests and configuration UIs can enumerate the strategies
  /// despite the associated-value case.
  static public let allCases: [Self] = {
    [
      .assumeAbsent,
      .throwOnDiscovery,
      .percentEscape,
    ]
      + XPCCodec.StringValueDataRepresentation.allCases.map {
        Self.useDataRepresentation($0)
      }
  }()

}

// MARK: - CustomStringConvertible

extension XPCCodec.StringValueStrategy: CustomStringConvertible {

  /// A brief, human-readable name for the string-value strategy.
  ///
  /// - Note: Intended for diagnostics and logging. The exact text is not API
  ///   and must not be parsed.
  public var description: String {
    switch self {
    case .assumeAbsent: "assume absent"
    case .throwOnDiscovery: "throw on discovery"
    case .percentEscape: "%-escape"
    case .useDataRepresentation(let representation): "represent as \(representation.description)"
    }
  }

}

// MARK: - CustomDebugStringConvertible

extension XPCCodec.StringValueStrategy: CustomDebugStringConvertible {

  /// A developer-facing description naming the case in source-like form.
  ///
  /// - Note: Intended for diagnostics and logging. The exact text is not API
  ///   and must not be parsed.
  public var debugDescription: String {
    switch self {
    case .assumeAbsent: ".assumeAbsent"
    case .throwOnDiscovery: ".throwOnDiscovery"
    case .percentEscape: ".percentEscape"
    case .useDataRepresentation(let representation): ".useDataRepresentation(\(representation.debugDescription))"
    }
  }

}

extension XPCCodec.StringValueStrategy {

  /// "Standard" null-byte strategy for encoding and decoding.
  public static let standard: Self = .percentEscape

}
