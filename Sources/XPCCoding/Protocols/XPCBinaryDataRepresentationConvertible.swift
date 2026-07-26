import Foundation

// MARK: XPCBinaryDataRepresentationConvertible

/// Protocol for types that can be converted to a binary-data representation.
///
/// - Note: this exists to encode/decode types like `Int16` (etc.) as binary data, rather than as an Int64.
/// - TBD: if we should actually use this as widely (vs, say, just embedding them in the larger ints, where applicable).
/// - TODO: setup a dedicated error type, since there's really just one type of error we expect to see (length mismatches)
@usableFromInline
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
  
  @inlinable
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
  @inlinable
  internal init?(unsafeXPCBinaryDataRepresentationRawBufferPointer unsafeRawBufferPointer: UnsafeRawBufferPointer) {
    guard
      let baseAddress = unsafeRawBufferPointer.baseAddress,
      unsafeRawBufferPointer.count == MemoryLayout<Self>.size
    else {
      return nil
    }
    self = baseAddress.loadUnaligned(as: Self.self)
  }

  @inlinable
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
  @inlinable
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

extension Int8: XPCBinaryDataRepresentationConvertible { }
extension Int16: XPCBinaryDataRepresentationConvertible { }
extension Int32: XPCBinaryDataRepresentationConvertible { }
extension Int128: XPCBinaryDataRepresentationConvertible { }

extension UInt8: XPCBinaryDataRepresentationConvertible { }
extension UInt16: XPCBinaryDataRepresentationConvertible { }
extension UInt32: XPCBinaryDataRepresentationConvertible { }
extension UInt128: XPCBinaryDataRepresentationConvertible { }

extension Float16: XPCBinaryDataRepresentationConvertible { }
extension Float: XPCBinaryDataRepresentationConvertible { }
