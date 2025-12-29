import Foundation
import XPC

extension XPCEncoder {

  /// The strategy for handling embedded null bytes in string values during encoding.
  ///
  /// XPC only supports C-style null-terminated strings. This strategy controls how
  /// the encoder handles Swift strings that contain embedded null bytes.
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
    /// and receive an error rather than silent truncation.
    case throwOnDiscovery

    /// Apply percent-encoding to null bytes before encoding.
    ///
    /// This ensures strings with embedded null bytes round-trip correctly,
    /// at the cost of some encoding overhead. This is the default strategy.
    case percentEscape

    /// Encode strings as binary data using the specified encoding.
    ///
    /// This bypasses the XPC string type entirely by encoding strings as
    /// `xpc_data_t` in the specified Unicode encoding. Use this when you
    /// need to preserve arbitrary string content without escaping.
    case useDataRepresentation(XPCCodec.StringValueDataRepresentation)
  }

}

extension XPCEncoder.StringValueStrategy: Sendable { }
extension XPCEncoder.StringValueStrategy: Equatable { }
extension XPCEncoder.StringValueStrategy: Hashable { }
extension XPCEncoder.StringValueStrategy: Codable { }
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

extension XPCEncoder.StringValueStrategy {

  /// The standard (default) strategy for encoding string values.
  @usableFromInline
  static let standard: Self = XPCCodec.StringValueStrategy.standard.encodingStrategy

}

extension XPCCodec.StringValueStrategy {
  
  @usableFromInline
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
