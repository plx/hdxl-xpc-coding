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
/// `XPCDecoder` is mutable and does not conform to `Sendable`. Keep each
/// instance confined to one task. Share an immutable ``XPCCodec`` when
/// concurrent operations need the same configuration.
///
/// ## Usage
///
/// ```swift
/// let decoder = XPCDecoder()
/// let value = try decoder.decode(MyType.self, from: xpcObject)
/// ```
///
/// ## Decoding failures
///
/// XPCCoding reports its own representation failures through the standard
/// `DecodingError` taxonomy at the most-specific available coding path:
///
/// - an absent keyed value is `DecodingError.keyNotFound`;
/// - explicit XPC null requested as a nonoptional value is
///   `DecodingError.valueNotFound`;
/// - the wrong XPC object kind is `DecodingError.typeMismatch`; and
/// - a correct-kind representation with invalid length, range, content, text
///   encoding, percent-escape grammar, or exhausted resource limits is
///   `DecodingError.dataCorrupted`.
///
/// Low-level malformed-content causes may be retained as the error context's
/// `underlyingError`, but XPCCoding's internal errors are never thrown from
/// this facade. Errors thrown directly by a type's `Decodable` implementation
/// propagate unchanged.
public final class XPCDecoder: TopLevelDecoder {

  /// The `TopLevelDecoder` input type: an XPC object tree.
  ///
  /// The object kinds and values XPCCoding accepts are described by the
  /// repository's XPC object representation contract
  /// (`reference/WireFormat.md`). Supported input is an object produced by the
  /// same compilation cohort — peers built from the same XPCCoding revision,
  /// toolchain, models, and configuration, and deployed together. Objects from
  /// another XPCCoding release, from persistence, or from an independently
  /// versioned peer are out of scope. They may fail with the `DecodingError`
  /// taxonomy documented on ``XPCDecoder`` or may happen to decode; neither
  /// outcome is a compatibility guarantee.
  public typealias Input = xpc_object_t

  /// The strategy for handling encoded null bytes in string keys.
  public var stringKeyStrategy: StringKeyStrategy

  /// The strategy for handling encoded null bytes in string values.
  public var stringValueStrategy: StringValueStrategy

  /// Contextual values made available to each `Decodable` value.
  ///
  /// The dictionary is shallow-copied when a decoding operation begins and is
  /// never read from the XPC object. Reference-valued entries therefore
  /// preserve their identity. Mutating this task-confined facade during an
  /// active operation is unsupported; mutations between operations affect only
  /// subsequent operations.
  public var userInfo: [CodingUserInfoKey: Any]

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
    self.userInfo = [:]
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
  /// - Throws: XPCCoding-originated representation failures use the standard
  ///   `DecodingError` taxonomy documented on ``XPCDecoder``. Errors thrown
  ///   directly by `T` propagate unchanged.
  public func decode<T>(
    _ type: T.Type,
    from input: Input
  ) throws -> T where T: Decodable {
    let stringKeyStrategy = stringKeyStrategy
    let stringValueStrategy = stringValueStrategy
    let resourceLimits = resourceLimits
    let userInfo = userInfo
    return try _XPCDecoder.decode(
      type,
      from: input,
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      resourceLimits: resourceLimits,
      userInfo: userInfo
    )
  }

}

// MARK: - CustomStringConvertible

extension XPCDecoder: CustomStringConvertible {

  /// A brief, human-readable summary of the decoder's strategies and limits.
  ///
  /// - Note: Intended for diagnostics and logging. The exact text is not API
  ///   and must not be parsed.
  public var description: String {
    """
    (string-keys: \(stringKeyStrategy), string-values: \(stringValueStrategy), \
    resource-limits: \(resourceLimits))
    """
  }
}

// MARK: - CustomStringConvertible

extension XPCDecoder: CustomDebugStringConvertible {

  /// A developer-facing description naming the decoder's strategies and limits.
  ///
  /// - Note: Intended for diagnostics and logging. The exact text is not API
  ///   and must not be parsed.
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
