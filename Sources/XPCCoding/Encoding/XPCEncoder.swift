import Foundation
import XPC
import Combine

public final class XPCEncoder: TopLevelEncoder {
  public typealias Output = xpc_object_t
  
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
      stringKeyStrategy: configuration.stringKeyStrategy.encodingStrategy,
      stringValueStrategy: configuration.stringValueStrategy.encodingStrategy
    )
  }

  @inlinable
  public func encode<T>(
    _ value: T
  ) throws -> Output where T : Encodable {
    try _XPCEncoder.encode(
      value,
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy
    )
  }
  
}
