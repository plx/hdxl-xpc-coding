// Sources/CodableXPC/XPCKeyedDecodingContainer.swift - KeyedDecodingContainer
// implementation for XPC
//
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// -----------------------------------------------------------------------------
//
// This file contains a KeyedDecodingContainer implementation for xpc_object_t.
//
// -----------------------------------------------------------------------------//

import XPC

@usableFromInline
internal struct XPCKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
  public typealias Key = K
  
  // MARK: - Properties
  
  /// A reference to the decoder we're reading from.
  @usableFromInline
  internal let decoder: XPCDecoder
  
  /// The path of coding keys taken to get to this point in decoding.
  public var codingPath: [CodingKey] {
    decoder.codingPath
  }
  
  @usableFromInline
  internal let underlyingMessage: xpc_object_t
  
  // MARK: - Initialization
  
  /// Initializes `self` by referencing the given decoder and container.
  init(referencing decoder: XPCDecoder, wrapping underlyingMessage: xpc_object_t) throws {
    guard underlyingMessage.isDictionary else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Did not find xpc dictionary in keyed container"
        )
      )
    }
    self.decoder = decoder
    self.underlyingMessage = underlyingMessage
  }
  
  // MARK: - Helpers
  
  @usableFromInline
  internal func getXPCObject(for key: CodingKey) throws -> xpc_object_t {
    let possibleValue = key.stringValue.withCString { keyCString in
      xpc_dictionary_get_value(underlyingMessage, keyCString)
    }
    guard let value = possibleValue else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "No value found for key \(key.stringValue)"
        )
      )
    }
    
    return value
  }
  
  // MARK: - KeyedDecodingContainerProtocol Methods
  
  /// You shouldn't rely on this because this is slow
  public var allKeys: [Key] {
    get {
      var keys: [Key] = []
      xpc_dictionary_apply(underlyingMessage) { (key, _) -> Bool in
        keys.append(Key(stringValue: String(cString: key))!)
        return true
      }
      return keys
    }
  }
  
  public func contains(_ key: Key) -> Bool {
    do {
      let _ = try getXPCObject(for: key)
    } catch {
      return false
    }
    return true
  }
  
  @inlinable
  internal func withTransientCodingKey<R>(
    _ key: Key,
    _ closure: ([any CodingKey]) throws -> R
  ) rethrows -> R {
    try decoder.withTransientCodingPathElement(key, closure)
  }

  @inlinable
  internal func withTransientCodingKey<R>(
    _ key: XPCCodingKey,
    _ closure: ([any CodingKey]) throws -> R
  ) rethrows -> R {
    try decoder.withTransientCodingPathElement(key, closure)
  }

  @inlinable
  internal func extractValue<Value>(
    ofType valueType: Value.Type,
    forKey key: Key
  ) throws -> Value where Value: XPCObjectExtractable {
    try withTransientCodingKey(key) { codingPath in
      try underlyingMessage.extractValue(
        ofType: valueType,
        at: codingPath,
        forKey: key
      )
    }
  }
  
  public func decodeNil(forKey key: Key) throws -> Bool {
    withTransientCodingKey(key) { codingPath in
      underlyingMessage.decodeNil(
        at: codingPath,
        forKey: key
      )
    }
  }
  
  public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    try extractValue(ofType: type, forKey: key)
  }
    
  public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode(_ type: String.Type, forKey key: Key) throws -> String {
    try extractValue(ofType: type, forKey: key)
  }
  
  public func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
    try withTransientCodingKey(key) { codingPath in
      try T(
        from: XPCDecoder(
          underlyingMessage: try getXPCObject(for: key),
          at: codingPath
        )
      )
    }
  }
  
  public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
    try withTransientCodingKey(key) { _ in
      let xpcObject = try getXPCObject(for: key)
      
      let container = try XPCKeyedDecodingContainer<NestedKey>(
        referencing: decoder,
        wrapping: xpcObject
      )
      
      return KeyedDecodingContainer<NestedKey>(container)
    }
  }
  
  public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    try withTransientCodingKey(key) { _ in
      try XPCUnkeyedDecodingContainer(
        referencing: decoder,
        wrapping: try getXPCObject(for: key)
      )
    }
  }
  
  public func superDecoder() throws -> Decoder {
    try withTransientCodingKey(XPCCodingKey.superKey) { codingPath in
      XPCDecoder(
        underlyingMessage: try getXPCObject(for: XPCCodingKey.superKey),
        at: codingPath
      )
    }
  }
  
  public func superDecoder(forKey key: Key) throws -> Decoder {
    try withTransientCodingKey(key) { codingPath in
      XPCDecoder(
        underlyingMessage: try getXPCObject(for: key),
        at: codingPath
      )
    }
  }
}


