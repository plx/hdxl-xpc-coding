// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import XPC

// MARK: XPCUnkeyedDecodingContainer

/// The `UnkeyedDecodingContainer` implementation for `XPCDecoder`.
@usableFromInline
internal struct XPCUnkeyedDecodingContainer: UnkeyedDecodingContainer {
  
  @usableFromInline
  internal typealias StringKeyStrategy = XPCDecoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCDecoder.StringValueStrategy
  
  /// Always read the string key strategy from the decoder.
  @inlinable @inline(__always)
  internal var stringKeyStrategy: XPCDecoder.StringKeyStrategy { decoder.stringKeyStrategy }
  
  /// Always read the string value strategy from the decoder.
  @inlinable @inline(__always)
  internal var stringValueStrategy: XPCDecoder.StringValueStrategy { decoder.stringValueStrategy }

  /// The path of coding keys taken to get to this point in decoding (necessary to store @ creation for proper reporting).
  @usableFromInline
  internal let codingPath: [any CodingKey]

  /// The index of the next element to decode.
  @usableFromInline
  internal var currentIndex: Int
  
  /// The underlying XPC array.
  @usableFromInline
  internal let underlyingXPCArray: xpc_object_t
  
  /// The parent decoder.
  @usableFromInline
  internal let decoder: _XPCDecoder  

  /// The recursive decoding depth of this array below the root object.
  @usableFromInline
  internal let depth: Int

  // MARK: - Initialization

  /// Initialize a new unkeyed container.
  /// - Parameters:
  ///   - decoder: The decoder to use for decoding.
  ///   - wrapping: The XPC object to wrap.
  ///   - codingPath: The coding path to use for decoding.
  ///   - depth: The recursive decoding depth of this container.
  /// - Throws: `DecodingError.dataCorrupted` if the XPC object is not an array.
  @usableFromInline
  internal init(
    referencing decoder: _XPCDecoder,
    wrapping xpcObject: xpc_object_t,
    codingPath: [any CodingKey],
    depth: Int? = nil
  ) throws {
    guard xpcObject.isArray else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Did not find xpc array in unkeyed container."
        )
      )
    }

    try decoder.decodingState.validateContainerElementCount(
      xpc_array_get_count(xpcObject),
      codingPath: codingPath
    )
    
    self.underlyingXPCArray = xpcObject
    self.decoder = decoder
    self.codingPath = codingPath
    self.currentIndex = 0
    self.depth = depth ?? decoder.depth
  }

  // MARK: - UnkeyedDecodingContainer
  
  @inlinable  
  internal var count: Int? {
    _count
  }
  
  @inlinable
  internal mutating func decodeNil() throws -> Bool {
    guard !isAtEnd else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Reached end of unkeyed container."
        )
      )
    }
    
    return try withCurrentCodingKey { codingPath in
      let foundValue = xpc_array_get_value(underlyingXPCArray, currentIndex)
      try decoder.prepareToVisitChild(
        at: codingPath,
        depth: depth + 1
      )
      
      if foundValue.decodeNil(at: codingPath) {
        self.currentIndex += 1
        return true
      }
      return false
      
    }
  }
  
  @inlinable
  internal mutating func decode(_ type: Bool.Type) throws -> Bool {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: String.Type) throws -> String {
    try decodeNextStringValue()
  }
  
  @inlinable
  internal mutating func decode(_ type: Double.Type) throws -> Double {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: Float.Type) throws -> Float {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: Int.Type) throws -> Int {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: Int8.Type) throws -> Int8 {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: Int16.Type) throws -> Int16 {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: Int32.Type) throws -> Int32 {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: Int64.Type) throws -> Int64 {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: Int128.Type) throws -> Int128 {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: UInt.Type) throws -> UInt {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode(_ type: UInt128.Type) throws -> UInt128 {
    try decodeNextValue(as: type)
  }
  
  @inlinable
  internal mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
    let decoder = decoder
    let childDepth = depth + 1
    return try handleNextDecodingKeyValue { xpcValue, codingPath in
      try decoder.decodeVisitedValue(
        type,
        from: xpcValue,
        at: codingPath,
        depth: childDepth
      )
    }
  }
  
  @inlinable
  internal mutating func nestedContainer<NestedKey>(
    keyedBy type: NestedKey.Type
  ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
    let decoder = decoder
    let childDepth = depth + 1
    return try handleNextDecodingKeyValue { xpcValue, codingPath in
      KeyedDecodingContainer(
        try XPCKeyedDecodingContainer<NestedKey>(
          referencing: decoder,
          wrapping: xpcValue,
          codingPath: codingPath,
          depth: childDepth
        )
      )
    }
  }
  
  @inlinable
  internal mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
    let decoder = decoder
    let childDepth = depth + 1
    
    return try handleNextDecodingKeyValue { xpcValue, codingPath in
      try XPCUnkeyedDecodingContainer(
        referencing: decoder,
        wrapping: xpcValue,
        codingPath: codingPath,
        depth: childDepth
      )
    }
  }
  
  @inlinable
  internal mutating func superDecoder() throws -> Decoder {
    let stringKeyStrategy = stringKeyStrategy
    let stringValueStrategy = stringValueStrategy
    let decodingState = decoder.decodingState
    let userInfo = decoder.userInfo
    let childDepth = depth + 1
    
    return try handleNextDecodingKeyValue { xpcValue, codingPath in
      _XPCDecoder(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: stringValueStrategy,
        decoding: xpcValue,
        at: codingPath,
        userInfo: userInfo,
        decodingState: decodingState,
        depth: childDepth
      )
    }
  }
  
}

// MARK: - Support API

extension XPCUnkeyedDecodingContainer {
  
  /// The number of elements in the container.
  @usableFromInline
  internal var _count: Int {
    xpc_array_get_count(underlyingXPCArray)
  }
  
  /// True if we have reached the end of the container.
  @usableFromInline
  internal var isAtEnd: Bool {
    currentIndex >= _count
  }
  
  @inlinable
  internal var currentCodingKey: XPCCodingKey {
    XPCCodingKey(intValue: currentIndex)
  }

  /// Execute a closure with the current coding key added to the coding path.
  @usableFromInline
  internal func withCurrentCodingKey<R>(_ closure: ([any CodingKey]) throws -> R) throws -> R {
    var codingPath = codingPath
    codingPath.append(currentCodingKey)
    return try closure(codingPath)
  }
  
  /// Decode the next value in the container, with proper coding-path management.
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
    
    let foundValue = xpc_array_get_value(underlyingXPCArray, currentIndex)
    
    let interpretedValue = try withCurrentCodingKey { codingPath in
      try decoder.prepareToVisitChild(
        at: codingPath,
        depth: depth + 1
      )
      return try closure(foundValue, codingPath)
    }
    
    currentIndex += 1
    return interpretedValue
  }
  
  /// Decode the next value in the container, with proper coding-path management.
  @usableFromInline
  internal mutating func decodeNextValue<Value>(
    as valueType: Value.Type
  ) throws -> Value where Value: XPCObjectExtractable {
    let decoder = decoder
    return try handleNextDecodingKeyValue { xpcValue, codingPath in
      try decoder.extractVisitedValue(
        valueType,
        from: xpcValue,
        at: codingPath
      )
    }
  }

  /// Special-case logic for decoding string values.
  @usableFromInline
  internal mutating func decodeNextStringValue() throws -> String {
    let decoder = decoder
    return try handleNextDecodingKeyValue { xpcValue, codingPath in
      try decoder.extractVisitedString(
        from: xpcValue,
        at: codingPath
      )
    }
  }
  
}
