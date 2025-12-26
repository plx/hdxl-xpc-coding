import Foundation
import XPC
import Combine

public final class XPCDecoder: TopLevelDecoder {
  public typealias Input = xpc_object_t
    
  public var stringKeyStrategy: StringKeyStrategy
  public var stringValueStrategy: StringValueStrategy

  public static var standard: Self {
    Self()
  }
  
  public init(
    stringKeyStrategy: StringKeyStrategy = .standard,
    stringValueStrategy: StringValueStrategy = .standard
  ) {
    self.stringKeyStrategy = stringKeyStrategy
    self.stringValueStrategy = stringValueStrategy
  }

  public convenience init(configuration: XPCCodec.Configuration) {
    self.init(
      stringKeyStrategy: configuration.stringKeyStrategy.decodingStrategy,
      stringValueStrategy: configuration.stringValueStrategy.decodingStrategy
    )
  }

  @inlinable
  public func decode<T>(
    _ type: T.Type,
    from input: Input
  ) throws -> T where T : Decodable {
    let decoder = _XPCDecoder(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      decoding: input
    )
    
    return try T(from: decoder)
  }
  
}
