// Sources/XPCCoding/XPCDecoder.swift - Decoder impelementation for XPC
//
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// -----------------------------------------------------------------------------
//
// This file contains an implementation of a Decoder for xpc_object_t types, as
// well as generic utility functions for decoding primitives that are reused by
// all the decoding containers.
//
// -----------------------------------------------------------------------------//

import XPC

public final class XPCDecoder: Decoder {

  @usableFromInline
  internal let underlyingMessage: xpc_object_t

  @usableFromInline
  internal var _codingPath: [CodingKey]

  public var codingPath: [CodingKey] { _codingPath }
  
  
  public var userInfo: [CodingUserInfoKey : Any] = [:]
    
  @usableFromInline
  internal init(underlyingMessage message: xpc_object_t, at codingPath: [CodingKey] = []) {
    self.underlyingMessage = message
    self._codingPath = codingPath
  }
  
  @usableFromInline
  internal convenience init(decoding message: xpc_object_t) throws {
    guard xpc_get_type(message) == XPC_TYPE_DICTIONARY else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: [],
          debugDescription: "Supplied a non-dictionary xpc object (type: \(xpc_get_type(message).typeDescription))!"
        )
      )
    }
    self.init(
      underlyingMessage: message,
      at: []
    )
  }
  
  @inlinable
  public static func decodeRootValue<T: Decodable>(_ message: xpc_object_t, as type: T.Type) throws -> T {
    if
      let extractableType = type as? XPCObjectExtractable.Type,
      xpc_get_type(message) == extractableType.associatedXPCObjectType,
      let _extractedValue = extractableType.extracting(from: message),
      let extractedValue = _extractedValue as? T
    {
      return extractedValue
    }
    
    let decoder = try XPCDecoder(decoding: message)
    return try type.init(from: decoder)
  }
  
  @inlinable
  internal func verifyKeyCompatibility(
    key: some CodingKey,
    codingPath: [any CodingKey]
  ) throws(DecodingError) {
    do {
      try key.verifyXPCCompatibility()
    }
    catch let incompatibilityError {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Tried to decode an xpc-incompatible key `\(key)`",
          underlyingError: incompatibilityError
        )
      )
    }
  }
  
  @inlinable
  internal func withTransientCodingPathElement<Key, R>(
    _ codingPathElement: Key,
    _ closure: ([any CodingKey]) throws -> R
  ) throws -> R where Key: CodingKey {
    _codingPath.append(codingPathElement)
    defer {
      #if DEBUG
      assert(!_codingPath.isEmpty)
      let popped = _codingPath.removeLast()
      // `CodingKey` isn't `Equatable`, so we instead compare its concrete representations:
      assert(popped.stringValue == codingPathElement.stringValue)
      assert(popped.intValue == codingPathElement.intValue)
      #else
      _codingPath.removeLast()
      #endif
    }
    let codingPath = _codingPath
    try verifyKeyCompatibility(
      key: codingPathElement,
      codingPath: codingPath
    )
    return try closure(codingPath)
  }
  
  public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
    let container = try XPCKeyedDecodingContainer<Key>(referencing: self, wrapping: underlyingMessage)
    return KeyedDecodingContainer(container)
  }
  
  public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    try XPCUnkeyedDecodingContainer(referencing: self, wrapping: underlyingMessage)
  }
  
  public func singleValueContainer() throws -> SingleValueDecodingContainer {
    XPCSingleValueDecodingContainer(referencing: self, wrapping: underlyingMessage)
  }
  
  public static func decode<T: Decodable>(_ type: T.Type, message xpcObject: xpc_object_t) throws -> T {
    try T(from: XPCDecoder(underlyingMessage: xpcObject))
  }
}

extension xpc_object_t {
  @usableFromInline
  func decodeNil(at codingPath: [CodingKey]) -> Bool {
    return xpc_get_type(self) == XPC_TYPE_NULL
  }

  @usableFromInline
  func decodeNil(
    at codingPath: [CodingKey],
    forKey key: any CodingKey
  ) -> Bool {
    let possibleValue = key.stringValue.withCString { cString in
      xpc_dictionary_get_value(self, cString)
    }
    guard
      let value = possibleValue,
      value.hasType(XPC_TYPE_NULL)
    else {
      return false
    }
    
    return true
  }

  @usableFromInline
  func extractValue<Value>(
    ofType valueType: Value.Type,
    at codingPath: [any CodingKey]
  ) throws -> Value where Value: XPCObjectExtractable {
    guard xpc_get_type(self) == valueType.associatedXPCObjectType else {
      throw DecodingError.typeMismatch(
        valueType,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
          """
          Type mismatch: expected \(String(reflecting: valueType)) represented-as \(valueType.associatedXPCObjectType.typeDescription), but xpc object is actually \(xpc_get_type(self).typeDescription).",
          """,
          underlyingError: nil
        )
      )
    }
    
    guard let extractedValue = valueType.extracting(from: self) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
          """
          Data corruption: unable to construct a value of type \(String(reflecting: valueType)) from an xpc object of type \(xpc_get_type(self).typeDescription).",
          """,
          underlyingError: nil
        )
      )
    }
    
    return extractedValue
  }
  
  @usableFromInline
  func extractValue<Value>(
    ofType valueType: Value.Type,
    at codingPath: [any CodingKey],
    forKey key: any CodingKey
  ) throws -> Value where Value: XPCObjectExtractable {
    guard xpc_get_type(self) == XPC_TYPE_DICTIONARY else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
          """
          Data corruption: expected to be extracting a value of type \(String(reflecting: valueType)) for key `\(key)` from a dictionary, but our xpc object is actually \(xpc_get_type(self).typeDescription).",
          """,
          underlyingError: nil
        )
      )
    }
    
    let possible_xpc_value = key.stringValue.withCString { cString in
      xpc_dictionary_get_value(self, cString)
    }
    guard let xpc_value = possible_xpc_value else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
          """
          Key not found: couldn't find expected value of type \(String(reflecting: valueType)) for key: `\(key.stringValue)`.",
          """,
          underlyingError: nil
        )
      )
    }

    return try xpc_value.extractValue(
      ofType: valueType,
      at: codingPath
    )
  }

}
