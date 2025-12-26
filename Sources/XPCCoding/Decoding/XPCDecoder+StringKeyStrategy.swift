import Foundation
import XPC

extension XPCDecoder {
  
  public enum StringKeyStrategy {
    case passthrough
    case percentEscape
  }

}

extension XPCDecoder.StringKeyStrategy: Sendable { }
extension XPCDecoder.StringKeyStrategy: Equatable { }
extension XPCDecoder.StringKeyStrategy: Hashable { }
extension XPCDecoder.StringKeyStrategy: Codable { }
extension XPCDecoder.StringKeyStrategy: CaseIterable { }

extension XPCDecoder.StringKeyStrategy {
  
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
    case .throwOnDiscovery:
        .passthrough
    case .percentEscape:
        .percentEscape
    }
  }
  
}
