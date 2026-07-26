// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

/// Protocol for values that can *infallibly* be converted to `xpc_object_t` representations.
///
@usableFromInline
internal protocol LosslessXPCObjectConvertible {
  
  /// Provides an `xpc_object_t` that's an exact representation of `self`.
  var xpcObjectRepresentation: xpc_object_t { get }
  
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

extension Double: LosslessXPCObjectConvertible {

  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_double_create(self)
  }
  
}

extension Int64: LosslessXPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_int64_create(self)
  }
  
}

extension UInt64: LosslessXPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_uint64_create(self)
  }
  
}

extension Int: LosslessXPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_int64_create(Int64(self))
  }

}

extension UInt: LosslessXPCObjectConvertible {

  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_uint64_create(UInt64(self))
  }

}

extension Data: LosslessXPCObjectConvertible {

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

extension Bool: LosslessXPCObjectConvertible {
  
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_bool_create(self)
  }

}

// MARK: - Synthesized Conformances

extension Int8: LosslessXPCObjectConvertible { }
extension Int16: LosslessXPCObjectConvertible { }
extension Int32: LosslessXPCObjectConvertible { }
extension Int128: LosslessXPCObjectConvertible { }

extension UInt8: LosslessXPCObjectConvertible { }
extension UInt16: LosslessXPCObjectConvertible { }
extension UInt32: LosslessXPCObjectConvertible { }
extension UInt128: LosslessXPCObjectConvertible { }

extension Float16: LosslessXPCObjectConvertible { }
extension Float: LosslessXPCObjectConvertible { }
