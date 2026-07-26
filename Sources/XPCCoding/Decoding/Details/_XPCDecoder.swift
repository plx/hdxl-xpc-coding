// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

/// The internal `_XPCDecoder` implementation.
@usableFromInline
internal final class _XPCDecoder: Decoder {

  @usableFromInline
  internal typealias StringKeyStrategy = XPCDecoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCDecoder.StringValueStrategy

  /// The strategy to use for decoding `String` keys.
  @usableFromInline
  internal let stringKeyStrategy: XPCDecoder.StringKeyStrategy

  /// The strategy to use for decoding `String` values.
  @usableFromInline
  internal let stringValueStrategy: XPCDecoder.StringValueStrategy

  /// The underlying XPC message.
  @usableFromInline
  internal let underlyingMessage: xpc_object_t
  
  /// The current coding path.
  @usableFromInline
  internal let codingPath: [CodingKey]

  /// The shared resource accounting for this top-level decode operation.
  @usableFromInline
  internal let decodingState: _XPCDecodingState

  /// The recursive decoding depth of `underlyingMessage` below the root object.
  @usableFromInline
  internal let depth: Int
    
  @usableFromInline
  internal let userInfo: [CodingUserInfoKey : Any]
  
  @usableFromInline
  internal init(
    stringKeyStrategy: StringKeyStrategy,
    stringValueStrategy: StringValueStrategy,
    decoding message: xpc_object_t,
    at codingPath: [CodingKey] = [],
    userInfo: [CodingUserInfoKey : Any],
    decodingState: _XPCDecodingState,
    depth: Int
  ) {
    self.stringKeyStrategy = stringKeyStrategy
    self.stringValueStrategy = stringValueStrategy
    self.underlyingMessage = message
    self.codingPath = codingPath
    self.userInfo = userInfo
    self.decodingState = decodingState
    self.depth = depth
  }

  // MARK: - Decoder

  @usableFromInline
  internal func container<Key>(
    keyedBy type: Key.Type
  ) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
    let container = try XPCKeyedDecodingContainer<Key>(
      referencing: self,
      wrapping: underlyingMessage,
      codingPath: codingPath,
      depth: depth
    )
    return KeyedDecodingContainer(container)
  }
  
  @usableFromInline
  internal func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    try XPCUnkeyedDecodingContainer(
      referencing: self,
      wrapping: underlyingMessage,
      codingPath: codingPath,
      depth: depth
    )
  }
  
  @usableFromInline
  internal func singleValueContainer() throws -> SingleValueDecodingContainer {
    XPCSingleValueDecodingContainer(
      referencing: self,
      wrapping: underlyingMessage,
      codingPath: codingPath,
      depth: depth
    )
  }
  
}

// MARK: - Support API

extension _XPCDecoder {

  /// Decodes one top-level value from a complete operation snapshot.
  @inlinable
  internal static func decode<T: Decodable>(
    _ valueType: T.Type,
    from input: xpc_object_t,
    stringKeyStrategy: StringKeyStrategy,
    stringValueStrategy: StringValueStrategy,
    resourceLimits: XPCDecoder.ResourceLimits,
    userInfo: [CodingUserInfoKey: Any]
  ) throws -> T {
    let decodingState = _XPCDecodingState(limits: resourceLimits)
    try decodingState.prepareToVisit(
      atDepth: 0,
      codingPath: []
    )

    let decoder = _XPCDecoder(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      decoding: input,
      userInfo: userInfo,
      decodingState: decodingState,
      depth: 0
    )

    if let data = try decoder.decodeVisitedDataIfRequested(
      valueType,
      from: input,
      at: []
    ) {
      return data
    }

    return try T(from: decoder)
  }

  /// Decodes `Data` through XPCCoding's one-object representation when the
  /// requested generic type is exactly `Data`.
  ///
  /// `Data`'s standard `Codable` implementation uses an unkeyed byte array.
  /// XPCCoding deliberately does not fall back to that historical accidental
  /// representation when the XPC object has the wrong kind.
  @usableFromInline
  internal func decodeVisitedDataIfRequested<T: Decodable>(
    _ valueType: T.Type,
    from object: xpc_object_t,
    at codingPath: [any CodingKey]
  ) throws -> T? {
    guard valueType is Data.Type else {
      return nil
    }
    guard object.hasType(XPC_TYPE_DATA) else {
      throw DecodingError.typeMismatch(
        Data.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
            """
            Expected Data to use XPCCoding's XPC_TYPE_DATA representation, but found \
            \(object.typeDescription). Historical unkeyed byte-array representations are not \
            supported.
            """
        )
      )
    }

