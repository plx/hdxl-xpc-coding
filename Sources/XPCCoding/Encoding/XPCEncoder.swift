import Foundation
import XPC
import Combine

// MARK: XPCEncoder

/// The entrypoint for *encoding* `Encodable` values into XPC objects.
///
/// `XPCEncoder` conforms to `TopLevelEncoder`, which provides a standarized API 
/// for encoding top-level values into encoder's native output format (XPC objects, here).
/// 
/// This class is *not* an `Encoder` itself—it's a facade that handles provisinion 
/// the actual underlying `Encoder`-conformaing object. 
/// 
/// ## Usage
///
/// ```swift
/// let encoder = XPCEncoder()
/// let xpcObject = try encoder.encode(myValue)
/// ```
///
public final class XPCEncoder: TopLevelEncoder {
  public typealias Output = xpc_object_t

  /// The strategy for handling embedded null bytes in string keys.
  public var stringKeyStrategy: StringKeyStrategy

  /// The strategy for handling embedded null bytes in string values.
  public var stringValueStrategy: StringValueStrategy

  /// An encoder with the standard (default) configuration.
  public static var standard: Self {
    Self()
  }

  /// Creates a new encoder with the specified strategies.
  ///
  /// - Parameters:
  ///   - stringKeyStrategy: The strategy for handling null bytes in string keys. Defaults to ``StringKeyStrategy/percentEscape``.
  ///   - stringValueStrategy: The strategy for handling null bytes in string values. Defaults to ``StringValueStrategy/percentEscape``.
  public init(
    stringKeyStrategy: StringKeyStrategy = .standard,
    stringValueStrategy: StringValueStrategy = .standard
  ) {
    self.stringKeyStrategy = stringKeyStrategy
    self.stringValueStrategy = stringValueStrategy
  }

  /// Creates a new encoder from an ``XPCCodec/Configuration``.
  ///
  /// - Parameter configuration: The codec configuration to derive encoder settings from.
  public convenience init(configuration: XPCCodec.Configuration) {
    self.init(
      stringKeyStrategy: configuration.stringKeyStrategy.encodingStrategy,
      stringValueStrategy: configuration.stringValueStrategy.encodingStrategy
    )
  }

  /// Encodes an encodable value into an `xpc_object_t`.
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

// MARK: - CustomStringConvertible

extension XPCEncoder: CustomStringConvertible {
  public var description: String {
    "(string-keys: \(stringKeyStrategy), string-values: \(stringValueStrategy))"
  }
}

// MARK: - CustomStringConvertible

extension XPCEncoder: CustomDebugStringConvertible {

  public var debugDescription: String {
    "XPCEncoder(stringKeyStrategy: \(stringKeyStrategy), stringValueStrategy: \(stringValueStrategy))"
  }

}
