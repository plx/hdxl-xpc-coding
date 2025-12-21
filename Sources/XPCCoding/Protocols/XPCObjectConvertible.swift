import Foundation
import XPC

@usableFromInline
internal protocol XPCObjectConvertible {
  
  var xpcObjectRepresentation: xpc_object_t { get }
  
}

extension Double: XPCObjectConvertible {

  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_double_create(self)
  }
  
}

extension Int64: XPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_int64_create(self)
  }
  
}

extension UInt64: XPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_uint64_create(self)
  }
  
}

extension Int: XPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_int64_create(Int64(self))
  }

}

extension UInt: XPCObjectConvertible {

  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_uint64_create(UInt64(self))
  }

}

extension Data: XPCObjectConvertible {

  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    withUnsafeBytes { (unsafeRawBufferPointer: UnsafeRawBufferPointer) in
      xpc_data_create(
        unsafeRawBufferPointer.baseAddress,
        unsafeRawBufferPointer.count
      )
    }
  }
  
}

extension String: XPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    withCString { cString in
      xpc_string_create(cString)
    }
  }

}

extension Bool: XPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_bool_create(self)
  }

}

extension XPCObjectConvertible where Self: XPCBinaryDataRepresentationConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    withUnsafeXPCBinaryDataRepresentationRawBufferPointer { unsafeBufferPointer in
      xpc_data_create(
        unsafeBufferPointer.baseAddress,
        unsafeBufferPointer.count
      )
    }
  }
  
}

extension Int8: XPCObjectConvertible { }
extension Int16: XPCObjectConvertible { }
extension Int32: XPCObjectConvertible { }
extension Int128: XPCObjectConvertible { }

extension UInt8: XPCObjectConvertible { }
extension UInt16: XPCObjectConvertible { }
extension UInt32: XPCObjectConvertible { }
extension UInt128: XPCObjectConvertible { }

extension Float16: XPCObjectConvertible { }
extension Float: XPCObjectConvertible { }
