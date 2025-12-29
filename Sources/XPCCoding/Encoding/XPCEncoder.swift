import Foundation
import XPC
import Combine

/// An encoder that encodes `Codable` values to `xpc_object_t`.
///
/// `XPCEncoder` conforms to `TopLevelEncoder` and can be used with Combine publishers.
/// It handles the conversion of Swift types to their XPC equivalents, including special
/// handling for strings that may contain embedded null bytes.
///
/// ## Usage
///
/// ```swift
/// let encoder = XPCEncoder()
/// let xpcObject = try encoder.encode(myValue)
/// ```
///
/// ## String Handling
///
/// Because XPC only supports C-style null-terminated strings, Swift strings containing
/// embedded null bytes require special handling. Configure this behavior using
/// ``stringKeyStrategy`` and ``stringValueStrategy``.
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
  ///   - stringKeyStrategy: The strategy for handling null bytes in string keys. Defaults to ``StringKeyStrategy/standard``.
  ///   - stringValueStrategy: The strategy for handling null bytes in string values. Defaults to ``StringValueStrategy/standard``.
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

  /// Provides direct access to the underlying `Encoder` for manual encoding operations.
  ///
  /// Use this method when you need to perform encoding operations that don't fit the
  /// standard `Encodable` pattern. The closure receives an `Encoder` instance that you
  /// can use to manually encode values.
  ///
  /// - Parameter closure: A closure that performs encoding operations using the provided encoder.
  /// - Returns: The encoded `xpc_object_t`.
  /// - Throws: ``TransientEncoderError/noEncodingOccurred`` if the closure doesn't encode anything,
  ///   or any error thrown by the closure.
  @inlinable
  public func withTransientEncoder(_ closure: (any Encoder) throws -> Void) throws -> Output {
    let encoder = _XPCEncoder(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      codingPath: []
    )
    try closure(encoder)
    guard let result = encoder.topLevelContainer else {
      throw TransientEncoderError.noEncodingOccurred
    }
    return result
  }

}

/// Errors that can occur when using ``XPCEncoder/withTransientEncoder(_:)``.
public enum TransientEncoderError: Error {

  /// The closure provided to ``XPCEncoder/withTransientEncoder(_:)`` did not encode any value.
  case noEncodingOccurred
}
