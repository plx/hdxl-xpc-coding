import Foundation
import XPC

extension XPCEncoder {

  /// The strategy for handling embedded null bytes in string keys during encoding.
  ///
  /// XPC only supports C-style null-terminated strings for dictionary keys.
  /// This strategy controls how the encoder handles Swift strings that contain
  /// embedded null bytes.
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

extension XPCEncoder.StringKeyStrategy: Sendable { }
extension XPCEncoder.StringKeyStrategy: Equatable { }
extension XPCEncoder.StringKeyStrategy: Hashable { }
extension XPCEncoder.StringKeyStrategy: Codable { }
extension XPCEncoder.StringKeyStrategy: CaseIterable { }

extension XPCEncoder.StringKeyStrategy {

  /// The standard (default) strategy for encoding string keys.
  @usableFromInline
  static let standard: Self = XPCCodec.StringKeyStrategy.standard.encodingStrategy

}

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

