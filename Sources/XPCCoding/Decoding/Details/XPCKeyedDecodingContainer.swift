// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

// MARK: XPCKeyedDecodingContainer

/// Internal keyed-decoding container.
@usableFromInline
internal final class XPCKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {

  @usableFromInline
  internal typealias StringKeyStrategy = XPCDecoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCDecoder.StringValueStrategy
  
  /// We always read the string key strategy from the decoder.
  @inlinable @inline(__always)
  internal var stringKeyStrategy: XPCDecoder.StringKeyStrategy { decoder.stringKeyStrategy }
  
  /// We always read the string value strategy from the decoder.
  @inlinable @inline(__always)
  internal var stringValueStrategy: XPCDecoder.StringValueStrategy { decoder.stringValueStrategy }
  
  // MARK: - Properties
  
  /// A reference to the decoder we're reading from.
  @usableFromInline
  internal let decoder: _XPCDecoder
  
  /// The path of coding keys taken to get to this point in decoding.
  @usableFromInline
  internal var codingPath: [CodingKey]
  
  /// The underlying XPC dictionary from which we're decoding.
  @usableFromInline
  internal let underlyingXPCDictionary: xpc_object_t

  /// The recursive decoding depth of this dictionary below the root object.
  @usableFromInline
  internal let depth: Int
  
  // MARK: - Initialization
  
  /// Initializes `self` by referencing the given decoder and container.
  /// 
  /// - Parameters:
  ///   - decoder: The decoder to reference.
  ///   - underlyingXPCDictionary: The underlying XPC dictionary to wrap.
  ///   - codingPath: The path of coding keys taken to get to this point in decoding.
  ///   - depth: The recursive decoding depth of this container.
  /// - Throws: `DecodingError.dataCorrupted` if the underlying XPC object is not a dictionary.
  @usableFromInline
  internal init(
    referencing decoder: _XPCDecoder,
    wrapping underlyingXPCDictionary: xpc_object_t,
    codingPath: [any CodingKey],
    depth: Int? = nil
  ) throws {
    guard underlyingXPCDictionary.isDictionary else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Did not find xpc dictionary in keyed container"
        )
      )
    }

    let depth = depth ?? decoder.depth
    try decoder.decodingState.validateDictionary(
      underlyingXPCDictionary,
      codingPath: codingPath
    )

    self.decoder = decoder
    self.underlyingXPCDictionary = underlyingXPCDictionary
    self.codingPath = codingPath
    self.depth = depth
  }
  
  // MARK: - KeyedDecodingContainerProtocol
  
  @usableFromInline
  internal var allKeys: [Key] {
    var keys: [Key] = []
    let embeddedNullByteRepresentation = stringKeyStrategy.embeddedNullByteRepresentation
    xpc_dictionary_apply(underlyingXPCDictionary) { (keyCString, _) -> Bool in
      guard
        let keyString = String(
          cString: keyCString,
          embeddedNullByteRepresentation: embeddedNullByteRepresentation
        ),
        let key = Key(stringValue: keyString)
      else {
        return true
      }
      
      keys.append(key)
      return true
    }
    return keys
  }
  
  @usableFromInline
  internal func contains(_ key: Key) -> Bool {
    key.withUTF8CString(stringKeyStrategy: stringKeyStrategy) { keyCString in
      nil != xpc_dictionary_get_value(underlyingXPCDictionary, keyCString)
    }
  }
  
  @inlinable
  internal func decodeNil(forKey key: Key) throws -> Bool {
    try withTransientCodingKey(key) { codingPath in
      guard let value = possibleXPCObject(for: key) else {
        return false
      }
      try decoder.prepareToVisitChild(
        at: codingPath,
        depth: depth + 1
      )
      return value.isNull
    }
  }
  
  @inlinable
  internal func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    try extractValue(ofType: type, forKey: key)
  }
    
  @inlinable
  internal func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    try extractValue(ofType: type, forKey: key)
  }

  @inlinable
  internal func decode(_ type: Int128.Type, forKey key: Key) throws -> Int128 {
    try extractValue(ofType: type, forKey: key)
  }

  @inlinable
  internal func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    try extractValue(ofType: type, forKey: key)
  }

  @inlinable
  internal func decode(_ type: UInt128.Type, forKey key: Key) throws -> UInt128 {
    try extractValue(ofType: type, forKey: key)
  }

  @inlinable
  internal func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: String.Type, forKey key: Key) throws -> String {
    try extractString(forKey: key)
  }
  
  @inlinable
  internal func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
    try withTransientCodingKey(key) { codingPath in
      let xpcObject = try requiredXPCObject(for: key)
      return try decoder.decodeChildValue(
        type,
        from: xpcObject,
        at: codingPath,
        depth: depth + 1
      )
    }
  }
  
  @inlinable
  internal func nestedContainer<NestedKey>(
    keyedBy type: NestedKey.Type,
    forKey key: Key
  ) throws -> KeyedDecodingContainer<NestedKey> {
    try withTransientCodingKey(key) { codingPath in
      let xpcObject = try requiredXPCObject(for: key)
      let childDepth = depth + 1
      try decoder.prepareToVisitChild(
        at: codingPath,
        depth: childDepth
      )
      
      let container = try XPCKeyedDecodingContainer<NestedKey>(
        referencing: decoder,
        wrapping: xpcObject,
        codingPath: codingPath,
        depth: childDepth
      )
      
      return KeyedDecodingContainer<NestedKey>(container)
    }
  }
  
  @inlinable
  internal func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    try withTransientCodingKey(key) { codingPath in
      let xpcObject = try requiredXPCObject(for: key)
      let childDepth = depth + 1
      try decoder.prepareToVisitChild(
        at: codingPath,
        depth: childDepth
      )
      return try XPCUnkeyedDecodingContainer(
        referencing: decoder,
        wrapping: xpcObject,
        codingPath: codingPath,
        depth: childDepth
      )
    }
  }
  
  @inlinable
  internal func superDecoder() throws -> Decoder {
    try withTransientCodingKey(XPCCodingKey.superKey) { codingPath in
      let xpcObject = try requiredXPCObject(for: XPCCodingKey.superKey)
      let childDepth = depth + 1
      try decoder.prepareToVisitChild(
        at: codingPath,
        depth: childDepth
      )
      return _XPCDecoder(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: stringValueStrategy,
        decoding: xpcObject,
        at: codingPath,
        decodingState: decoder.decodingState,
        depth: childDepth
      )
    }
  }
  
  @inlinable
  internal func superDecoder(forKey key: Key) throws -> Decoder {
    try withTransientCodingKey(key) { codingPath in
      let xpcObject = try requiredXPCObject(for: key)
      let childDepth = depth + 1
      try decoder.prepareToVisitChild(
        at: codingPath,
        depth: childDepth
      )
      return _XPCDecoder(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: stringValueStrategy,
        decoding: xpcObject,
        at: codingPath,
        decodingState: decoder.decodingState,
        depth: childDepth
      )
    }
  }
}

