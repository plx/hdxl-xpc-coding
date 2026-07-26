// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

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

  /// Finite resource limits applied independently to each call to ``decode(_:from:)``.
  ///
  /// The value is snapshotted when decoding begins. Mutating this property
  /// therefore affects subsequent operations, never an operation already in
  /// progress.
  public var resourceLimits: ResourceLimits

  /// A decoder with the standard (default) configuration.
  public static var standard: Self {
    Self()
  }

  /// Creates a new decoder with the specified strategies.
  ///
  /// - Parameters:
  ///   - stringKeyStrategy: The strategy for handling null bytes in string keys. Defaults to ``StringKeyStrategy/standard``.
  ///   - stringValueStrategy: The strategy for handling null bytes in string values. Defaults to ``StringValueStrategy/standard``.
  ///   - resourceLimits: The finite limits for each decode operation. Defaults to ``ResourceLimits/standard``.
  public init(
    stringKeyStrategy: StringKeyStrategy = .standard,
    stringValueStrategy: StringValueStrategy = .standard,
    resourceLimits: ResourceLimits = .standard
  ) {
    self.stringKeyStrategy = stringKeyStrategy
    self.stringValueStrategy = stringValueStrategy
    self.resourceLimits = resourceLimits
  }

  /// Creates a new decoder from an ``XPCCodec/Configuration``.
  ///
  /// - Parameters:
  ///   - configuration: The codec configuration to derive string settings from.
  ///   - resourceLimits: The finite limits for each decode operation.
  public convenience init(
    configuration: XPCCodec.Configuration,
    resourceLimits: ResourceLimits = .standard
  ) {
    self.init(
      stringKeyStrategy: configuration.stringKeyStrategy.decodingStrategy,
      stringValueStrategy: configuration.stringValueStrategy.decodingStrategy,
      resourceLimits: resourceLimits
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
  ) throws -> T where T: Decodable {
    let decodingState = _XPCDecodingState(limits: resourceLimits)
    try decodingState.prepareToVisit(
      atDepth: 0,
      codingPath: []
    )

    let decoder = _XPCDecoder(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      decoding: input,
      decodingState: decodingState,
      depth: 0
    )

    if let data = try decoder.decodeVisitedDataIfRequested(
      type,
      from: input,
      at: []
    ) {
      return data
    }

    return try T(from: decoder)
  }

}

// MARK: - CustomStringConvertible

extension XPCDecoder: CustomStringConvertible {
  public var description: String {
    """
    (string-keys: \(stringKeyStrategy), string-values: \(stringValueStrategy), \
    resource-limits: \(resourceLimits))
    """
  }
}

// MARK: - CustomStringConvertible

extension XPCDecoder: CustomDebugStringConvertible {

  public var debugDescription: String {
    """
    XPCDecoder(
      stringKeyStrategy: \(stringKeyStrategy),
      stringValueStrategy: \(stringValueStrategy),
      resourceLimits: \(resourceLimits.debugDescription)
    )
    """
  }

}
