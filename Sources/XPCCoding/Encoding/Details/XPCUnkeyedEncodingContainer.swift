// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

// MARK: XPCUnkeyedEncodingContainer

/// Our internal unkeyed encoding container.
@usableFromInline
internal struct XPCUnkeyedEncodingContainer: UnkeyedEncodingContainer {

  @usableFromInline
  internal typealias StringKeyStrategy = XPCEncoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCEncoder.StringValueStrategy
  
  /// We always retrieve our string key strategy from our parent encoder.
  @inlinable @inline(__always)
  internal var stringKeyStrategy: StringKeyStrategy { encoder.stringKeyStrategy }
  
  /// We always retrieve our string value strategy from our parent encoder.
  @inlinable @inline(__always)
  internal var stringValueStrategy: StringValueStrategy { encoder.stringValueStrategy }

  /// The immutable path at which this container was created.
  @usableFromInline
  internal let codingPath: [any CodingKey]
  
  /// Count of already-encoded items in this container.
  @usableFromInline
  internal var count: Int {
    xpc_array_get_count(underlyingXPCArray)
  }
  
  /// The encoder into-which we're doing our encoding.
  @usableFromInline
  internal let encoder: _XPCEncoder
  
  /// The underlying XPC array we're encoding into.
  @usableFromInline
  internal let underlyingXPCArray: xpc_object_t
  
  // MARK: - Initialization

  /// Memberwise-initialize a new unkeyed encoding container.
  /// - Parameters:
  ///   - encoder: The encoder into-which we're doing our encoding.
  ///   - underlyingXPCArray: The underlying XPC array we're encoding into.
  ///   - codingPath: The immutable path at which the container was created.
  /// - Throws: `EncodingError.invalidValue` if `underlyingXPCArray` is not an XPC array.
  @usableFromInline
  internal init(
    referencing encoder: _XPCEncoder,
    wrapping underlyingXPCArray: xpc_object_t,
    codingPath: [any CodingKey]
  ) throws {
    self.encoder = encoder
    self.codingPath = codingPath
    
    guard underlyingXPCArray.isArray else {
      throw EncodingError.invalidValue(
        underlyingXPCArray,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "Supplied a non-array xpc object (actual type: `\(underlyingXPCArray.typeDescription))"
        )
      )
    }
    
    self.underlyingXPCArray = underlyingXPCArray
  }

  // MARK: - UnkeyedEncodingContainer
  
  @usableFromInline
  internal mutating func encodeNil() throws {
    xpc_array_append_value(underlyingXPCArray, xpc_null_create())
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Bool) throws {
    appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode(_ value: String) throws {
    // string needs special handling to respect our string-value strategy
    try appendNextStringValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Double) throws {
    appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Float) throws {
    appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int) throws {
    appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int8) throws {
    appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int16) throws {
    appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int32) throws {
    appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int64) throws {
    appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode(_ value: Int128) throws {
    appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode(_ value: UInt) throws {
    appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt8) throws {
    appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt16) throws {
    appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt32) throws {
    appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt64) throws {
    appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode(_ value: UInt128) throws {
    appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode<T: Encodable>(_ value: T) throws {
    try withNextCodingKey { codingPath in
      let xpcObject = try _XPCEncoder.encode(
        value,
        at: codingPath,
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: stringValueStrategy,
        userInfo: encoder.userInfo
      )
      xpc_array_append_value(underlyingXPCArray, xpcObject)
    }
  }
  
  @usableFromInline
  internal mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
    do {
      return try withNextCodingKey { codingPath in
        let xpcDictionary = xpc_dictionary_create(nil, nil, 0)
        xpc_array_append_value(underlyingXPCArray, xpcDictionary)

        let container = try XPCKeyedEncodingContainer<NestedKey>(
          referencing: encoder,
          wrapping: xpcDictionary,
          codingPath: codingPath
        )
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
      return try withNextCodingKey { codingPath in
        let xpcArray = xpc_array_create(nil, 0)
        xpc_array_append_value(underlyingXPCArray, xpcArray)

        return try XPCUnkeyedEncodingContainer(
          referencing: encoder,
          wrapping: xpcArray,
          codingPath: codingPath
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

  @usableFromInline
  internal mutating func superEncoder() -> Encoder {
    do {
      return try withNextCodingKey { codingPath in
        // TODO: investigate if we can refactor so as to avoid injecting this placeholder value
        xpc_array_append_value(underlyingXPCArray, xpc_null_create())
        return _XPCArrayReferencingEncoder(
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: stringValueStrategy,
          codingPath: codingPath,
          userInfo: encoder.userInfo,
          index: count - 1,
          array: underlyingXPCArray
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

// MARK: - Support API

extension XPCUnkeyedEncodingContainer {
  
  /// The coding key suitable-for appending our next encoded value.
  @usableFromInline
  internal var nextCodingKey: XPCCodingKey {
    XPCCodingKey(intValue: count)
  }
  
  /// Executes `closure` with our immutable base path extended by `nextCodingKey`.
  /// 
  /// - Parameter closure: The closure to execute.
  /// - Returns: The return value of `closure`.
  /// - Throws: Any error thrown by `closure`.
  /// 
  /// - SeeAlso: ``nextCodingKey``
  @inlinable
  internal func withNextCodingKey<R>(_ closure: ([any CodingKey]) throws -> R) throws -> R {
    var codingPath = codingPath
    codingPath.append(nextCodingKey)
    return try closure(codingPath)
  }
  
  /// Directly appends an XPC object to our underlying XPC array.
  @inlinable
  internal func appendNextXPCValue(_ value: xpc_object_t) {
    xpc_array_append_value(underlyingXPCArray, value)
  }

  /// Directly appends a losslessly-convertible value to our underlying XPC array.
  @inlinable
  internal func appendNextLosslesslyConvertibleValue(_ value: some LosslessXPCObjectConvertible) {
    appendNextXPCValue(value.xpcObjectRepresentation)
  }

  /// Directly appends a string value to our underlying XPC array, with proper coding-path management (and ensuring proper string-value strategy handling). 
  @inlinable
  internal func appendNextStringValue(_ value: String) throws {
    try withNextCodingKey { codingPath in
      let xpcObject = try value.makeXPCObjectRepresentation(
        stringValueStrategy: stringValueStrategy,
        codingPath: codingPath
      )
      xpc_array_append_value(underlyingXPCArray, xpcObject)
    }
  }
}

// MARK: - XPCEnhancedUnkeyedEncodingContainer

extension XPCUnkeyedEncodingContainer: XPCEnhancedUnkeyedEncodingContainer {
    
  @inlinable
  internal mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeRawPointer?,
    count: Int
  ) throws {
    try validateUnsafePointerCount(
      unsafePointer,
      count: count,
      codingPath: codingPath
    )
    appendNextXPCValue(
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
    try validateUnsafePointerCount(
      unsafePointer,
      count: count,
      codingPath: codingPath
    )
    appendNextXPCValue(
      xpc_data_create(
        unsafePointer.map { UnsafeRawPointer($0) },
        count
      )
    )
  }
  
  @inlinable
  internal mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeRawBufferPointer) throws {
    try directlyEncodeXPCData(
      unsafeBufferPointer.baseAddress,
      count: unsafeBufferPointer.count
    )
  }
  
  @inlinable
  internal mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeMutableRawBufferPointer) throws {
    try directlyEncodeXPCData(
      unsafeBufferPointer.baseAddress,
      count: unsafeBufferPointer.count
    )
  }
 
}
