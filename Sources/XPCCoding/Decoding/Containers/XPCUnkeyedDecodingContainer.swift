import XPC

@usableFromInline
internal struct XPCUnkeyedDecodingContainer: UnkeyedDecodingContainer {
  
  @usableFromInline
  internal typealias StringKeyStrategy = XPCDecoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCDecoder.StringValueStrategy
  
  @inlinable @inline(__always)
  internal var stringKeyStrategy: XPCDecoder.StringKeyStrategy { decoder.stringKeyStrategy }
  
  @inlinable @inline(__always)
  internal var stringValueStrategy: XPCDecoder.StringValueStrategy { decoder.stringValueStrategy }

  // MARK: - Properties
  @usableFromInline
  internal var codingPath: [CodingKey]
  
  @usableFromInline
  internal var count: Int? {
    _count
  }
  
  @usableFromInline
  internal var _count: Int {
    xpc_array_get_count(underlyingMessage)
  }
  
  @usableFromInline
  internal var isAtEnd: Bool {
    currentIndex >= _count
  }
  
  @usableFromInline
  internal var _currentIndex: Int
  
  @usableFromInline
  internal var currentIndex: Int { _currentIndex }
  
  @usableFromInline
  internal let underlyingMessage: xpc_object_t
  
  @usableFromInline
  internal let decoder: _XPCDecoder
  
  @inlinable
  internal var currentCodingKey: XPCCodingKey {
    XPCCodingKey(intValue: _currentIndex)
  }
  
  // MARK: - Initilization
  @usableFromInline
  internal init(
    referencing decoder: _XPCDecoder,
    wrapping: xpc_object_t,
    codingPath: [any CodingKey]
  ) throws {
    guard wrapping.isArray else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Did not find xpc array in unkeyed container."
        )
      )
    }
    
    self.underlyingMessage = wrapping
    self.decoder = decoder
    self.codingPath = codingPath
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

  @usableFromInline
  internal mutating func decodeNextStringValue() throws -> String {
    let stringValueStrategy = stringValueStrategy

    return try handleNextDecodingKeyValue { xpcValue, codingPath in
      try xpcValue.extractStringValue(
        stringValueStrategy: stringValueStrategy,
        at: codingPath
      )
    }
  }

  // MARK: - UnkeyedDecodingContainer protocol methods
  
  @usableFromInline
  internal mutating func decodeNil() throws -> Bool {
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
  
  @usableFromInline
  internal mutating func decode(_ type: Bool.Type) throws -> Bool {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: String.Type) throws -> String {
    try decodeNextStringValue()
  }
  
  @usableFromInline
  internal mutating func decode(_ type: Double.Type) throws -> Double {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: Float.Type) throws -> Float {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: Int.Type) throws -> Int {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: Int8.Type) throws -> Int8 {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: Int16.Type) throws -> Int16 {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: Int32.Type) throws -> Int32 {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: Int64.Type) throws -> Int64 {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: Int128.Type) throws -> Int128 {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: UInt.Type) throws -> UInt {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode(_ type: UInt128.Type) throws -> UInt128 {
    try decodeNextValue(as: type)
  }
  
  @usableFromInline
  internal mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
    let stringKeyStrategy = stringKeyStrategy
    let stringValueStrategy = stringValueStrategy

    return try handleNextDecodingKeyValue { xpcValue, codingPath in
      if let directExtraction = xpcValue.attemptDirectExtraction(type, stringValueStrategy: stringValueStrategy) {
        return directExtraction
      }
      
      return try T(
        from: _XPCDecoder(
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: stringValueStrategy,
          decoding: xpcValue,
          at: codingPath
        )
      )
    }
  }
  
  @usableFromInline
  internal mutating func nestedContainer<NestedKey>(
    keyedBy type: NestedKey.Type
  ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
    let decoder = decoder
    return try handleNextDecodingKeyValue { xpcValue, codingPath in
      KeyedDecodingContainer(
        try XPCKeyedDecodingContainer<NestedKey>(
          referencing: decoder,
          wrapping: xpcValue,
          codingPath: codingPath
        )
      )
    }
  }
  
  @usableFromInline
  internal mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
    let decoder = decoder
    
    return try handleNextDecodingKeyValue { xpcValue, codingPath in
      try XPCUnkeyedDecodingContainer(
        referencing: decoder,
        wrapping: xpcValue,
        codingPath: codingPath
      )
    }
  }
  
  @usableFromInline
  internal mutating func superDecoder() throws -> Decoder {
    let stringKeyStrategy = stringKeyStrategy
    let stringValueStrategy = stringValueStrategy
    
    return try handleNextDecodingKeyValue { xpcValue, codingPath in
      _XPCDecoder(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: stringValueStrategy,
        decoding: xpcValue,
        at: codingPath
      )
    }
  }
  
}
