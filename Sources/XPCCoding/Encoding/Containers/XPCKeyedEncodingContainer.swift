import XPC

@usableFromInline
internal struct XPCKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

  @usableFromInline
  internal typealias StringKeyStrategy = XPCEncoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCEncoder.StringValueStrategy
  
  @inlinable @inline(__always)
  internal var stringKeyStrategy: StringKeyStrategy { encoder.stringKeyStrategy }
  
  @inlinable @inline(__always)
  internal var stringValueStrategy: StringValueStrategy { encoder.stringValueStrategy }

  // MARK: - Properties
  
  /// A reference to the encoder we're writing to.
  @usableFromInline
  internal let encoder: _XPCEncoder
  
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
    referencing encoder: _XPCEncoder,
    wrapping dictionary: xpc_object_t
  ) throws {
    self.encoder = encoder
    guard dictionary.isDictionary else {
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
  internal mutating func actuallyEncodeLosslesslyConvertibleValue(_ value: some LosslessXPCObjectConvertible, forKey key: Key) throws {
    try encoder.withTransientCodingPathElement(key) { _ in
      underlyingMessage.setValue(
        value,
        forKey: key,
        strategy: stringKeyStrategy
      )
    }
  }

  @usableFromInline
  internal mutating func actuallyEncodeStringValue(_ value: String, forKey key: Key) throws {
    try encoder.withTransientCodingPathElement(key) { codingPath in
      let xpcObject = value.makeXPCObjectRepresentation(stringKeyStrategy: stringKeyStrategy)
      underlyingMessage.setValue(
        xpcObject,
        forKey: key,
        strategy: stringKeyStrategy
      )
    }
  }

  // MARK: - KeyedEncodingContainerProtocol Methods
  
  public mutating func encodeNil(forKey key: Key) throws {
    try encoder.withTransientCodingPathElement(key) { _ in
      underlyingMessage.setNil(
        forKey: key,
        strategy: stringKeyStrategy
      )
    }
  }
  
  public mutating func encode(_ value: Bool, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Int, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Int8, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Int16, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Int32, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Int64, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }

  public mutating func encode(_ value: Int128, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }

  public mutating func encode(_ value: UInt, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: UInt8, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: UInt16, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: UInt32, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: UInt64, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }

  public mutating func encode(_ value: UInt128, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }

  public mutating func encode(_ value: String, forKey key: Key) throws {
    try actuallyEncodeStringValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Float, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  public mutating func encode(_ value: Double, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  public mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
    try encoder.withTransientCodingPathElement(key) { codingPath in
      do {
        underlyingMessage.setValue(
          try _XPCEncoder.encode(
            value,
            at: codingPath,
            stringKeyStrategy: stringKeyStrategy,
            stringValueStrategy: stringValueStrategy
          ),
          forKey: key,
          strategy: stringKeyStrategy
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
    do {
      return try encoder.withTransientCodingPathElement(key) { _ in
        let xpcDictionary = xpc_dictionary_create(nil, nil, 0)
        underlyingMessage.setValue(
          xpcDictionary,
          forKey: key,
          strategy: stringKeyStrategy
        )
        // It is OK to force this through because we know we are providing a dictionary
        let container = try XPCKeyedEncodingContainer<NestedKey>(
          referencing: encoder,
          wrapping: xpcDictionary
        )
        return KeyedEncodingContainer(container)
      }
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable error preparing nested keyed container (due to API limitations requiring non-throwing construction here).
        
        - keyType: \(keyType)
        - key: \(key)
        - error: \(String(reflecting: error))
        """
      )
    }
  }
  
  public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    do {
      let xpcArray = xpc_array_create(nil, 0)
      underlyingMessage.setValue(
        xpcArray,
        forKey: key,
        strategy: stringKeyStrategy
      )
      
      return try encoder.withTransientCodingPathElement(key) { _ in
        let container = try XPCUnkeyedEncodingContainer(
          referencing: encoder,
          wrapping: xpcArray
        )
        return container
      }
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable error preparing nested unkeyed container (due to API limitations requiring non-throwing construction here).
        
        - key: \(key)
        - error: \(String(reflecting: error))
        """
      )
    }
  }
  
  public mutating func superEncoder() -> Encoder {
    do {
      return try encoder.withTransientCodingPathElement(XPCCodingKey.superKey) { codingPath in
        XPCDictionaryReferencingEncoder(
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: stringValueStrategy,
          codingPath: codingPath,
          codingKey: XPCCodingKey.superKey,
          dictionary: underlyingMessage
        )
      }
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable error preparing superEncoder (due to API limitations requiring non-throwing construction here).
        
        - error: \(String(reflecting: error))
        """
      )
    }
  }
  
  public mutating func superEncoder(forKey key: Key) -> Encoder {
    do {
      return try encoder.withTransientCodingPathElement(key) { codingPath in
        XPCDictionaryReferencingEncoder(
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: stringValueStrategy,
          codingPath: codingPath,
          codingKey: key,
          dictionary: underlyingMessage
        )
      }
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable error preparing superEncoder (due to API limitations requiring non-throwing construction here).
        
        - key: \(key)
        - error: \(String(reflecting: error))
        """
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
internal final class XPCDictionaryReferencingEncoder: _XPCEncoder {
  @usableFromInline
  internal let xpcDictionary: xpc_object_t
  
  @usableFromInline
  internal let codingKey: CodingKey
  
  @usableFromInline
  internal init(
    stringKeyStrategy: StringKeyStrategy,
    stringValueStrategy: StringValueStrategy,
    codingPath: [CodingKey],
    codingKey: CodingKey,
    dictionary: xpc_object_t
  ) {
    self.xpcDictionary = dictionary
    self.codingKey = codingKey
    super.init(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      codingPath: codingPath
    )
  }
  
  @usableFromInline
  override func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
    let newDictionary = xpc_dictionary_create(nil, nil, 0)
    xpcDictionary.setValue(
      newDictionary,
      forKey: codingKey,
      strategy: stringKeyStrategy
    )

    do {
      let container = try XPCKeyedEncodingContainer<Key>(
        referencing: self,
        wrapping: newDictionary
      )
      return KeyedEncodingContainer(container)
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable internal error creating keyed-container:
        
        - keyedBy: \(type)
        - error: \(String(reflecting: error))
        """
      )
    }
  }
  
  @usableFromInline
  override func unkeyedContainer() -> UnkeyedEncodingContainer {
    let newArray = xpc_array_create(nil, 0)
    xpcDictionary.setValue(
      newArray,
      forKey: codingKey,
      strategy: stringKeyStrategy
    )

    do {
      return try XPCUnkeyedEncodingContainer(
        referencing: self,
        wrapping: newArray
      )
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable internal error creating unkeyed-container:
        
        - error: \(String(reflecting: error))
        """
      )
    }
  }
  
  @usableFromInline
  override func singleValueContainer() -> SingleValueEncodingContainer {
    XPCSingleValueEncodingContainer(referencing: self) { [self] value in
      xpcDictionary.setValue(
        value,
        forKey: codingKey,
        strategy: stringKeyStrategy
      )
    }
  }
}

