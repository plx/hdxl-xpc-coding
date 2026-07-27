// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

/// Protocol for values that can *infallibly* be converted to `xpc_object_t` representations.
///
/// Inlining audit rationale: this protocol and its `@usableFromInline`
/// witnesses are the compiler-required ABI closure for the measured `Int` and
/// `Data` conversion leaves. Other witness bodies are not inlinable.
@usableFromInline
internal protocol LosslessXPCObjectConvertible {
  
  /// Provides an `xpc_object_t` that's an exact representation of `self`.
  var xpcObjectRepresentation: xpc_object_t { get }
  
}

// MARK: - XPCBinaryDataRepresentationConvertible Interop

extension LosslessXPCObjectConvertible where Self: XPCBinaryDataRepresentationConvertible {
  
  @usableFromInline
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

  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_double_create(self)
  }
  
}

extension Float: LosslessXPCObjectConvertible {

  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_double_create(Double(self))
  }

}

extension Float16: LosslessXPCObjectConvertible {

  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_double_create(Double(self))
  }

}

extension Int64: LosslessXPCObjectConvertible {
  
  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_int64_create(self)
  }
  
}

extension Int32: LosslessXPCObjectConvertible {

  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_int64_create(Int64(self))
  }

}

extension Int16: LosslessXPCObjectConvertible {

  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_int64_create(Int64(self))
  }

}

extension Int8: LosslessXPCObjectConvertible {

  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_int64_create(Int64(self))
  }

}

extension UInt64: LosslessXPCObjectConvertible {
  
  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_uint64_create(self)
  }
  
}

extension UInt32: LosslessXPCObjectConvertible {

  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_uint64_create(UInt64(self))
  }

}

extension UInt16: LosslessXPCObjectConvertible {

  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_uint64_create(UInt64(self))
  }

}

extension UInt8: LosslessXPCObjectConvertible {

  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_uint64_create(UInt64(self))
  }

}

extension Int: LosslessXPCObjectConvertible {
  
  /// Measured hot conversion for keyed integer encoding.
  @inlinable
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_int64_create(Int64(self))
  }

}

extension UInt: LosslessXPCObjectConvertible {

  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_uint64_create(UInt64(self))
  }

}

extension Data: LosslessXPCObjectConvertible {

  /// Measured direct-buffer conversion for the public-client data benchmarks.
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
  
  @usableFromInline
  internal var xpcObjectRepresentation: xpc_object_t {
    xpc_bool_create(self)
  }

}

// MARK: - Synthesized Conformances

extension Int128: LosslessXPCObjectConvertible { }

extension UInt128: LosslessXPCObjectConvertible { }
