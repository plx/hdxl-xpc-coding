import Foundation
@preconcurrency import XPC

extension xpc_type_t {
  
  @usableFromInline
  internal var typeDescription: String {
    String(cString: xpc_type_get_name(self), encoding: .utf8) ?? "<unknown: \(String(reflecting: self))>"
  }
  
}

@TaskLocal
@usableFromInline
internal var sharedNullObject = xpc_null_create()

// MARK - Typechecks

extension xpc_object_t {
  
  @inlinable
  internal func hasType(_ xpcType: xpc_type_t) -> Bool {
    xpc_get_type(self) == xpcType
  }
  
  @inlinable
  internal var isArray: Bool {
    hasType(XPC_TYPE_ARRAY)
  }

  @inlinable
  internal var isDictionary: Bool {
    hasType(XPC_TYPE_DICTIONARY)
  }
  
  @inlinable
  internal var typeDescription: String {
    xpc_get_type(self).typeDescription
  }

}

// MARK - Setters - CodingKey

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

extension xpc_object_t {
  
  @inlinable @inline(__always)
  internal func appendValue(_ value: some LosslessXPCObjectConvertible) {
    assert(xpc_get_type(self) == XPC_TYPE_ARRAY)
    xpc_array_append_value(self, value.xpcObjectRepresentation)
  }
  
}
