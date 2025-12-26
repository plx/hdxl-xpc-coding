import XPC

public struct XPCCodec {
  
  public let encoder: XPCEncoder
  public let decoder: XPCDecoder
  
  public let configuration: Configuration
  
  public var stringKeyStrategy: StringKeyStrategy { configuration.stringKeyStrategy }
  public var stringValueStrategy: StringValueStrategy { configuration.stringValueStrategy }
  
  @usableFromInline
  internal init(
    encoder: XPCEncoder,
    decoder: XPCDecoder,
    configuration: Configuration
  ) {
    self.encoder = encoder
    self.decoder = decoder
    self.configuration = configuration
  }
  
  public init(configuration: Configuration) {
    self.init(
      encoder: XPCEncoder(configuration: configuration),
      decoder: XPCDecoder(configuration: configuration),
      configuration: configuration
    )
  }

}

extension XPCCodec {
  
  @inlinable
  public func encode<T>(_ value: T) throws -> xpc_object_t where T: Encodable {
    try encoder.encode(value)
  }

  @inlinable
  public func decode<T>(
    _ valueType: T.Type,
    from object: xpc_object_t
  ) throws -> T where T: Decodable {
    try decoder.decode(
      valueType,
      from: object
    )
  }

}
