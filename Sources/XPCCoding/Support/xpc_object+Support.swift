// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
@preconcurrency import XPC

extension xpc_type_t {
  
  /// Shorthand for `xpc_type_get_name(self)`
  internal var typeDescription: String {
    String(cString: xpc_type_get_name(self))
  }
  
}

// MARK: - Typechecks

extension xpc_object_t {
  
  /// `true` if `self` is of type `xpcType`
  internal func hasType(_ xpcType: xpc_type_t) -> Bool {
    xpc_get_type(self) == xpcType
  }

  /// `true` if `self` is `XPC_TYPE_NULL`
  internal var isNull: Bool {
    hasType(XPC_TYPE_NULL)
  }

  /// `true` if `self` is `XPC_TYPE_ARRAY`
  internal var isArray: Bool {
    hasType(XPC_TYPE_ARRAY)
  }

  /// `true` if `self` is `XPC_TYPE_DICTIONARY`
  internal var isDictionary: Bool {
    hasType(XPC_TYPE_DICTIONARY)
  }
  
  /// Shorthand for `xpc_get_type(self).typeDescription`
  internal var typeDescription: String {
    xpc_get_type(self).typeDescription
  }

}

// MARK: - Setters - Nil

extension xpc_object_t {
  
  /// Sets `nil` for `key`, using the indicated `strategy` for the `key`'s string representation.
  internal func setNil(
    forKey key: some CodingKey,
    strategy: XPCEncoder.StringKeyStrategy
  ) {
    setNil(
      forKey: key.stringValue,
      strategy: strategy
    )
  }

  /// Sets `nil` for `key`, using the indicated `strategy` for the `key`.
  internal func setNil(
    forKey key: String,
    strategy: XPCEncoder.StringKeyStrategy
  ) {
    key.withUTF8CString(stringKeyStrategy: strategy) { keyCString in
      xpc_dictionary_set_value(
        self,
        keyCString,
        xpc_null_create()
      )
    }
  }
  
}

// MARK: - Value-Setting - Lossless

extension xpc_object_t {

  /// Sets `value` for `key`, using the indicated `strategy` for the `key`'s string representation.
  ///
  /// Inlining audit rationale: compiler-required ABI dependency of the measured
  /// keyed lossless-conversion helper; the setter body is not inlinable.
  @usableFromInline
  internal func setValue(
    _ value: some LosslessXPCObjectConvertible,
    forKey key: some CodingKey,
    strategy: XPCEncoder.StringKeyStrategy
  ) {
    setValue(
      value.xpcObjectRepresentation,
      forKey: key.stringValue,
      strategy: strategy
    )
  }

  /// Sets `value` for `key`, using the indicated `strategy` for the `key`.
  internal func setValue(
    _ value: some LosslessXPCObjectConvertible,
    forKey key: String,
    strategy: XPCEncoder.StringKeyStrategy
  ) {
    setValue(
      value.xpcObjectRepresentation,
      forKey: key,
      strategy: strategy
    )
  }

}

// MARK: - Value-Setting - Direct

extension xpc_object_t {
  
  /// Sets `value` for `key`, using the indicated `strategy` for the `key`'s string representation.
  ///
  /// - Note: there are two `CodingKey`-taking overloads here: a `some CodingKey` variant that
  ///   specializes for the common case where a concrete generic key type is known at the call
  ///   site (e.g. inside `XPCKeyedEncodingContainer`), and an `any CodingKey` variant that handles
  ///   the existential case used by `_XPCDictionaryReferencingEncoder.codingKey`.
  internal func setValue(
    _ value: xpc_object_t,
    forKey key: some CodingKey,
    strategy: XPCEncoder.StringKeyStrategy
  ) {
    setValue(
      value,
      forKey: key.stringValue,
      strategy: strategy
    )
  }

  /// Sets `value` for `key`, using the indicated `strategy` for the `key`'s string representation.
  ///
  /// Retained with the string overload below as the measured direct XPC
  /// dictionary-setting leaf for existential keys.
  @inlinable @inline(__always)
  internal func setValue(
    _ value: xpc_object_t,
    forKey key: any CodingKey,
    strategy: XPCEncoder.StringKeyStrategy
  ) {
    setValue(
      value,
      forKey: key.stringValue,
      strategy: strategy
    )
  }

  /// Sets `value` for `key`, using the indicated `strategy` for the `key`.
  ///
  /// Retained with the existential-key overload above as the measured C-string
  /// bridge and dictionary-write leaf.
  @inlinable @inline(__always)
  internal func setValue(
    _ value: xpc_object_t,
    forKey key: String,
    strategy stringKeyStrategy: XPCEncoder.StringKeyStrategy
  ) {
    key.withUTF8CString(stringKeyStrategy: stringKeyStrategy) { keyCString in
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
  
  /// Appends `value` to `self`.
  internal func appendValue(_ value: some LosslessXPCObjectConvertible) {
    assert(xpc_get_type(self) == XPC_TYPE_ARRAY)
    xpc_array_append_value(self, value.xpcObjectRepresentation)
  }
  
}

// MARK: - Decoding Support

extension xpc_object_t {
  
  /// `true` if `self` is actually an `XPC_TYPE_NULL`.
  /// 
  /// - Note: `codingPath` is supplied for diagnostics.
  func decodeNil(at codingPath: [CodingKey]) -> Bool {
    isNull
  }
  
  /// `true` if an explicit `nil` value is encoded into this object under `key` (using `strategy`).
  /// 
  /// - Note: `codingPath` is supplied for diagnostics.
  func decodeNil(
    at codingPath: [CodingKey],
    forKey key: any CodingKey,
    strategy stringKeyStrategy: XPCDecoder.StringKeyStrategy
  ) -> Bool {
    let possibleValue = key.stringValue.withUTF8CString(stringKeyStrategy: stringKeyStrategy) { cString in
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