// MARK: - Support API

extension XPCKeyedDecodingContainer {

  /// Locates the XPC object for `key`, returning `nil` when absent.
  @usableFromInline
  internal func possibleXPCObject(for key: CodingKey) -> xpc_object_t? {
    key.withUTF8CString(stringKeyStrategy: stringKeyStrategy) { keyCString in
      xpc_dictionary_get_value(underlyingXPCDictionary, keyCString)
    }
  }

  /// Locates the XPC object for the given `key`; throws an error when not found.
  @usableFromInline
  internal func requiredXPCObject(for key: CodingKey) throws -> xpc_object_t {
    let possibleValue = possibleXPCObject(for: key)
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

  /// Performs `closure` with `key` added to the coding path, then removes it.
  @inlinable
  internal func withTransientCodingKey<R>(
    _ key: Key,
    _ closure: ([any CodingKey]) throws -> R
  ) throws -> R {
    codingPath.append(key)
    defer {
#if DEBUG
      let poppedKey = codingPath.removeLast()
      assert(poppedKey.stringValue == key.stringValue)
      assert(poppedKey.intValue == key.intValue)
#else
      let _ = codingPath.removeLast()
#endif
    }
    return try closure(codingPath)
  }
  
  /// Special-case transient-coding-key helper for `XPCCodingKey`.
  /// 
  /// - Note: used for encoding superclasses (etc.).
  @inlinable
  internal func withTransientCodingKey<R>(
    _ key: XPCCodingKey,
    _ closure: ([any CodingKey]) throws -> R
  ) throws -> R {
    codingPath.append(key)
    defer {
#if DEBUG
      let poppedKey = codingPath.removeLast()
      assert(poppedKey.stringValue == key.stringValue)
      assert(poppedKey.intValue == key.intValue)
#else
      let _ = codingPath.removeLast()
#endif
    }
    return try closure(codingPath)
  }
  
  /// General-purpose extraction for a value of a specific type.
  @inlinable
  internal func extractValue<Value>(
    ofType valueType: Value.Type,
    forKey key: Key
  ) throws -> Value where Value: XPCObjectExtractable {
    try withTransientCodingKey(key) { codingPath in
      try decoder.extractChildValue(
        valueType,
        from: try requiredXPCObject(for: key),
        at: codingPath,
        depth: depth + 1
      )
    }
  }
  
  /// Special-case extraction for `String`, respecting our string key and value strategies.
  @inlinable
  internal func extractString(
    forKey key: Key
  ) throws -> String {
    try withTransientCodingKey(key) { codingPath in
      try decoder.extractChildString(
        from: try requiredXPCObject(for: key),
        at: codingPath,
        depth: depth + 1
      )
    }
  }

}
