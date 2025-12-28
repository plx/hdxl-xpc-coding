import XPC

@usableFromInline
internal final class XPCKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {

  @usableFromInline
  internal typealias StringKeyStrategy = XPCDecoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCDecoder.StringValueStrategy
  
  @inlinable @inline(__always)
  internal var stringKeyStrategy: XPCDecoder.StringKeyStrategy { decoder.stringKeyStrategy }
  
  @inlinable @inline(__always)
  internal var stringValueStrategy: XPCDecoder.StringValueStrategy { decoder.stringValueStrategy }
  
  // MARK: - Properties
  
  /// A reference to the decoder we're reading from.
  @usableFromInline
  internal let decoder: _XPCDecoder
  
  /// The path of coding keys taken to get to this point in decoding.
  @usableFromInline
  internal var codingPath: [CodingKey]
  
  @usableFromInline
  internal let underlyingMessage: xpc_object_t
  
  // MARK: - Initialization
  
  /// Initializes `self` by referencing the given decoder and container.
  @usableFromInline
  internal init(
    referencing decoder: _XPCDecoder,
    wrapping underlyingMessage: xpc_object_t,
    codingPath: [any CodingKey]
  ) throws {
    guard underlyingMessage.isDictionary else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Did not find xpc dictionary in keyed container"
        )
      )
    }
    self.decoder = decoder
    self.underlyingMessage = underlyingMessage
    self.codingPath = codingPath
  }
  
  // MARK: - KeyedDecodingContainerProtocol
  
  @usableFromInline
  internal var allKeys: [Key] {
    var keys: [Key] = []
    let embeddedNullByteRepresentation = stringKeyStrategy.embeddedNullByteRepresentation
    xpc_dictionary_apply(underlyingMessage) { (keyCString, _) -> Bool in
      guard
        let keyString = String(
          cString: keyCString,
          embeddedNullByteRepresentation: embeddedNullByteRepresentation
        ),
        let key = Key(stringValue: keyString)
      else {
        return true
      }
      
      keys.append(key)
      return true
    }
    return keys
  }
  
  @usableFromInline
  internal func contains(_ key: Key) -> Bool {
    key.withUTF8CString(embeddedNullByteRepresentation: stringKeyStrategy.embeddedNullByteRepresentation) { keyCString in
      nil != xpc_dictionary_get_value(underlyingMessage, keyCString)
    }
  }
  
  @inlinable
  internal func decodeNil(forKey key: Key) throws -> Bool {
    try withTransientCodingKey(key) { codingPath in
      underlyingMessage.decodeNil(
        at: codingPath,
        forKey: key
      )
    }
  }
  
  @inlinable
  internal func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    try extractValue(ofType: type, forKey: key)
  }
    
  @inlinable
  internal func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    try extractValue(ofType: type, forKey: key)
  }

  @inlinable
  internal func decode(_ type: Int128.Type, forKey key: Key) throws -> Int128 {
    try extractValue(ofType: type, forKey: key)
  }

  @inlinable
  internal func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    try extractValue(ofType: type, forKey: key)
  }

  @inlinable
  internal func decode(_ type: UInt128.Type, forKey key: Key) throws -> UInt128 {
    try extractValue(ofType: type, forKey: key)
  }

  @inlinable
  internal func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    try extractValue(ofType: type, forKey: key)
  }
  
  @inlinable
  internal func decode(_ type: String.Type, forKey key: Key) throws -> String {
    try extractString(forKey: key)
  }
  
  @inlinable
  internal func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
    try withTransientCodingKey(key) { codingPath in
      let xpcObject = try getXPCObject(for: key)

      if let directExtraction = xpcObject.attemptDirectExtraction(type, stringValueStrategy: stringValueStrategy) {
        return directExtraction
      }
      
      return try T(
        from: _XPCDecoder(
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: stringValueStrategy,
          decoding: xpcObject,
          at: codingPath
        )
      )
    }
  }
  
  @inlinable
  internal func nestedContainer<NestedKey>(
    keyedBy type: NestedKey.Type,
    forKey key: Key
  ) throws -> KeyedDecodingContainer<NestedKey> {
    try withTransientCodingKey(key) { codingPath in
      let xpcObject = try getXPCObject(for: key)
      
      let container = try XPCKeyedDecodingContainer<NestedKey>(
        referencing: decoder,
        wrapping: xpcObject,
        codingPath: codingPath
      )
      
      return KeyedDecodingContainer<NestedKey>(container)
    }
  }
  
  @inlinable
  internal func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    try withTransientCodingKey(key) { codingPath in
      try XPCUnkeyedDecodingContainer(
        referencing: decoder,
        wrapping: try getXPCObject(for: key),
        codingPath: codingPath
      )
    }
  }
  
  @inlinable
  internal func superDecoder() throws -> Decoder {
    try withTransientCodingKey(XPCCodingKey.superKey) { codingPath in
      _XPCDecoder(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: stringValueStrategy,
        decoding: try getXPCObject(for: XPCCodingKey.superKey),
        at: codingPath
      )
    }
  }
  
  @inlinable
  internal func superDecoder(forKey key: Key) throws -> Decoder {
    try withTransientCodingKey(key) { codingPath in
      _XPCDecoder(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: stringValueStrategy,
        decoding: try getXPCObject(for: key),
        at: codingPath
      )
    }
  }
}

// MARK: - Support

extension XPCKeyedDecodingContainer {
  
  
  @usableFromInline
  internal func getXPCObject(for key: CodingKey) throws -> xpc_object_t {
    
    let possibleValue = key.withUTF8CString(embeddedNullByteRepresentation: stringKeyStrategy.embeddedNullByteRepresentation) { keyCString in
      xpc_dictionary_get_value(underlyingMessage, keyCString)
    }
    guard let value = possibleValue else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "No value found for key \(key.stringValue)"
        )
      )
    }
    
    return value
  }

  @inlinable
  internal func withTransientCodingKey<R>(
    _ key: Key,
    _ closure: ([any CodingKey]) throws -> R
  ) throws -> R {
    codingPath.append(key)
    defer {
#if DEBUG
      let poppedKey = codingPath.removeLast()
      assert(poppedKey.stringValue == key.stringValue)
      assert(poppedKey.intValue == key.intValue)
#else
      let _ = codingPath.removeLast()
#endif
    }
    return try closure(codingPath)
  }
  
  @inlinable
  internal func withTransientCodingKey<R>(
    _ key: XPCCodingKey,
    _ closure: ([any CodingKey]) throws -> R
  ) throws -> R {
    codingPath.append(key)
    defer {
#if DEBUG
      let poppedKey = codingPath.removeLast()
      assert(poppedKey.stringValue == key.stringValue)
      assert(poppedKey.intValue == key.intValue)
#else
      let _ = codingPath.removeLast()
#endif
    }
    return try closure(codingPath)
  }
  
  @inlinable
  internal func extractValue<Value>(
    ofType valueType: Value.Type,
    forKey key: Key
  ) throws -> Value where Value: XPCObjectExtractable {
    try withTransientCodingKey(key) { codingPath in
      try underlyingMessage.extractValue(
        ofType: valueType,
        at: codingPath,
        forKey: key,
        stringKeyStrategy: stringKeyStrategy
      )
    }
  }

  @inlinable
  internal func extractString(
    forKey key: Key
  ) throws -> String {
    try withTransientCodingKey(key) { codingPath in
      try underlyingMessage.extractString(
        at: codingPath,
        forKey: key,
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: stringValueStrategy
      )
    }
  }

}
