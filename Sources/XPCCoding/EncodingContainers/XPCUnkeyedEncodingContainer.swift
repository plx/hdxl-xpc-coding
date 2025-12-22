// Sources/CodableXPC/XPCUnkeyedEncodingContainer.swift -
// UnkeyedEncodingContainer for XPC
//
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// -----------------------------------------------------------------------------
///
/// This file contains a UnkeyedEncodingContainer implementation for
/// xpc_object_t. It also includes a specialization of XPCEncoder for handling
/// the super class case as we don't know what kind of object is going to be
/// needed and we need to maitain a reference to the underlying array.
///
// -----------------------------------------------------------------------------//

import XPC

@usableFromInline
internal struct XPCUnkeyedEncodingContainer: UnkeyedEncodingContainer {

  // MARK: - Properties
  public var codingPath: [CodingKey] {
    encoder.codingPath
  }
  
  public var count: Int {
    xpc_array_get_count(underlyingMessage)
  }
  
  @usableFromInline
  internal let encoder: XPCEncoder
  
  @usableFromInline
  internal let underlyingMessage: xpc_object_t
  
  // MARK: - Initialization
  @usableFromInline
  internal init(
    referencing encoder: XPCEncoder,
    wrapping underlyingMessage: xpc_object_t
  ) throws {
    self.encoder = encoder
    
    guard xpc_get_type(underlyingMessage) == XPC_TYPE_ARRAY else {
      throw EncodingError.invalidValue(
        underlyingMessage,
        EncodingError.Context(
          codingPath: encoder.codingPath,
          debugDescription: "Supplied a non-array xpc object (actual type: `\(xpc_get_type(underlyingMessage).typeDescription))"
        )
      )
    }
    
    self.underlyingMessage = underlyingMessage
  }
  
  @usableFromInline
  internal var nextCodingKey: XPCCodingKey {
    XPCCodingKey(intValue: count)
  }
  
  @inlinable
  internal func withNextCodingKey<R>(_ closure: ([any CodingKey]) throws -> R) rethrows -> R {
    try encoder.withTransientCodingPathElement(nextCodingKey) { codingPath in
      try closure(codingPath)
    }
  }
  
  @inlinable
  internal func appendNextEncodedValue(_ value: some XPCObjectConvertible) throws {
    withNextCodingKey { _ in
      underlyingMessage.appendValue(value)
    }
  }
  
  // MARK: - UnkeyedEncodingContainer protocol methods
  public mutating func encode(_ value: Bool) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encodeNil() throws {
    withNextCodingKey { _ in
      xpc_array_append_value(underlyingMessage, xpc_null_create())
    }
  }
  
  public mutating func encode(_ value: String) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode(_ value: Double) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode(_ value: Float) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode(_ value: Int) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode(_ value: Int8) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode(_ value: Int16) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode(_ value: Int32) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode(_ value: Int64) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode(_ value: UInt) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode(_ value: UInt8) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode(_ value: UInt16) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode(_ value: UInt32) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode(_ value: UInt64) throws {
    try appendNextEncodedValue(value)
  }
  
  public mutating func encode<T: Encodable>(_ value: T) throws {
    try withNextCodingKey { codingPath in
      do {
        let xpcObject = try XPCEncoder.encode(
          value,
          at: codingPath
        )
        xpc_array_append_value(underlyingMessage, xpcObject)
      } catch let error as EncodingError {
        throw error
      } catch let underlyingError {
        throw EncodingError.invalidValue(
          value,
          EncodingError.Context(
            codingPath: codingPath,
            debugDescription: "Unabled to append value: \(String(reflecting: value))!",
            underlyingError: underlyingError
          )
        )
      }
    }
  }
  
  public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
    withNextCodingKey { _ in
      let xpcDictionary = xpc_dictionary_create(nil, nil, 0)
      xpc_array_append_value(underlyingMessage, xpcDictionary)
      
      //It is OK to force this because we are explicitly passing a dictionary
      let container = try! XPCKeyedEncodingContainer<NestedKey>(referencing: encoder, wrapping: xpcDictionary)
      return KeyedEncodingContainer(container)
    }
  }
  
  public mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    withNextCodingKey { _ in
      let xpcArray = xpc_array_create(nil, 0)
      xpc_array_append_value(underlyingMessage, xpcArray)
      
      return try! XPCUnkeyedEncodingContainer(referencing: encoder, wrapping: xpcArray)
    }
  }
  
  public mutating func superEncoder() -> Encoder {
    withNextCodingKey { codingPath in
      // Insert dummy value in array so we don't get bit later
      xpc_array_append_value(underlyingMessage, xpc_null_create())
      return XPCArrayReferencingEncoder(at: codingPath, wrapping: underlyingMessage, forIndex: count - 1)
    }
  }
}

// This is used for encoding super classes, we don't know yet what kind of
// container the caller will request so we can not prepoluate in superEncoder().
// To overcome this we alias the encoder, the underlying array, this way we can
// insert the key-value pair upon request and use the encoder to maintain the
// encoding state
@usableFromInline
internal final class XPCArrayReferencingEncoder: XPCEncoder {
  @usableFromInline
  let xpcArray: xpc_object_t
  
  @usableFromInline
  let index: Int
  
  @usableFromInline
  init(at codingPath: [CodingKey], wrapping array: xpc_object_t, forIndex index: Int) {
    self.xpcArray = array
    self.index = index
    super.init(at: codingPath)
  }
  
  @usableFromInline
  override func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
    let newDictionary = xpc_dictionary_create(nil, nil, 0)
    xpc_array_set_value(xpcArray, index, newDictionary)
    
    // It is OK to force this through because we are explicitly passing a dictionary
    let container = try! XPCKeyedEncodingContainer<Key>(
      referencing: self,
      wrapping: newDictionary
    )
    return KeyedEncodingContainer(container)
  }
  
  @usableFromInline
  override func unkeyedContainer() -> UnkeyedEncodingContainer {
    let newArray = xpc_array_create(nil, 0)
    xpc_array_set_value(xpcArray, index, newArray)
    
    // It is OK to force this through because we are explicitly passing an array
    return try! XPCUnkeyedEncodingContainer(
      referencing: self,
      wrapping: newArray
    )
  }
  
  @usableFromInline
  override func singleValueContainer() -> SingleValueEncodingContainer {
    // It is OK to force this through because we are explictly passing an array
    return XPCSingleValueEncodingContainer(referencing: self) { [unowned(unsafe) self] value in
      guard index < xpc_array_get_count(xpcArray) else {
        throw EncodingError.invalidValue(
          xpcArray,
          EncodingError.Context(
            codingPath: codingPath,
            debugDescription: "Overshot end index on an array: index \(index) vs count \(xpc_array_get_count(xpcArray))."
          )
        )
      }
      xpc_array_set_value(xpcArray, index, value)
    }
  }
}

