// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

// MARK: XPCObjectExtractable

/// Protocol for types that can be extracted-from an `xpc_object_t`.
///
/// Expected to be a round-trip for types that also conform to either ``XPCObjectConvertible``
/// or ``LosslessXPCObjectConvertible`` (at least for values that *are* xpc-compatible).
///
/// - SeeAlso: ``XPCObjectConvertible``
/// - SeeAlso: ``LosslessXPCObjectConvertible``
internal protocol XPCObjectExtractable {
  
  /// The "XPC object type" from-which we're able to extract a value.
  /// 
  /// - Note: for the cases we care about a single possible type is fine (no need for e.g. a set of possible representations).
  static var associatedXPCObjectType: xpc_type_t { get }

  /// Extract a value of this type from the given `xpc_object_t`, or `nil` if none can be found.
  /// 
  /// - Precondition: `object` has type `associatedXPCObjectType`; guaranteed when called via `extracting(from:)` convenience method.
  static func _extracting(from object: xpc_object_t) -> Self?
  
}

// MARK: - Convenience Methods

extension XPCObjectExtractable {

  /// Wrapper around `_extracting(from:)` that checks the object type on our behalf.
  static func extracting(from object: xpc_object_t) -> Self? {
    guard object.hasType(associatedXPCObjectType) else {
      return nil
    }
    return _extracting(from: object)
  }
  
}

// MARK: - XPCBinaryDataRepresentationConvertible Interop

extension XPCObjectExtractable where Self: XPCBinaryDataRepresentationConvertible {
  
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_DATA }
  
  /// Extracts a value from the *exact* bytes of an xpc data object.
  ///
  /// - Note: the length check comes first, so we never read from an xpc data object of the wrong length.
  /// - Note: `xpc_data_get_bytes_ptr` makes no alignment promise, so the extraction must be alignment-agnostic.
  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))

    let length = xpc_data_get_length(object)
    guard MemoryLayout<Self>.size == length else {
      return nil
    }

    let unsafeBaseAddress = infalliblyUnwrap(
      xpc_data_get_bytes_ptr(object),
      explanation: "`xpc_data_get_bytes_ptr` returns NULL only for non-data xpc objects, but `object`'s type was already checked above."
    )

    return Self(
      unsafeXPCBinaryDataRepresentationRawBufferPointer: UnsafeRawBufferPointer(
        start: unsafeBaseAddress,
        count: length
      )
    )
  }
  
}

// MARK: - Double Conformance

extension Double: XPCObjectExtractable {

  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_DOUBLE }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return xpc_double_get_value(object)
  }
  
}

// MARK: - Narrow Floating-Point Conformances

extension Float: XPCObjectExtractable {

  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_DOUBLE }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    let value = xpc_double_get_value(object)
    if value.isNaN {
      return Self(value)
    }
    return Self(exactly: value)
  }

}

extension Float16: XPCObjectExtractable {

  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_DOUBLE }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    let value = xpc_double_get_value(object)
    if value.isNaN {
      return Self(value)
    }
    return Self(exactly: value)
  }

}

// MARK: - Int64 Conformance

extension Int64: XPCObjectExtractable {

  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_INT64 }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return xpc_int64_get_value(object)
  }
  
}

// MARK: - Narrow Signed Integer Conformances

extension Int32: XPCObjectExtractable {

  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_INT64 }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return Self(exactly: xpc_int64_get_value(object))
  }

}

extension Int16: XPCObjectExtractable {

  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_INT64 }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return Self(exactly: xpc_int64_get_value(object))
  }

}

extension Int8: XPCObjectExtractable {

  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_INT64 }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return Self(exactly: xpc_int64_get_value(object))
  }

}

// MARK: - UInt64 Conformance

extension UInt64: XPCObjectExtractable {
  
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_UINT64 }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return xpc_uint64_get_value(object)
  }
  
}

// MARK: - Narrow Unsigned Integer Conformances

extension UInt32: XPCObjectExtractable {

  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_UINT64 }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return Self(exactly: xpc_uint64_get_value(object))
  }

}

extension UInt16: XPCObjectExtractable {

  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_UINT64 }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return Self(exactly: xpc_uint64_get_value(object))
  }

}

extension UInt8: XPCObjectExtractable {

  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_UINT64 }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return Self(exactly: xpc_uint64_get_value(object))
  }

}

// MARK: - Int Conformance

extension Int: XPCObjectExtractable {

  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_INT64 }

  static func _extracting(from object: xpc_object_t) -> Self? {
    guard let value = Int64.extracting(from: object) else {
      return nil
    }
    return Self(exactly: value)
  }

}

// MARK: - UInt Conformance

extension UInt: XPCObjectExtractable {
  
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_UINT64 }

  static func _extracting(from object: xpc_object_t) -> Self? {
    guard let value = UInt64.extracting(from: object) else {
      return nil
    }
    return Self(exactly: value)
  }
  
}

// MARK: - Data Conformance

extension Data: XPCObjectExtractable {
  
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_DATA }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    let length = xpc_data_get_length(object)
    guard length > 0 else {
      return Self()
    }
    var result = Data(repeating: 0, count: length)
    let copiedOK = result.withUnsafeMutableBytes { unsafeMutableBufferPtr in
      let baseAddress = infalliblyUnwrap(
        unsafeMutableBufferPtr.baseAddress,
        explanation: "`UnsafeMutableRawBufferPointer.baseAddress` is nil only for empty buffers, but we already early-returned for `length == 0`."
      )

      let copiedAmount = xpc_data_get_bytes(
        object,
        baseAddress,
        0,
        length
      )
      return copiedAmount == length
    }
    guard copiedOK else {
      return nil
    }

    return result
  }
  
}

// MARK: - Bool Conformance

extension Bool: XPCObjectExtractable {
  
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_BOOL }

  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return xpc_bool_get_value(object)
  }
  
}


// MARK: - Synthesized Conformances

extension Int128: XPCObjectExtractable { }

extension UInt128: XPCObjectExtractable { }
