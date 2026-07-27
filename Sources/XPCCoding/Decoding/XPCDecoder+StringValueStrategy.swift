import Foundation
import XPC
import Combine

// MARK: XPCDecoder.StringValueStrategy

extension XPCDecoder {

  /// The strategy for handling encoded null bytes in string values during decoding.
  ///
  /// This strategy must match the encoding strategy used when the data was created
  /// to ensure correct round-tripping of string values.
  public enum StringValueStrategy {

    /// Decode string values directly without any transformation.
    ///
    /// Use this when values were encoded with ``XPCEncoder/StringValueStrategy/assumeAbsent``
    /// or ``XPCEncoder/StringValueStrategy/throwOnDiscovery`` and are known not to
    /// contain any encoded null bytes.
    case passthrough

    /// Decode XPCCoding percent escapes in string values.
    ///
    /// Use this when values were encoded with ``XPCEncoder/StringValueStrategy/percentEscape``.
    /// Only `%00` (null) and `%25` (literal percent) are accepted; malformed,
    /// dangling, and unsupported escapes are rejected. This is the default
    /// strategy.
    case percentEscape

    /// Decode strings from binary data using the specified encoding.
    ///
    /// Use this when values were encoded with
    /// ``XPCEncoder/StringValueStrategy/useDataRepresentation(_:)``. The encoding
    /// must match the one used during encoding.
    case useDataRepresentation(XPCCodec.StringValueDataRepresentation)
  }

}

// MARK: - Synthesized Conformances

extension XPCDecoder.StringValueStrategy: Sendable { }
extension XPCDecoder.StringValueStrategy: Equatable { }
extension XPCDecoder.StringValueStrategy: Hashable { }
extension XPCDecoder.StringValueStrategy: Codable { }

// MARK: - CaseIterable

extension XPCDecoder.StringValueStrategy: CaseIterable {

  /// Every string-value decoding strategy, including one
  /// ``XPCDecoder/StringValueStrategy/useDataRepresentation(_:)`` case per
  /// ``XPCCodec/StringValueDataRepresentation``.
  ///
  /// The order is an implementation detail; treat this as a set. It exists so
  /// exhaustive tests and configuration UIs can enumerate the strategies
  /// despite the associated-value case.
  static public let allCases: [Self] = {
    [
      .passthrough,
      .percentEscape
    ] + XPCCodec.StringValueDataRepresentation.allCases.map {
      Self.useDataRepresentation($0)
    }
  }()

}

// MARK: - CustomStringConvertible

extension XPCDecoder.StringValueStrategy: CustomStringConvertible {

  /// A brief, human-readable name for the string-value decoding strategy.
  ///
  /// - Note: Intended for diagnostics and logging. The exact text is not API
  ///   and must not be parsed.
  public var description: String {
    switch self {
    case .passthrough:
      "passthrough"
    case .percentEscape:
      "%-escape"
    case .useDataRepresentation(let representation):
      "\(representation)-data"
    }
  }

}

extension XPCDecoder.StringValueStrategy: CustomDebugStringConvertible {

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
    case .useDataRepresentation(let representation):
      "\(Self.self).useDataRepresentation(\(String(reflecting: representation)))"
    }
  }
  
}

// MARK: - Well-Known Values

extension XPCDecoder.StringValueStrategy {

  /// The standard (default) strategy for decoding string values.
  public static let standard: Self = XPCCodec.StringValueStrategy.standard.decodingStrategy

}

// MARK: - From XPCCodec.StringValueStrategy

extension XPCCodec.StringValueStrategy {
  
  internal var decodingStrategy: XPCDecoder.StringValueStrategy {
    switch self {
    case .assumeAbsent:
      .passthrough
    case .throwOnDiscovery:
      .passthrough
    case .percentEscape:
      .percentEscape
    case .useDataRepresentation(let representation):
      .useDataRepresentation(representation)
    }
  }
  
}
