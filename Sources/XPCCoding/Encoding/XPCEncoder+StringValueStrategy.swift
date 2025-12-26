import Foundation
import XPC

extension XPCEncoder {
  
  public enum StringValueStrategy {
    case assumeAbsent
    case throwOnDiscovery
    case percentEscape
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