    try decodingState.validateDataValue(
      object,
      codingPath: codingPath
    )
    guard let data = Data.extracting(from: object) as? T else {
      preconditionFailure("A Data metatype must accept a Data value.")
    }
    return data
  }

  /// Validates and consumes a child-object traversal.
  @usableFromInline
  internal func prepareToVisitChild(
    at codingPath: [any CodingKey],
    depth: Int
  ) throws {
    try decodingState.prepareToVisit(
      atDepth: depth,
      codingPath: codingPath
    )
  }

  /// Extracts an already-visited primitive, applying any data-byte limits first.
  @usableFromInline
  internal func extractVisitedValue<Value>(
    _ valueType: Value.Type,
    from object: xpc_object_t,
    at codingPath: [any CodingKey]
  ) throws -> Value where Value: XPCObjectExtractable {
    if
      valueType.associatedXPCObjectType == XPC_TYPE_DATA,
      object.hasType(XPC_TYPE_DATA)
    {
      try decodingState.validateDataValue(
        object,
        codingPath: codingPath
      )
    }
    return try object.extractValue(
      ofType: valueType,
      at: codingPath
    )
  }

  /// Visits and extracts one child primitive.
  @usableFromInline
  internal func extractChildValue<Value>(
    _ valueType: Value.Type,
    from object: xpc_object_t,
    at codingPath: [any CodingKey],
    depth: Int
  ) throws -> Value where Value: XPCObjectExtractable {
    try prepareToVisitChild(
      at: codingPath,
      depth: depth
    )
    return try extractVisitedValue(
      valueType,
      from: object,
      at: codingPath
    )
  }

  /// Extracts an already-visited string after checking its encoded byte count.
  @usableFromInline
  internal func extractVisitedString(
    from object: xpc_object_t,
    at codingPath: [any CodingKey]
  ) throws -> String {
    try decodingState.validateStringValue(
      object,
      strategy: stringValueStrategy,
      codingPath: codingPath
    )
    return try object.extractStringValue(
      stringValueStrategy: stringValueStrategy,
      at: codingPath
    )
  }

  /// Visits and extracts one child string.
  @usableFromInline
  internal func extractChildString(
    from object: xpc_object_t,
    at codingPath: [any CodingKey],
    depth: Int
  ) throws -> String {
    try prepareToVisitChild(
      at: codingPath,
      depth: depth
    )
    return try extractVisitedString(
      from: object,
      at: codingPath
    )
  }

  /// Decodes an already-visited generic value without duplicating node accounting.
  @usableFromInline
  internal func decodeVisitedValue<T: Decodable>(
    _ valueType: T.Type,
    from object: xpc_object_t,
    at codingPath: [any CodingKey],
    depth: Int
  ) throws -> T {
    if let data = try decodeVisitedDataIfRequested(
      valueType,
      from: object,
      at: codingPath
    ) {
      return data
    }

    if valueType is String.Type {
      let string = try extractVisitedString(
        from: object,
        at: codingPath
      )
      guard let value = string as? T else {
        preconditionFailure("A String metatype must accept a String value.")
      }
      return value
    }

    if
      let extractableType = valueType as? XPCObjectExtractable.Type,
      object.hasType(extractableType.associatedXPCObjectType)
    {
      if extractableType.associatedXPCObjectType == XPC_TYPE_DATA {
        try decodingState.validateDataValue(
          object,
          codingPath: codingPath
        )
      }
      if let extractedValue = extractableType.extracting(from: object) as? T {
        return extractedValue
      }
    }

    return try T(
      from: _XPCDecoder(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: stringValueStrategy,
        decoding: object,
        at: codingPath,
        userInfo: userInfo,
        decodingState: decodingState,
        depth: depth
      )
    )
  }

  /// Visits and decodes one child generic value.
  @usableFromInline
  internal func decodeChildValue<T: Decodable>(
    _ valueType: T.Type,
    from object: xpc_object_t,
    at codingPath: [any CodingKey],
    depth: Int
  ) throws -> T {
    try prepareToVisitChild(
      at: codingPath,
      depth: depth
    )
    return try decodeVisitedValue(
      valueType,
      from: object,
      at: codingPath,
      depth: depth
    )
  }

}
