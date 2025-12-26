import XPC

@usableFromInline
internal final class _XPCDecoder: Decoder {

  @usableFromInline
  internal typealias StringKeyStrategy = XPCDecoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCDecoder.StringValueStrategy

  @usableFromInline
  internal let stringKeyStrategy: XPCDecoder.StringKeyStrategy

  @usableFromInline
  internal let stringValueStrategy: XPCDecoder.StringValueStrategy

  @usableFromInline
  internal let underlyingMessage: xpc_object_t
  
  @usableFromInline
  internal var _codingPath: [CodingKey]
  
  @usableFromInline
  internal var codingPath: [CodingKey] { _codingPath }
  
  
  @usableFromInline
  internal var userInfo: [CodingUserInfoKey : Any] = [:]
  
  @usableFromInline
  internal init(
    stringKeyStrategy: StringKeyStrategy,
    stringValueStrategy: StringValueStrategy,
    decoding message: xpc_object_t,
    at codingPath: [CodingKey] = [],
  ) {
    self.stringKeyStrategy = stringKeyStrategy
    self.stringValueStrategy = stringValueStrategy
    self.underlyingMessage = message
    self._codingPath = codingPath
  }
  
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

extension _XPCDecoder {

  @inlinable
  internal func withTransientCodingPathElement<Key, R>(
    _ codingPathElement: Key,
    _ closure: ([any CodingKey]) throws -> R
  ) throws -> R where Key: CodingKey {
    _codingPath.append(codingPathElement)
    defer {
#if DEBUG
      assert(!_codingPath.isEmpty)
      let popped = _codingPath.removeLast()
      // `CodingKey` isn't `Equatable`, so we instead compare its concrete representations:
      assert(popped.stringValue == codingPathElement.stringValue)
      assert(popped.intValue == codingPathElement.intValue)
#else
      _codingPath.removeLast()
#endif
    }
    let codingPath = _codingPath
    return try closure(codingPath)
  }
  

}

