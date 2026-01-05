import Foundation
import XPC
import Combine

/// The entrypoint for *decoding* `Decodable` values from XPC objects.
///
/// `XPCDecoder` conforms to `TopLevelDecoder` and provides a direct API for decoding
/// `xpc_object_t` values into a `Decodable` Swift type.
///
/// ## Usage
///
/// ```swift
/// let decoder = XPCDecoder()
/// let value = try decoder.decode(MyType.self, from: xpcObject)
/// ```
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

  /// Decodes a value of the given type from the given XPC object.
  ///
  /// - Parameters:
  ///   - type: The type of the value to decode.
  ///   - input: The XPC object to decode from.
  /// - Returns: A value of the requested type.
  /// - Throws: An error if decoding failed.
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

// MARK: - CustomStringConvertible

extension XPCDecoder: CustomStringConvertible {
  public var description: String {
    "(string-keys: \(stringKeyStrategy), string-values: \(stringValueStrategy))"
  }
}

// MARK: - CustomStringConvertible

extension XPCDecoder: CustomDebugStringConvertible {

  public var debugDescription: String {
    "XPCDecoder(stringKeyStrategy: \(stringKeyStrategy), stringValueStrategy: \(stringValueStrategy))"
  }

}
