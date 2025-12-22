import Foundation
import XPC

/// Protocol for values that can *infallibly* be converted to `xpc_object_t` representations.
///
/// - SeeAlso: ``XPCObjectConvertible``, for the rare, fallible equivalent.
@usableFromInline
internal protocol LosslessXPCObjectConvertible: XPCObjectConvertible {
  
  /// Provides an `xpc_object_t` that's an exact representation of `self`.
  var xpcObjectRepresentation: xpc_object_t { get }
  
}

// MARK: - XPCObjectConvertible Interop

extension XPCObjectConvertible where Self: LosslessXPCObjectConvertible {
  
  @inlinable
  internal func makeXPCObjectRepresentation() throws(XPCObjectCompatibilityError) -> xpc_object_t {
    xpcObjectRepresentation
  }
  
}

// MARK: - XPCBinaryDataRepresentationConvertible Interop

extension LosslessXPCObjectConvertible where Self: XPCBinaryDataRepresentationConvertible {
  
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

// MARK: - Specialized Conformances

extension Double: XPCObjectConvertible, LosslessXPCObjectConvertible {

  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_double_create(self)
  }
  
}

extension Int64: XPCObjectConvertible, LosslessXPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_int64_create(self)
  }
  
}

extension UInt64: XPCObjectConvertible, LosslessXPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_uint64_create(self)
  }
  
}

extension Int: XPCObjectConvertible, LosslessXPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_int64_create(Int64(self))
  }

}

extension UInt: XPCObjectConvertible, LosslessXPCObjectConvertible {

  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_uint64_create(UInt64(self))
  }

}

extension Data: XPCObjectConvertible, LosslessXPCObjectConvertible {

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

extension Bool: XPCObjectConvertible, LosslessXPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_bool_create(self)
  }

}

// MARK: - Synthesized Conformances

extension Int8: XPCObjectConvertible, LosslessXPCObjectConvertible { }
extension Int16: XPCObjectConvertible, LosslessXPCObjectConvertible { }
extension Int32: XPCObjectConvertible, LosslessXPCObjectConvertible { }
extension Int128: XPCObjectConvertible, LosslessXPCObjectConvertible { }

extension UInt8: XPCObjectConvertible, LosslessXPCObjectConvertible { }
extension UInt16: XPCObjectConvertible, LosslessXPCObjectConvertible { }
extension UInt32: XPCObjectConvertible, LosslessXPCObjectConvertible { }
extension UInt128: XPCObjectConvertible, LosslessXPCObjectConvertible { }

extension Float16: XPCObjectConvertible, LosslessXPCObjectConvertible { }
extension Float: XPCObjectConvertible, LosslessXPCObjectConvertible { }
