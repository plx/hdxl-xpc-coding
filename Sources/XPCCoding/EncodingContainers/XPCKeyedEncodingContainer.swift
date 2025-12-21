// Sources/CodableXPC/XPCKeyedEncodingContainer.swift - KeyedEncodingContainer
// implementation for XPC
//
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// -----------------------------------------------------------------------------
//
// This file contains a KeyedEncodingContainer implementation for xpc_object_t.
// This includes a specialization of the XPCEncoder for handling the super
// class case, as we don't know what container type is going to be needed to
// handle it.
//
// -----------------------------------------------------------------------------//
import XPC

@usableFromInline
internal struct XPCKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
  public typealias Key = K
  
  // MARK: - Properties
  
  /// A reference to the encoder we're writing to.
  @usableFromInline
  internal let encoder: XPCEncoder
  
  @usableFromInline
  internal let underlyingMessage: xpc_object_t
  
  /// The path of coding keys taken to get to this point in encoding.
  public var codingPath: [CodingKey] {
    encoder.codingPath
  }
  
  // MARK: - Initialization
  
  /// Initializes `self` with the given references.
  @usableFromInline
  internal init(
    referencing encoder: XPCEncoder,
    wrapping dictionary: xpc_object_t
  ) throws {
    self.encoder = encoder
    guard xpc_get_type(dictionary) == XPC_TYPE_DICTIONARY else {
      throw EncodingError.invalidValue(
        dictionary,
        EncodingError.Context(
          codingPath: encoder.codingPath,
          debugDescription: "Expected a dictionary as xpc object, but got: \(xpc_get_type(dictionary).typeDescription)!"
        )
      )
    }
    self.underlyingMessage = dictionary
  }
 
  @usableFromInline
  internal mutating func actuallyEncodeValue(_ value: some XPCObjectConvertible, forKey key: Key) throws {
    encoder.withTransientCodingPathElement(key) { _ in
      underlyingMessage.setValue(value, forKey: key)
    }
  }
  
  // MARK: - KeyedEncodingContainerProtocol Methods
  
  public mutating func encodeNil(forKey key: Key) throws {
    encoder.withTransientCodingPathElement(key) { _ in
      underlyingMessage.setNil(forKey: key)
    }
  }
  
  public mutating func encode(_ value: Bool, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Int, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Int8, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Int16, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Int32, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Int64, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: UInt, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: UInt8, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: UInt16, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: UInt32, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: UInt64, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: String, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Float, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Double, forKey key: Key) throws {
    try actuallyEncodeValue(value, forKey: key)
  }
  
  public mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
    try encoder.withTransientCodingPathElement(key) { codingPath in
      do {
        underlyingMessage.setValue(
          try XPCEncoder.encode(
            value, at: codingPath
          ),
          forKey: key
        )
      } catch let error as EncodingError {
        throw error
      } catch let underlyingError {
        throw EncodingError.invalidValue(
          value,
          EncodingError.Context(
            codingPath: codingPath,
            debugDescription: "Unable to encode value: \(value) for key: \(key.stringValue)",
            underlyingError: underlyingError
          )
        )
      }
    }
  }
  
  public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
    encoder.withTransientCodingPathElement(key) { _ in
      let xpcDictionary = xpc_dictionary_create(nil, nil, 0)
      underlyingMessage.setValue(xpcDictionary, forKey: key)
      // It is OK to force this through because we know we are providing a dictionary
      let container = try! XPCKeyedEncodingContainer<NestedKey>(
        referencing: encoder,
        wrapping: xpcDictionary
      )
      return KeyedEncodingContainer(container)
    }
  }
  
  public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    encoder.withTransientCodingPathElement(key) { _ in
      let xpcArray = xpc_array_create(nil, 0)
      underlyingMessage.setValue(xpcArray, forKey: key)
      let container = try! XPCUnkeyedEncodingContainer(
        referencing: encoder,
        wrapping: xpcArray
      )
      return container
    }
  }
  
  public mutating func superEncoder() -> Encoder {
    encoder.withTransientCodingPathElement(XPCCodingKey.superKey) { codingPath in
      XPCDictionaryReferencingEncoder(
        at: codingPath,
        wrapping: underlyingMessage,
        forKey: XPCCodingKey.superKey
      )
    }
  }
  
  public mutating func superEncoder(forKey key: Key) -> Encoder {
    encoder.withTransientCodingPathElement(key) { codingPath in
      XPCDictionaryReferencingEncoder(
        at: codingPath,
        wrapping: underlyingMessage,
        forKey: key
      )
    }
  }
}

// This is used for encoding super classes, we don't know yet what kind of
// container the caller will request so we can not prepoluate in superEncoder().
// To overcome this we alias the encoder, the underlying dictionary, and the key
// to use, this way we can insert the key-value pair upon request and use the
// encoder to maintain the encoding state
@usableFromInline
internal final class XPCDictionaryReferencingEncoder: XPCEncoder {
  @usableFromInline
  let xpcDictionary: xpc_object_t
  
  @usableFromInline
  let key: CodingKey
  
  @usableFromInline
  init(at codingPath: [CodingKey], wrapping dictionary: xpc_object_t, forKey key: CodingKey) {
    self.xpcDictionary = dictionary
    self.key = key
    super.init(at: codingPath)
  }
  
  @usableFromInline
  override func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
    let newDictionary = xpc_dictionary_create(nil, nil, 0)
    xpcDictionary.setValue(newDictionary, forKey: key)
    
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
    xpcDictionary.setValue(newArray, forKey: key)
    
    // It is OK to force this through because we are explicitly passing an array
    return try! XPCUnkeyedEncodingContainer(
      referencing: self,
      wrapping: newArray
    )
  }
  
  @usableFromInline
  override func singleValueContainer() -> SingleValueEncodingContainer {
    XPCSingleValueEncodingContainer(referencing: self) { [unowned(unsafe) self] value in
      xpcDictionary.setValue(value, forKey: key)
    }
  }
}

