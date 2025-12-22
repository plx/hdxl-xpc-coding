// Sources/CodableXPC/XPCUnkeyedDecodingContainer.swift -
// UnkeyedDecodingContainer for XPC
//
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// -----------------------------------------------------------------------------
//
// This file contains a UnkeyedDecodingContainer implementation for
// xpc_object_t.
//
// -----------------------------------------------------------------------------//

import XPC

@usableFromInline
internal struct XPCUnkeyedDecodingContainer: UnkeyedDecodingContainer {
  
  // MARK: - Properties
  public var codingPath: [CodingKey] {
    decoder.codingPath
  }
  
  public var count: Int? {
    _count
  }
  
  @usableFromInline
  internal var _count: Int {
    xpc_array_get_count(underlyingMessage)
  }
  
  public var isAtEnd: Bool {
    currentIndex >= _count
  }
  
  @usableFromInline
  internal var _currentIndex: Int
  
  public var currentIndex: Int { _currentIndex }
  
  private let underlyingMessage: xpc_object_t
  
  private let decoder: XPCDecoder
  
  @inlinable
  internal var currentCodingKey: XPCCodingKey {
    XPCCodingKey(intValue: _currentIndex)
  }
  
  // MARK: - Initilization
  init(referencing decoder: XPCDecoder, wrapping: xpc_object_t) throws {
    guard xpc_get_type(wrapping) == XPC_TYPE_ARRAY else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath,
                                                              debugDescription: "Did not find xpc array in unkeyed container."))
    }
    
    self.underlyingMessage = wrapping
    self.decoder = decoder
    self._currentIndex = 0
  }
  
  @usableFromInline
  internal func withCurrentCodingKey<R>(_ closure: ([any CodingKey]) throws -> R) throws -> R {
    try decoder.withTransientCodingPathElement(currentCodingKey, closure)
  }
  
  @usableFromInline
  internal mutating func handleNextDecodingKeyValue<R>(_ closure: (xpc_object_t, [any CodingKey]) throws -> R) throws -> R {
    guard !isAtEnd else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Reached end of unkeyed container."
        )
      )
    }
      
    let foundValue = xpc_array_get_value(underlyingMessage, currentIndex)
    
    let interpretedValue = try decoder.withTransientCodingPathElement(currentCodingKey) { codingPath in
      try closure(foundValue, codingPath)
    }
    
    _currentIndex += 1
    return interpretedValue
  }

  @usableFromInline
  internal mutating func decodeNextValue<Value>(
    as valueType: Value.Type
  ) throws -> Value where Value: XPCObjectExtractable {
    try handleNextDecodingKeyValue { xpcValue, codingPath in
      try xpcValue.extractValue(
        ofType: valueType,
        at: codingPath
      )
    }
  }

  
  // MARK: - UnkeyedDecodingContainer protocol methods
  public mutating func decodeNil() throws -> Bool {
    guard !isAtEnd else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Reached end of unkeyed container."
        )
      )
    }

    return try withCurrentCodingKey { _ in
      let foundValue = xpc_array_get_value(underlyingMessage, currentIndex)
      
      if foundValue.decodeNil(at: codingPath) {
        self._currentIndex += 1
        return true
      }
      return false

    }
  }
  
  public mutating func decode(_ type: Bool.Type) throws -> Bool {
    try decodeNextValue(as: type)
  }
  
  public mutating func decode(_ type: String.Type) throws -> String {
    try decodeNextValue(as: type)
  }
  
  public mutating func decode(_ type: Double.Type) throws -> Double {
    try decodeNextValue(as: type)
  }
  
  public mutating func decode(_ type: Float.Type) throws -> Float {
    try decodeNextValue(as: type)
  }
  
  public mutating func decode(_ type: Int.Type) throws -> Int {
    try decodeNextValue(as: type)
  }
  
  public mutating func decode(_ type: Int8.Type) throws -> Int8 {
    try decodeNextValue(as: type)
  }
  
  public mutating func decode(_ type: Int16.Type) throws -> Int16 {
    try decodeNextValue(as: type)
  }
  
  public mutating func decode(_ type: Int32.Type) throws -> Int32 {
    try decodeNextValue(as: type)
  }
  
  public mutating func decode(_ type: Int64.Type) throws -> Int64 {
    try decodeNextValue(as: type)
  }

  public mutating func decode(_ type: Int128.Type) throws -> Int128 {
    try decodeNextValue(as: type)
  }

  public mutating func decode(_ type: UInt.Type) throws -> UInt {
    try decodeNextValue(as: type)
  }
  
  public mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
    try decodeNextValue(as: type)
  }
  
  public mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
    try decodeNextValue(as: type)
  }
  
  public mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
    try decodeNextValue(as: type)
  }
  
  public mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
    try decodeNextValue(as: type)
  }

  public mutating func decode(_ type: UInt128.Type) throws -> UInt128 {
    try decodeNextValue(as: type)
  }

  public mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
    try handleNextDecodingKeyValue { xpcValue, codingPath in
      return try T(
        from: XPCDecoder(
          underlyingMessage: xpcValue,
          at: codingPath
        )
      )
    }
  }
  
  public mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
    let decoder = decoder
    return try handleNextDecodingKeyValue { xpcValue, _ in
      KeyedDecodingContainer(
        try XPCKeyedDecodingContainer<NestedKey>(
          referencing: decoder,
          wrapping: xpcValue
        )
      )
    }
  }
  
  public mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
    let decoder = decoder
    
    return try handleNextDecodingKeyValue { xpcValue, _ in
      try XPCUnkeyedDecodingContainer(
        referencing: decoder,
        wrapping: xpcValue
      )
    }
  }
  
  public mutating func superDecoder() throws -> Decoder {
    try handleNextDecodingKeyValue { xpcValue, codingPath in
      XPCDecoder(
        underlyingMessage: xpcValue,
        at: codingPath
      )
    }
  }
}

