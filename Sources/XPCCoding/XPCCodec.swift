import XPC

/// A facade that simplifies obtaining mutually-compatible ``XPCEncoder`` and ``XPCDecoder`` instances.
///
/// `XPCCodec` ensures that its encoder and decoder share the same configuration, guaranteeing
/// that values encoded with the codec's encoder can be successfully decoded by its decoder.
/// This is particularly important when dealing with strategies for handling embedded null bytes
/// in strings, where encoder/decoder configuration must match for successful round-tripping.
///
/// ## Usage
///
/// ```swift
/// let codec = XPCCodec(configuration: .init(
///     stringKeyStrategy: .percentEscape,
///     stringValueStrategy: .percentEscape
/// ))
///
/// let encoded = try codec.encode(myValue)
/// let decoded = try codec.decode(MyType.self, from: encoded)
/// ```
public struct XPCCodec {

  /// The encoder used for encoding `Codable` values to `xpc_object_t`.
  public let encoder: XPCEncoder

  /// The decoder used for decoding `xpc_object_t` to `Codable` values.
  public let decoder: XPCDecoder

  /// The configuration controlling how the codec handles string encoding.
  public let configuration: Configuration

  /// The strategy for handling embedded null bytes in string keys.
  public var stringKeyStrategy: StringKeyStrategy { configuration.stringKeyStrategy }

  /// The strategy for handling embedded null bytes in string values.
  public var stringValueStrategy: StringValueStrategy { configuration.stringValueStrategy }
  
  /// Internal field-initialization constructor.
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

  /// Creates a new codec with the specified configuration.
  ///
  /// - Parameter configuration: The configuration specifying how to handle string keys and values.
  public init(configuration: Configuration) {
    self.init(
      encoder: XPCEncoder(configuration: configuration),
      decoder: XPCDecoder(configuration: configuration),
      configuration: configuration
    )
  }

}

extension XPCCodec {

  /// Encodes the given value to an `xpc_object_t`.
  ///
  /// - Parameter value: The value to encode.
  /// - Returns: An `xpc_object_t` representing the encoded value.
  /// - Throws: An error if the value cannot be encoded.
  @inlinable
  public func encode<T>(_ value: T) throws -> xpc_object_t where T: Encodable {
    try encoder.encode(value)
  }

  /// Decodes a value of the specified type from an `xpc_object_t`.
  ///
  /// - Parameters:
  ///   - valueType: The type of the value to decode.
  ///   - object: The `xpc_object_t` to decode.
  /// - Returns: A value of the specified type.
  /// - Throws: An error if the value cannot be decoded.
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
