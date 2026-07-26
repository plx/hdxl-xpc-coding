// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC
import Combine

// MARK: XPCEncoder

/// The entrypoint for *encoding* `Encodable` values into XPC objects.
///
/// `XPCEncoder` conforms to `TopLevelEncoder`, which provides a standardized API
/// for encoding top-level values into encoder's native output format (XPC objects, here).
///
/// This class is *not* an `Encoder` itself—it's a facade that provisions the
/// actual underlying `Encoder`-conforming object.
///
/// `XPCEncoder` is mutable and does not conform to `Sendable`. Keep each
/// instance confined to one task. Share an immutable ``XPCCodec`` when
/// concurrent operations need the same configuration.
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

  /// Contextual values made available to each `Encodable` value.
  ///
  /// The dictionary is shallow-copied when an encoding operation begins and is
  /// not serialized into the XPC object. Reference-valued entries therefore
  /// preserve their identity. Mutating this task-confined facade during an
  /// active operation is unsupported; mutations between operations affect only
  /// subsequent operations.
  public var userInfo: [CodingUserInfoKey: Any]

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
    self.userInfo = [:]
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
  ) throws -> Output where T: Encodable {
    let stringKeyStrategy = stringKeyStrategy
    let stringValueStrategy = stringValueStrategy
    let userInfo = userInfo
    return try _XPCEncoder.encode(
      value,
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      userInfo: userInfo
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
    let stringKeyStrategy = stringKeyStrategy
    let stringValueStrategy = stringValueStrategy
    let userInfo = userInfo
    let encoder = _XPCEncoder(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      codingPath: [],
      userInfo: userInfo
    )
    try closure(encoder)
    guard let result = encoder.topLevelContainer else {
      throw TransientEncoderError.noEncodingOccurred
    }
    return result
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

// MARK: - TransientEncoderError

/// Errors that can occur when using ``XPCEncoder/withTransientEncoder(_:)``.
public enum TransientEncoderError: Error {

  /// The closure provided to ``XPCEncoder/withTransientEncoder(_:)`` did not encode any value.
  case noEncodingOccurred
}
