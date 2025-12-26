import Foundation
import XPC
import Combine

extension XPCDecoder {
  
  public enum StringValueStrategy {
    case passthrough
    case percentEscape
    case useDataRepresentation(XPCCodec.StringValueDataRepresentation)
  }

}

extension XPCDecoder.StringValueStrategy: Sendable { }
extension XPCDecoder.StringValueStrategy: Equatable { }
extension XPCDecoder.StringValueStrategy: Hashable { }
extension XPCDecoder.StringValueStrategy: Codable { }
extension XPCDecoder.StringValueStrategy: CaseIterable {
  
  static public let allCases: [Self] = {
    [
      .passthrough,
      .percentEscape
    ] + XPCCodec.StringValueDataRepresentation.allCases.map {
      Self.useDataRepresentation($0)
    }
  }()

}

extension XPCDecoder.StringValueStrategy {
  
  public static let standard: Self = XPCCodec.StringValueStrategy.standard.decodingStrategy

}

extension XPCCodec.StringValueStrategy {
  
  @usableFromInline
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
