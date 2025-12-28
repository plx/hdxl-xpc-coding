import XPC
import Foundation

extension XPCCodec {

  public struct Configuration {
    
    public var stringKeyStrategy: StringKeyStrategy
    public var stringValueStrategy: StringValueStrategy
    
    public init(
      stringKeyStrategy: StringKeyStrategy,
      stringValueStrategy: StringValueStrategy
    ) {
      self.stringKeyStrategy = stringKeyStrategy
      self.stringValueStrategy = stringValueStrategy
    }
    
  }

}

extension XPCCodec.Configuration: Sendable { }
extension XPCCodec.Configuration: Equatable { }
extension XPCCodec.Configuration: Hashable { }
extension XPCCodec.Configuration: Codable { }
extension XPCCodec.Configuration: CaseIterable {
  
  public static let allCases: [Self] = {
    var result: [Self] = []
    let stringKeyStrategies = XPCCodec.StringKeyStrategy.allCases
    let stringValueStrategies = XPCCodec.StringValueStrategy.allCases
    result.reserveCapacity(stringKeyStrategies.count * stringValueStrategies.count)
    for stringKeyStrategy in stringKeyStrategies {
      for stringValueStrategy in stringValueStrategies {
        result.append(
          Self(
            stringKeyStrategy: stringKeyStrategy,
            stringValueStrategy: stringValueStrategy
          )
        )
      }
    }
    
    return result
  }()
}
