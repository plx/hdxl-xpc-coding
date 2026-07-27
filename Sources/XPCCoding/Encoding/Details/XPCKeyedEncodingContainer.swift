// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

// MARK: XPCKeyedEncodingContainer

/// Our internal implementation of `KeyedEncodingContainerProtocol`.
///
/// Inlining audit rationale: this is the compiler-required ABI closure for the
/// measured keyed-encoding leaves below. Non-hot protocol witnesses are
/// `@usableFromInline`, not inlinable.
@usableFromInline
internal struct XPCKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

  @usableFromInline
  internal typealias StringKeyStrategy = XPCEncoder.StringKeyStrategy
  
  internal typealias StringValueStrategy = XPCEncoder.StringValueStrategy
  
  /// Always read the string-key strategy from the encoder.
  ///
  /// This paired annotation is retained for the measured per-key strategy read.
  @inlinable @inline(__always)
  internal var stringKeyStrategy: StringKeyStrategy { encoder.stringKeyStrategy }
  
  /// Always read the string-value strategy from the encoder.
  internal var stringValueStrategy: StringValueStrategy { encoder.stringValueStrategy }

  /// The immutable path at which this container was created.
  @usableFromInline
  internal let codingPath: [any CodingKey]

  // MARK: - Properties
  
  /// A reference to the encoder we're writing to.
  @usableFromInline
  internal let encoder: _XPCEncoder
  
  @usableFromInline
  internal let underlyingXPCDictionary: xpc_object_t
  
  // MARK: - Initialization
  
  /// Initializes `self` with the given references.
  ///
  /// - Parameters:
  ///   - encoder: The encoder whose configuration this container uses.
  ///   - dictionary: The XPC dictionary into which this container encodes.
  ///   - codingPath: The immutable path at which the container was created.
  internal init(
    referencing encoder: _XPCEncoder,
    wrapping dictionary: xpc_object_t,
    codingPath: [any CodingKey]
  ) throws {
    self.encoder = encoder
    self.codingPath = codingPath
    guard dictionary.isDictionary else {
      throw EncodingError.invalidValue(
        dictionary,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected a dictionary as xpc object, but got: \(xpc_get_type(dictionary).typeDescription)!"
        )
      )
    }
    self.underlyingXPCDictionary = dictionary
  }
 
  // MARK: - KeyedEncodingContainerProtocol
  
  @usableFromInline
  internal mutating func encodeNil(forKey key: Key) throws {
    underlyingXPCDictionary.setNil(
      forKey: key,
      strategy: stringKeyStrategy
    )
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Bool, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  /// Measured hot specialization for keyed `Int` values.
  @inlinable
  internal mutating func encode(_ value: Int, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int8, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int16, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int32, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int64, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }

  @usableFromInline
  internal mutating func encode(_ value: Int128, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }

  @usableFromInline
  internal mutating func encode(_ value: UInt, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt8, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt16, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt32, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt64, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }

  @usableFromInline
  internal mutating func encode(_ value: UInt128, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }

  @usableFromInline
  internal mutating func encode(_ value: String, forKey key: Key) throws {
    try actuallyEncodeStringValue(value, forKey: key)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Float, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Double, forKey key: Key) throws {
    try actuallyEncodeLosslesslyConvertibleValue(value, forKey: key)
  }
  
  @usableFromInline
  internal mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
    let codingPath = codingPath(appending: key)
    underlyingXPCDictionary.setValue(
      try _XPCEncoder.encode(
        value,
        at: codingPath,
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: stringValueStrategy,
        userInfo: encoder.userInfo
      ),
      forKey: key,
      strategy: stringKeyStrategy
    )
  }
  
  @usableFromInline
  internal mutating func nestedContainer<NestedKey>(
    keyedBy keyType: NestedKey.Type,
    forKey key: Key
  ) -> KeyedEncodingContainer<NestedKey> {
    do {
      let codingPath = codingPath(appending: key)
      let xpcDictionary = xpc_dictionary_create(nil, nil, 0)
      underlyingXPCDictionary.setValue(
        xpcDictionary,
        forKey: key,
        strategy: stringKeyStrategy
      )
      // It is OK to force this through because we know we are providing a dictionary
      let container = try XPCKeyedEncodingContainer<NestedKey>(
        referencing: encoder,
        wrapping: xpcDictionary,
        codingPath: codingPath
      )
      return KeyedEncodingContainer(container)
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

  @usableFromInline
  internal mutating func nestedUnkeyedContainer(
    forKey key: Key
  ) -> UnkeyedEncodingContainer {
    do {
      let codingPath = codingPath(appending: key)
      let xpcArray = xpc_array_create(nil, 0)
      underlyingXPCDictionary.setValue(
        xpcArray,
        forKey: key,
        strategy: stringKeyStrategy
      )

      return try XPCUnkeyedEncodingContainer(
        referencing: encoder,
        wrapping: xpcArray,
        codingPath: codingPath
      )
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

  @usableFromInline
  internal mutating func superEncoder() -> Encoder {
    _XPCDictionaryReferencingEncoder(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      codingPath: codingPath(appending: XPCCodingKey.superKey),
      userInfo: encoder.userInfo,
      codingKey: XPCCodingKey.superKey,
      dictionary: underlyingXPCDictionary
    )
  }

  @usableFromInline
  internal mutating func superEncoder(forKey key: Key) -> Encoder {
    _XPCDictionaryReferencingEncoder(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      codingPath: codingPath(appending: key),
      userInfo: encoder.userInfo,
      codingKey: key,
      dictionary: underlyingXPCDictionary
    )
  }
}


// MARK: - Support API

extension XPCKeyedEncodingContainer {

  /// Returns this container's immutable base path extended by `key`.
  internal func codingPath<ChildKey>(
    appending key: ChildKey
  ) -> [any CodingKey] where ChildKey: CodingKey {
    var codingPath = codingPath
    codingPath.append(key)
    return codingPath
  }

  /// Generic handler for losslessly-convertible values.
  ///
  /// Retained as the measured leaf joining keyed `Int` conversion to the
  /// direct XPC dictionary setter.
  @inlinable
  internal mutating func actuallyEncodeLosslesslyConvertibleValue(
    _ value: some LosslessXPCObjectConvertible,
    forKey key: Key
  ) throws {
    underlyingXPCDictionary.setValue(
      value,
      forKey: key,
      strategy: stringKeyStrategy
    )
  }

  /// Special-case handling for string values.
  internal mutating func actuallyEncodeStringValue(
    _ value: String,
    forKey key: Key
  ) throws {
    let xpcObject = try value.makeXPCObjectRepresentation(
      stringValueStrategy: stringValueStrategy,
      codingPath: codingPath(appending: key)
    )
    underlyingXPCDictionary.setValue(
      xpcObject,
      forKey: key,
      strategy: stringKeyStrategy
    )
  }

}
