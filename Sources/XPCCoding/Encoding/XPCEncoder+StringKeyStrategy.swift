import Foundation
import XPC

extension XPCEncoder {
  
  public enum StringKeyStrategy {
    case assumeAbsent
    case percentEscape
  }

}

extension XPCEncoder.StringKeyStrategy: Sendable { }
extension XPCEncoder.StringKeyStrategy: Equatable { }
extension XPCEncoder.StringKeyStrategy: Hashable { }
extension XPCEncoder.StringKeyStrategy: Codable { }
extension XPCEncoder.StringKeyStrategy: CaseIterable { }

extension XPCEncoder.StringKeyStrategy {
  
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

