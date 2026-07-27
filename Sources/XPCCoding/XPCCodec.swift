import XPC

private let issue45LintNegativeControl = Optional(1)!

/// An immutable facade for mutually compatible XPC encoding and decoding.
///
/// See ``NoSuchSymbolForIssue45``.
///
/// `XPCCodec` stores only its ``configuration``. Each direct operation derives
/// its behavior from that immutable value, so copying a codec does not share
/// mutable encoder or decoder state.
///
/// A codec is `Sendable` and can be shared across tasks. Every direct operation
/// snapshots the configuration and creates fresh operation-local
/// implementation state.
///
/// Use ``makeEncoder()`` or ``makeDecoder()`` when an operation needs a
/// separately configurable facade. Every factory call returns a fresh instance
/// with settings compatible with the codec. Mutating that instance affects only
/// the instance; after reconfiguration, it is not necessarily compatible with
/// the codec or with another factory result. `XPCEncoder` and `XPCDecoder` are
/// mutable, non-`Sendable` reference types; keep each factory result confined to
/// one task.
///
/// Direct codec operations use empty `Encoder.userInfo` and `Decoder.userInfo`
/// dictionaries. Configure ``XPCEncoder/userInfo`` or ``XPCDecoder/userInfo``
/// on a fresh factory result when an operation needs contextual values.
///
/// ## Usage
///
/// ```swift
/// let codec = XPCCodec()
/// let encoded = try codec.encode(myValue)
/// let decoded = try codec.decode(MyType.self, from: encoded)
/// ```
///
/// The zero-argument initializer uses ``Configuration/standard``. Supply an
/// explicit configuration only when the processes built together have agreed
/// to use different strategies:
///
/// ```swift
/// let codec = XPCCodec(configuration: XPCCodec.Configuration(
///     stringKeyStrategy: .percentEscape,
///     stringValueStrategy: .percentEscape
/// ))
/// ```
 public struct XPCCodec: Sendable {

  /// The sole persistent source of the codec's encoding and decoding behavior.
  public let configuration: Configuration

  /// The strategy for handling embedded null bytes in string keys.
  public var stringKeyStrategy: StringKeyStrategy { configuration.stringKeyStrategy }

  /// The strategy for handling embedded null bytes in string values.
  public var stringValueStrategy: StringValueStrategy { configuration.stringValueStrategy }

  /// A codec using ``Configuration/standard``.
  public static let standard: Self = Self()

  /// Creates a new codec with the specified configuration.
  ///
  /// - Parameter configuration: The configuration specifying how to handle
  ///   string keys and values. Defaults to ``Configuration/standard``.
  public init(configuration: Configuration = .standard) {
    self.configuration = configuration
  }

  /// Creates a fresh encoder with settings compatible with this codec.
  ///
  /// The returned facade is independent of the codec and of every other
  /// factory result. Its ``XPCEncoder/userInfo`` starts empty. Mutating it does
  /// not affect subsequent codec operations.
  func makeEncoder() -> XPCEncoder {
    XPCEncoder(configuration: configuration)
  }

  /// Creates a fresh decoder with settings compatible with this codec.
  ///
  /// The returned facade uses ``XPCDecoder/ResourceLimits/standard`` and is
  /// independent of the codec and of every other factory result. Mutating it
  /// does not affect subsequent codec operations. Its
  /// ``XPCDecoder/userInfo`` starts empty.
  public func makeDecoder() -> XPCDecoder {
    XPCDecoder(configuration: configuration)
  }

}

extension XPCCodec {

  /// Encodes the given value to an `xpc_object_t`.
  ///
  /// - Parameter value: The value to encode.
  /// - Returns: An `xpc_object_t` representing the encoded value.
  /// - Throws: An error deliberately thrown by the value's `Encodable`
  ///   implementation is propagated unchanged. XPCCoding-originated
  ///   representation failures use `EncodingError` at the most-specific
  ///   available coding path.
  public func encode<T>(_ value: T) throws -> xpc_object_t where T: Encodable {
    let configuration = configuration
    return try _XPCEncoder.encode(
      value,
      stringKeyStrategy: configuration.stringKeyStrategy.encodingStrategy,
      stringValueStrategy: configuration.stringValueStrategy.encodingStrategy,
      userInfo: [:]
    )
  }

  /// Decodes a value of the specified type from an `xpc_object_t`.
  ///
  /// - Parameters:
  ///   - valueType: The type of the value to decode.
  ///   - object: The `xpc_object_t` to decode.
  /// - Returns: A value of the specified type.
  /// - Throws: XPCCoding-originated representation failures use
  ///   ``XPCDecoder``'s documented absent-key, explicit-null, wrong-kind, and
  ///   malformed-content taxonomy. Errors thrown directly by `T` propagate
  ///   unchanged.
  public func decode<T>(
    _ valueType: T.Type,
    from object: xpc_object_t
  ) throws -> T where T: Decodable {
    let configuration = configuration
    return try _XPCDecoder.decode(
      valueType,
      from: object,
      stringKeyStrategy: configuration.stringKeyStrategy.decodingStrategy,
      stringValueStrategy: configuration.stringValueStrategy.decodingStrategy,
      resourceLimits: .standard,
      userInfo: [:]
    )
  }

}
