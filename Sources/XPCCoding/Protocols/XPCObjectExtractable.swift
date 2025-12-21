import Foundation
import XPC

@usableFromInline
internal protocol XPCObjectExtractable {
  
  static var associatedXPCObjectType: xpc_type_t { get }
  static func extracting(from object: xpc_object_t) -> Self?
  
}

extension Double: XPCObjectExtractable {

  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_DOUBLE }

  @usableFromInline
  static func extracting(from object: xpc_object_t) -> Self? {
    guard xpc_get_type(object) == associatedXPCObjectType else {
      return nil
    }
    return xpc_double_get_value(object)
  }
  
}

extension Int64: XPCObjectExtractable {

  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_INT64 }

  @usableFromInline
  static func extracting(from object: xpc_object_t) -> Self? {
    guard xpc_get_type(object) == associatedXPCObjectType else {
      return nil
    }
    return xpc_int64_get_value(object)
  }
  
}

extension UInt64: XPCObjectExtractable {
  
  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_UINT64 }

  @usableFromInline
  static func extracting(from object: xpc_object_t) -> Self? {
    guard xpc_get_type(object) == associatedXPCObjectType else {
      return nil
    }
    return xpc_uint64_get_value(object)
  }
  
}

extension Int: XPCObjectExtractable {

  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_INT64 }

  @usableFromInline
  static func extracting(from object: xpc_object_t) -> Self? {
    guard let value = Int64.extracting(from: object) else {
      return nil
    }
    return Self(value)
  }

}

extension UInt: XPCObjectExtractable {
  
  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_UINT64 }

  @usableFromInline
  static func extracting(from object: xpc_object_t) -> Self? {
    guard let value = UInt64.extracting(from: object) else {
      return nil
    }
    return Self(value)
  }
  
}

extension Data: XPCObjectExtractable {
  
  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_DATA }

  @usableFromInline
  static func extracting(from object: xpc_object_t) -> Self? {
    guard xpc_get_type(object) == associatedXPCObjectType else {
      return nil
    }
    let length = xpc_data_get_length(object)
    guard length > 0 else {
      return Self()
    }
    var result = Data(repeating: 0, count: length)
    let copiedOK = result.withUnsafeMutableBytes { unsafeMutableBufferPtr in
      guard let baseAddress = unsafeMutableBufferPtr.baseAddress else {
        return false
      }
      
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

extension String: XPCObjectExtractable {

  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_STRING }

  @usableFromInline
  static func extracting(from object: xpc_object_t) -> Self? {
    guard xpc_get_type(object) == associatedXPCObjectType else {
      return nil
    }
    let length = xpc_string_get_length(object)
    guard length > 0 else {
      return Self()
    }
    guard let unsafeStringPtr = xpc_string_get_string_ptr(object) else {
      return nil
    }
    
    return String(
      cString: unsafeStringPtr,
      encoding: .utf8
    )
  }

}

extension Bool: XPCObjectExtractable {
  
  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_BOOL }

  @usableFromInline
  static func extracting(from object: xpc_object_t) -> Self? {
    guard xpc_get_type(object) == associatedXPCObjectType else {
      return nil
    }
    
    return xpc_bool_get_value(object)
  }
  
}

extension XPCObjectExtractable where Self: XPCBinaryDataRepresentationConvertible {
  
  @usableFromInline
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_DATA }
  
  @usableFromInline
  static func extracting(from object: xpc_object_t) -> Self? {
    guard xpc_get_type(object) == associatedXPCObjectType else {
      return nil
    }
    let length = xpc_data_get_length(object)
    guard MemoryLayout<Self>.size == length else {
      return nil
    }
    
    guard let unsafeBaseAddress = xpc_data_get_bytes_ptr(object) else {
      return nil
    }
    
    return Self(
      unsafeXPCBinaryDataRepresentationRawBufferPointer: UnsafeRawBufferPointer(
        start: unsafeBaseAddress,
        count: length
      )
    )
  }
  
}

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
