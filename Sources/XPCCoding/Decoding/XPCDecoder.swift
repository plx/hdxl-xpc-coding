import Foundation
import XPC
import Combine

/// A decoder that decodes `Codable` values from `xpc_object_t`.
///
/// `XPCDecoder` conforms to `TopLevelDecoder` and can be used with Combine publishers.
/// It handles the conversion of XPC types to their Swift equivalents, including special
/// handling for strings that may have been encoded with null-byte handling strategies.
///
/// ## Usage
///
/// ```swift
/// let decoder = XPCDecoder()
/// let value = try decoder.decode(MyType.self, from: xpcObject)
/// ```
///
/// ## String Handling
///
/// The decoder must be configured with strategies compatible with the encoder that
/// produced the XPC data. Configure this using ``stringKeyStrategy`` and
/// ``stringValueStrategy``.
public final class XPCDecoder: TopLevelDecoder {
  public typealias Input = xpc_object_t

  /// The strategy for handling encoded null bytes in string keys.
  public var stringKeyStrategy: StringKeyStrategy

  /// The strategy for handling encoded null bytes in string values.
  public var stringValueStrategy: StringValueStrategy

  /// A decoder with the standard (default) configuration.
  public static var standard: Self {
    Self()
  }

  /// Creates a new decoder with the specified strategies.
  ///
  /// - Parameters:
  ///   - stringKeyStrategy: The strategy for handling null bytes in string keys. Defaults to ``StringKeyStrategy/standard``.
  ///   - stringValueStrategy: The strategy for handling null bytes in string values. Defaults to ``StringValueStrategy/standard``.
  public init(
    stringKeyStrategy: StringKeyStrategy = .standard,
    stringValueStrategy: StringValueStrategy = .standard
  ) {
    self.stringKeyStrategy = stringKeyStrategy
    self.stringValueStrategy = stringValueStrategy
  }

  /// Creates a new decoder from an ``XPCCodec/Configuration``.
  ///
  /// - Parameter configuration: The codec configuration to derive decoder settings from.
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
