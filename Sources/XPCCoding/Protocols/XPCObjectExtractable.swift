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
@usableFromInline
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
  @usableFromInline
  static func extracting(from object: xpc_object_t) -> Self? {
    guard object.hasType(associatedXPCObjectType) else {
      return nil
    }
    return _extracting(from: object)
  }
  
}

// MARK: - XPCBinaryDataRepresentationConvertible Interop

extension XPCObjectExtractable where Self: XPCBinaryDataRepresentationConvertible {
  
  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_DATA }
  
  @usableFromInline
  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))

    let length = xpc_data_get_length(object)
    guard MemoryLayout<Self>.size == length else {
      return nil
    }
    
    let unsafeBaseAddress = xpc_data_get_bytes_ptr(object)!
    
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

  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_DOUBLE }

  @usableFromInline
  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return xpc_double_get_value(object)
  }
  
}

// MARK: - Int64 Conformance

extension Int64: XPCObjectExtractable {

  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_INT64 }

  @usableFromInline
  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return xpc_int64_get_value(object)
  }
  
}

// MARK: - UInt64 Conformance

extension UInt64: XPCObjectExtractable {
  
  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_UINT64 }

  @usableFromInline
  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return xpc_uint64_get_value(object)
  }
  
}

// MARK: - Int Conformance

extension Int: XPCObjectExtractable {

  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_INT64 }

  @usableFromInline
  static func _extracting(from object: xpc_object_t) -> Self? {
    guard let value = Int64.extracting(from: object) else {
      return nil
    }
    return Self(value)
  }

}

// MARK: - UInt Conformance

extension UInt: XPCObjectExtractable {
  
  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_UINT64 }

  @usableFromInline
  static func _extracting(from object: xpc_object_t) -> Self? {
    guard let value = UInt64.extracting(from: object) else {
      return nil
    }
    return Self(value)
  }
  
}

// MARK: - Data Conformance

extension Data: XPCObjectExtractable {
  
  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_DATA }

  @usableFromInline
  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    let length = xpc_data_get_length(object)
    guard length > 0 else {
      return Self()
    }
    var result = Data(repeating: 0, count: length)
    result.withUnsafeMutableBytes { unsafeMutableBufferPtr in
      _ = xpc_data_get_bytes(
        object,
        unsafeMutableBufferPtr.baseAddress!,
        0,
        length
      )
    }
    
    return result
  }
  
}

// MARK: - Bool Conformance

extension Bool: XPCObjectExtractable {
  
  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_BOOL }

  @usableFromInline
  static func _extracting(from object: xpc_object_t) -> Self? {
    assert(object.hasType(associatedXPCObjectType))
    return xpc_bool_get_value(object)
  }
  
}


// MARK: - Synthesized Conformances

extension Int8: XPCObjectExtractable { }
extension Int16: XPCObjectExtractable { }
extension Int32: XPCObjectExtractable { }
extension Int128: XPCObjectExtractable { }

extension UInt8: XPCObjectExtractable { }
extension UInt16: XPCObjectExtractable { }
extension UInt32: XPCObjectExtractable { }
extension UInt128: XPCObjectExtractable { }

extension Float16: XPCObjectExtractable { }
extension Float: XPCObjectExtractable { }
