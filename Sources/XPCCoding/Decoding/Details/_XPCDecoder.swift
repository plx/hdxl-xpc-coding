import XPC

/// The internal `_XPCDecoder` implementation.
@usableFromInline
internal final class _XPCDecoder: Decoder {

  @usableFromInline
  internal typealias StringKeyStrategy = XPCDecoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCDecoder.StringValueStrategy

  /// The strategy to use for decoding `String` keys.
  @usableFromInline
  internal let stringKeyStrategy: XPCDecoder.StringKeyStrategy

  /// The strategy to use for decoding `String` values.
  @usableFromInline
  internal let stringValueStrategy: XPCDecoder.StringValueStrategy

  /// The underlying XPC message.
  @usableFromInline
  internal let underlyingMessage: xpc_object_t
  
  /// The current coding path.
  @usableFromInline
  internal var codingPath: [CodingKey]
    
  @usableFromInline
  internal var userInfo: [CodingUserInfoKey : Any] = [:]
  
  @usableFromInline
  internal init(
    stringKeyStrategy: StringKeyStrategy,
    stringValueStrategy: StringValueStrategy,
    decoding message: xpc_object_t,
    at codingPath: [CodingKey] = [],
    userInfo: [CodingUserInfoKey : Any] = [:]
  ) {
    self.stringKeyStrategy = stringKeyStrategy
    self.stringValueStrategy = stringValueStrategy
    self.underlyingMessage = message
    self.codingPath = codingPath
    self.userInfo = userInfo
  }
  
  // MARK: - Decoder

  @usableFromInline
  internal func container<Key>(
    keyedBy type: Key.Type
  ) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
    let container = try XPCKeyedDecodingContainer<Key>(
      referencing: self,
      wrapping: underlyingMessage,
      codingPath: codingPath
    )
    return KeyedDecodingContainer(container)
  }
  
  @usableFromInline
  internal func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    try XPCUnkeyedDecodingContainer(
      referencing: self,
      wrapping: underlyingMessage,
      codingPath: codingPath
    )
  }
  
  @usableFromInline
  internal func singleValueContainer() throws -> SingleValueDecodingContainer {
    XPCSingleValueDecodingContainer(
      referencing: self,
      wrapping: underlyingMessage,
      codingPath: codingPath
    )
  }
  
}

// MARK: - Support API

extension _XPCDecoder {

  @inlinable
  internal func withTransientCodingPathElement<Key, R>(
    _ codingPathElement: Key,
    _ closure: ([any CodingKey]) throws -> R
  ) throws -> R where Key: CodingKey {
    codingPath.append(codingPathElement)
    defer {
#if DEBUG
      assert(!codingPath.isEmpty)
      let popped = codingPath.removeLast()
      // `CodingKey` isn't `Equatable`, so we instead compare its concrete representations:
      assert(popped.stringValue == codingPathElement.stringValue)
      assert(popped.intValue == codingPathElement.intValue)
#else
      codingPath.removeLast()
#endif
    }
    let codingPath = codingPath
    return try closure(codingPath)
  }
  
}

