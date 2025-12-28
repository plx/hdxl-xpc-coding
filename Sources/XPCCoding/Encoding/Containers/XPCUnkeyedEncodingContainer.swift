import XPC

@usableFromInline
internal struct XPCUnkeyedEncodingContainer: UnkeyedEncodingContainer {

  @usableFromInline
  internal typealias StringKeyStrategy = XPCEncoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCEncoder.StringValueStrategy
  
  @inlinable @inline(__always)
  internal var stringKeyStrategy: StringKeyStrategy { encoder.stringKeyStrategy }
  
  @inlinable @inline(__always)
  internal var stringValueStrategy: StringValueStrategy { encoder.stringValueStrategy }

  // MARK: - Properties
  @usableFromInline
  internal var codingPath: [CodingKey] {
    encoder.codingPath
  }
  
  @usableFromInline
  internal var count: Int {
    xpc_array_get_count(underlyingMessage)
  }
  
  @usableFromInline
  internal let encoder: _XPCEncoder
  
  @usableFromInline
  internal let underlyingMessage: xpc_object_t
  
  // MARK: - Initialization
  @usableFromInline
  internal init(
    referencing encoder: _XPCEncoder,
    wrapping underlyingMessage: xpc_object_t
  ) throws {
    self.encoder = encoder
    
    guard underlyingMessage.isArray else {
      throw EncodingError.invalidValue(
        underlyingMessage,
        EncodingError.Context(
          codingPath: encoder.codingPath,
          debugDescription: "Supplied a non-array xpc object (actual type: `\(underlyingMessage.typeDescription))"
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
  internal func withNextCodingKey<R>(_ closure: ([any CodingKey]) throws -> R) throws -> R {
    try encoder.withTransientCodingPathElement(nextCodingKey) { codingPath in
      try closure(codingPath)
    }
  }
  
  @inlinable
  internal func appendNextXPCValue(_ value: xpc_object_t) throws {
    try withNextCodingKey { _ in
      xpc_array_append_value(underlyingMessage, value)
    }
  }

  @inlinable
  internal func appendNextLosslesslyConvertibleValue(_ value: some LosslessXPCObjectConvertible) throws {
    try withNextCodingKey { _ in
      underlyingMessage.appendValue(value)
    }
  }
  
  @inlinable
  internal func appendNextStringValue(_ value: String) throws {
    try withNextCodingKey { codingPath in
      
      do {
        let xpcObject = try value.makeXPCObjectRepresentation(stringValueStrategy: stringValueStrategy)
        xpc_array_append_value(underlyingMessage, xpcObject)
      }
      catch let incompatibilityError {
        throw EncodingError.invalidValue(
          value,
          EncodingError.Context(
            codingPath: codingPath,
            debugDescription: "Attempted to append xpc-incompatible value \(value).",
            underlyingError: incompatibilityError
          )
        )
      }
    }
  }

  // MARK: - UnkeyedEncodingContainer protocol methods
  
  @usableFromInline
  internal mutating func encodeNil() throws {
    try withNextCodingKey { _ in
      xpc_array_append_value(underlyingMessage, xpc_null_create())
    }
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Bool) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode(_ value: String) throws {
    try appendNextStringValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Double) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Float) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int8) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int16) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int32) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int64) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode(_ value: Int128) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode(_ value: UInt) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt8) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt16) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt32) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt64) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode(_ value: UInt128) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode<T: Encodable>(_ value: T) throws {
    try withNextCodingKey { codingPath in
      do {
        let xpcObject = try _XPCEncoder.encode(
          value,
          at: codingPath,
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: stringValueStrategy
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
  
  @usableFromInline
  internal mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
    do {
      return try withNextCodingKey { _ in
        let xpcDictionary = xpc_dictionary_create(nil, nil, 0)
        xpc_array_append_value(underlyingMessage, xpcDictionary)
        
        let container = try XPCKeyedEncodingContainer<NestedKey>(referencing: encoder, wrapping: xpcDictionary)
        return KeyedEncodingContainer(container)
      }
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable error preparing nested keyed container (due to API limitations requiring non-throwing construction here).
        
        - keyType: \(keyType)
        - error: \(String(reflecting: error))
        """
      )
    }
  }
  
  @usableFromInline
  internal mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    do {
      return try withNextCodingKey { _ in
        let xpcArray = xpc_array_create(nil, 0)
        xpc_array_append_value(underlyingMessage, xpcArray)
        
        return try XPCUnkeyedEncodingContainer(referencing: encoder, wrapping: xpcArray)
      }
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable error preparing nested unkeyed container (due to API limitations requiring non-throwing construction here).
        
        - error: \(String(reflecting: error))
        """
      )
    }
  }
  
  @usableFromInline
  internal mutating func superEncoder() -> Encoder {
    do {
      return try withNextCodingKey { codingPath in
        // Insert dummy value in array so we don't get bit later
        xpc_array_append_value(underlyingMessage, xpc_null_create())
        return XPCArrayReferencingEncoder(
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: stringValueStrategy,
          codingPath: codingPath,
          index: count - 1,
          array: underlyingMessage
        )
      }
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable error preparing nested unkeyed container (due to API limitations requiring non-throwing construction here).
        
        - error: \(String(reflecting: error))
        """
      )
    }
  }
}

extension XPCUnkeyedEncodingContainer: XPCEnhancedUnkeyedEncodingContainer {
    
  @inlinable
  internal mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeRawPointer?,
    count: Int
  ) throws {
    try appendNextXPCValue(
      xpc_data_create(
        unsafePointer,
        count
      )
    )
  }
  
  @inlinable
  internal mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeMutableRawPointer?,
    count: Int
  ) throws {
    try appendNextXPCValue(
      xpc_data_create(
        unsafePointer.map { UnsafeRawPointer($0) },
        count
      )
    )
  }
  
  @inlinable
  internal mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeRawBufferPointer) throws {
    try appendNextXPCValue(
      xpc_data_create(
        unsafeBufferPointer.baseAddress,
        unsafeBufferPointer.count
      )
    )
  }
  
  @inlinable
  internal mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeMutableRawBufferPointer) throws {
    try appendNextXPCValue(
      xpc_data_create(
        unsafeBufferPointer.baseAddress.map { UnsafeRawPointer($0) },
        unsafeBufferPointer.count
      )
    )
  }

  
}

// This is used for encoding super classes, we don't know yet what kind of
// container the caller will request so we can not prepoluate in superEncoder().
// To overcome this we alias the encoder, the underlying array, this way we can
// insert the key-value pair upon request and use the encoder to maintain the
// encoding state
@usableFromInline
internal final class XPCArrayReferencingEncoder: _XPCEncoder {
  
  @usableFromInline
  internal let xpcArray: xpc_object_t
  
  @usableFromInline
  internal let index: Int
  
  @usableFromInline
  internal init(
    stringKeyStrategy: StringKeyStrategy,
    stringValueStrategy: StringValueStrategy,
    codingPath: [CodingKey],
    index: Int,
    array: xpc_object_t
  ) {
    self.xpcArray = array
    self.index = index
    super.init(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      codingPath: codingPath
    )
  }
  
  @usableFromInline
  internal override func container<Key>(
    keyedBy type: Key.Type
  ) -> KeyedEncodingContainer<Key> where Key : CodingKey {
    let newDictionary = xpc_dictionary_create(nil, nil, 0)
    xpc_array_set_value(xpcArray, index, newDictionary)
    
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
  internal override func unkeyedContainer() -> UnkeyedEncodingContainer {
    let newArray = xpc_array_create(nil, 0)
    xpc_array_set_value(xpcArray, index, newArray)
    
    do {
      return try XPCUnkeyedEncodingContainer(
        referencing: self,
        wrapping: newArray
      )
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable internal error creating keyed-container:
        
        - error: \(String(reflecting: error))
        """
      )
    }
  }
  
  @usableFromInline
  internal override func singleValueContainer() -> SingleValueEncodingContainer {
    XPCSingleValueEncodingContainer(referencing: self) { [unowned(unsafe) self] value in
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

