import Foundation
import XPC

// MARK: XPCKeyedEncodingContainer

/// Our internal implementation of `KeyedEncodingContainerProtocol`.
@usableFromInline
internal struct XPCKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

  @usableFromInline
  internal typealias StringKeyStrategy = XPCEncoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCEncoder.StringValueStrategy
  
  /// Always read the string-key strategy from the encoder.
  @inlinable @inline(__always)
  internal var stringKeyStrategy: StringKeyStrategy { encoder.stringKeyStrategy }
  
  /// Always read the string-value strategy from the encoder.
  @inlinable @inline(__always)
  internal var stringValueStrategy: StringValueStrategy { encoder.stringValueStrategy }

  /// Always read the coding path from the encoder.
  @inlinable @inline(__always)
  internal var codingPath: [CodingKey] { encoder.codingPath }

  // MARK: - Properties
  
  /// A reference to the encoder we're writing to.
  @usableFromInline
  internal let encoder: _XPCEncoder
  
  @usableFromInline
  internal let underlyingXPCDictionary: xpc_object_t
  
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
    self.underlyingXPCDictionary = dictionary
  }
 
  // MARK: - KeyedEncodingContainerProtocol
  
  @inlinable
  internal mutating func encodeNil(forKey key: Key) throws {
    try encoder.withTransientCodingPathElement(key) { _ in
      underlyingXPCDictionary.setNil(
        forKey: key,
        strategy: stringKeyStrategy
      )
    }
  }
  
  @inlinable
  internal mutating func encode(_ value: Bool, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @inlinable
  internal mutating func encode(_ value: Int, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @inlinable
  internal mutating func encode(_ value: Int8, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @inlinable
  internal mutating func encode(_ value: Int16, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @inlinable
  internal mutating func encode(_ value: Int32, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @inlinable
  internal mutating func encode(_ value: Int64, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }

  @inlinable
  internal mutating func encode(_ value: Int128, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }

  @inlinable
  internal mutating func encode(_ value: UInt, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @inlinable
  internal mutating func encode(_ value: UInt8, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @inlinable
  internal mutating func encode(_ value: UInt16, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @inlinable
  internal mutating func encode(_ value: UInt32, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @inlinable
  internal mutating func encode(_ value: UInt64, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }

  @inlinable
  internal mutating func encode(_ value: UInt128, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }

  @inlinable
  internal mutating func encode(_ value: String, forKey key: Key) throws {
    try actuallyEncodeStringValue(value, forKey: key)
  }
  
  @inlinable
  internal mutating func encode(_ value: Float, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @inlinable
  internal mutating func encode(_ value: Double, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @inlinable
  internal mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
    // Fast path for Data - encode directly as xpc_data_t
    if let data = value as? Data {
      try encoder.withTransientCodingPathElement(key) { _ in
        data.withUnsafeBytes { buffer in
          underlyingXPCDictionary.setValue(
            xpc_data_create(buffer.baseAddress, buffer.count),
            forKey: key,
            strategy: stringKeyStrategy
          )
        }
      }
      return
    }

    try encoder.withTransientCodingPathElement(key) { codingPath in
      do {
        underlyingXPCDictionary.setValue(
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
  
  @inlinable
  internal mutating func nestedContainer<NestedKey>(
    keyedBy keyType: NestedKey.Type, 
    forKey key: Key
  ) -> KeyedEncodingContainer<NestedKey> {
    do {
      return try encoder.withTransientCodingPathElement(key) { _ in
        let xpcDictionary = xpc_dictionary_create(nil, nil, 0)
        underlyingXPCDictionary.setValue(
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
  
  @inlinable
  internal mutating func nestedUnkeyedContainer(
    forKey key: Key
  ) -> UnkeyedEncodingContainer {
    do {
      let xpcArray = xpc_array_create(nil, 0)
      underlyingXPCDictionary.setValue(
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
  
  @inlinable
  internal mutating func superEncoder() -> Encoder {
    do {
      return try encoder.withTransientCodingPathElement(XPCCodingKey.superKey) { codingPath in
        _XPCDictionaryReferencingEncoder(
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: stringValueStrategy,
          codingPath: codingPath,
          codingKey: XPCCodingKey.superKey,
          dictionary: underlyingXPCDictionary
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
  
  @inlinable
  internal mutating func superEncoder(forKey key: Key) -> Encoder {
    do {
      return try encoder.withTransientCodingPathElement(key) { codingPath in
        _XPCDictionaryReferencingEncoder(
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: stringValueStrategy,
          codingPath: codingPath,
          codingKey: key,
          dictionary: underlyingXPCDictionary
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


// MARK: - Support API

extension XPCKeyedEncodingContainer {

  /// Generic handler for losslessly-convertible values.
  @usableFromInline
  internal mutating func actuallyEncodeLosslesslyConvertibleValue(
    _ value: some LosslessXPCObjectConvertible, 
    forKey key: Key
  ) throws {
    try encoder.withTransientCodingPathElement(key) { _ in
      underlyingXPCDictionary.setValue(
        value,
        forKey: key,
        strategy: stringKeyStrategy
      )
    }
  }

  /// Special-case handling for string values.
  @usableFromInline
  internal mutating func actuallyEncodeStringValue(
    _ value: String, 
    forKey key: Key
  ) throws {
    try encoder.withTransientCodingPathElement(key) { codingPath in
      let xpcObject = try value.makeXPCObjectRepresentation(stringValueStrategy: stringValueStrategy)
      underlyingXPCDictionary.setValue(
        xpcObject,
        forKey: key,
        strategy: stringKeyStrategy
      )
    }
  }

}
