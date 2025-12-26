import Foundation
@preconcurrency import XPC

extension xpc_type_t {
  
  @inlinable @inline(__always)
  internal var typeDescription: String {
    String(cString: xpc_type_get_name(self), encoding: .utf8) ?? "<unknown: \(String(reflecting: self))>"
  }
  
}

@TaskLocal
@usableFromInline
internal var sharedNullObject = xpc_null_create()

// MARK - Typechecks

extension xpc_object_t {
  
  @inlinable @inline(__always)
  internal func hasType(_ xpcType: xpc_type_t) -> Bool {
    xpc_get_type(self) == xpcType
  }

  @inlinable @inline(__always)
  internal var isNull: Bool {
    hasType(XPC_TYPE_NULL)
  }

  @inlinable @inline(__always)
  internal var isArray: Bool {
    hasType(XPC_TYPE_ARRAY)
  }

  @inlinable @inline(__always)
  internal var isDictionary: Bool {
    hasType(XPC_TYPE_DICTIONARY)
  }
  
  @inlinable @inline(__always)
  internal var typeDescription: String {
    xpc_get_type(self).typeDescription
  }

}

// MARK - Setters - Nil

extension xpc_object_t {
  
  @inlinable @inline(__always)
  internal func setNil(forKey key: some CodingKey) {
    setNil(forKey: key.stringValue)
  }
  
  @inlinable @inline(__always)
  internal func setNil(forKey key: any CodingKey) {
    setNil(forKey: key.stringValue)
  }
  
  @inlinable @inline(__always)
  internal func setNil(forKey key: String) {
    key.withCString { keyCString in
      xpc_dictionary_set_value(
        self,
        keyCString,
        sharedNullObject
      )
    }
  }
  
}

// MARK: - Value-Setting - Lossless

extension xpc_object_t {

  @inlinable @inline(__always)
  internal func setValue(_ value: some LosslessXPCObjectConvertible, forKey key: some CodingKey) {
    setValue(value.xpcObjectRepresentation, forKey: key.stringValue)
  }

  @inlinable @inline(__always)
  internal func setValue(_ value: some LosslessXPCObjectConvertible, forKey key: any CodingKey) {
    setValue(value.xpcObjectRepresentation, forKey: key.stringValue)
  }

  @inlinable @inline(__always)
  internal func setValue(_ value: some LosslessXPCObjectConvertible, forKey key: String) {
    setValue(value.xpcObjectRepresentation, forKey: key)
  }

}

// MARK: - Value-Setting - Direct

extension xpc_object_t {
  
  @inlinable @inline(__always)
  internal func setValue(_ value: xpc_object_t, forKey key: some CodingKey) {
    setValue(value, forKey: key.stringValue)
  }
  
  @inlinable @inline(__always)
  internal func setValue(_ value: xpc_object_t, forKey key: any CodingKey) {
    setValue(value, forKey: key.stringValue)
  }
  
  @inlinable @inline(__always)
  internal func setValue(_ value: xpc_object_t, forKey key: String) {
    key.withCString { keyCString in
      xpc_dictionary_set_value(
        self,
        keyCString,
        value
      )
    }
  }
  
}

// MARK: - Value-Appending

extension xpc_object_t {
  
  @inlinable @inline(__always)
  internal func appendValue(_ value: some LosslessXPCObjectConvertible) {
    assert(xpc_get_type(self) == XPC_TYPE_ARRAY)
    xpc_array_append_value(self, value.xpcObjectRepresentation)
  }
  
}

// MARK: - Decoding Support

extension xpc_object_t {
  
  @inlinable @inline(__always)
  func decodeNil(at codingPath: [CodingKey]) -> Bool {
    isNull
  }
  
  @usableFromInline
  func decodeNil(
    at codingPath: [CodingKey],
    forKey key: any CodingKey
  ) -> Bool {
    let possibleValue = key.stringValue.withCString { cString in
      xpc_dictionary_get_value(self, cString)
    }
    guard
      let value = possibleValue,
      value.hasType(XPC_TYPE_NULL)
    else {
      return false
    }
    
    return true
  }
  
}

