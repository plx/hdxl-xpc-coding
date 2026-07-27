// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation

// MARK: XPCBinaryDataRepresentationConvertible

/// Protocol for types that can be converted to a binary-data representation.
///
/// This is used only for the 128-bit integer types for which XPC has no scalar representation.
/// Their bytes are the target-native bitwise representation shared by co-built local peers.
protocol XPCBinaryDataRepresentationConvertible: BitwiseCopyable {
  
  /// Provides access to a raw buffer pointer our binary data representation.
  ///
  /// - Note: this is the primary API method to avoid *needing* to create a `Data` just to encode a value like an `Int8`.
  func withUnsafeXPCBinaryDataRepresentationRawBufferPointer<R>(_ closure: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
  
  /// Constructs a value from a raw buffer pointer pointing-to our binary-data representation.
  ///
  /// - Note: the buffer's base address is *not* required to satisfy `Self`'s alignment.
  init?(unsafeXPCBinaryDataRepresentationRawBufferPointer unsafeRawBufferPointer: UnsafeRawBufferPointer)
}

// MARK: - Defaults

extension XPCBinaryDataRepresentationConvertible where Self: Numeric {
  
  internal func withUnsafeXPCBinaryDataRepresentationRawBufferPointer<R>(_ closure: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    try withUnsafePointer(to: self) { pointerToSelf in
      try closure(
        UnsafeRawBufferPointer(
          start: UnsafeRawPointer(pointerToSelf),
          count: MemoryLayout<Self>.size
        )
      )
    }
  }
  
  /// Constructs a value from a raw buffer pointer pointing-to our binary-data representation.
  ///
  /// - Note: the size check *must* stay ahead of the load; we never read from a buffer of the wrong size.
  /// - Note: we use `loadUnaligned(as:)` b/c XPC doesn't promise that e.g. `xpc_data_get_bytes_ptr` satisfies `Self`'s alignment.
  internal init?(unsafeXPCBinaryDataRepresentationRawBufferPointer unsafeRawBufferPointer: UnsafeRawBufferPointer) {
    guard
      let baseAddress = unsafeRawBufferPointer.baseAddress,
      unsafeRawBufferPointer.count == MemoryLayout<Self>.size
    else {
      return nil
    }
    self = baseAddress.loadUnaligned(as: Self.self)
  }

  internal init?(xpcBinaryDataRepresentation: Data) {
    self = .zero
    guard xpcBinaryDataRepresentation.count == MemoryLayout<Self>.size else {
      return nil
    }
    
    self = xpcBinaryDataRepresentation.withUnsafeBytes { (pointerToData: UnsafeRawBufferPointer) in
      infalliblyUnwrap(
        Self(unsafeXPCBinaryDataRepresentationRawBufferPointer: pointerToData),
        explanation: "The size of `xpcBinaryDataRepresentation` was just verified to equal `MemoryLayout<Self>.size`, which is the only condition under which the unsafe initializer can fail for a `Numeric` type."
      )
    }
  }
  
}

// MARK: - Conveniences

extension XPCBinaryDataRepresentationConvertible {

  /// Convenience to provide a `Data` holding our binary-data representation.
  internal var xpcBinaryDataRepresentation: Data {
    withUnsafePointer(to: self) { pointerToSelf in
      Data(
        bytes: pointerToSelf,
        count: MemoryLayout<Self>.size
      )
    }
  }
  

}

// MARK: - Synthesized Conformances

extension Int128: XPCBinaryDataRepresentationConvertible { }

extension UInt128: XPCBinaryDataRepresentationConvertible { }
