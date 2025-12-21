import Foundation

@usableFromInline
protocol XPCBinaryDataRepresentationConvertible: BitwiseCopyable {
  
  func withUnsafeXPCBinaryDataRepresentationRawBufferPointer<R>(_ closure: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
  init?(unsafeXPCBinaryDataRepresentationRawBufferPointer unsafeRawBufferPointer: UnsafeRawBufferPointer)
}

extension XPCBinaryDataRepresentationConvertible where Self: Numeric {
  
  @inlinable
  func withUnsafeXPCBinaryDataRepresentationRawBufferPointer<R>(_ closure: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    try withUnsafePointer(to: self) { pointerToSelf in
      try closure(
        UnsafeRawBufferPointer(
          start: UnsafeRawPointer(pointerToSelf),
          count: MemoryLayout<Self>.size
        )
      )
    }
  }
  
  @inlinable
  internal var xpcBinaryDataRepresentation: Data {
    withUnsafePointer(to: self) { pointerToSelf in
      Data(
        bytes: pointerToSelf,
        count: MemoryLayout<Self>.size
      )
    }
  }

  @inlinable
  internal init?(unsafeXPCBinaryDataRepresentationRawBufferPointer unsafeRawBufferPointer: UnsafeRawBufferPointer) {
    guard
      let baseAddress = unsafeRawBufferPointer.baseAddress,
      unsafeRawBufferPointer.count == MemoryLayout<Self>.size
    else {
      return nil
    }
    self = baseAddress.load(as: Self.self)
  }

  @inlinable
  internal init?(xpcBinaryDataRepresentation: Data) {
    self = .zero
    guard xpcBinaryDataRepresentation.count == MemoryLayout<Self>.size else {
      return nil
    }
    
    let dereferenced = xpcBinaryDataRepresentation.withUnsafeBytes { (pointerToData: UnsafeRawBufferPointer) in
      Self(unsafeXPCBinaryDataRepresentationRawBufferPointer: pointerToData)
    }
    
    guard let dereferenced else {
      return nil
    }
    
    self = dereferenced
  }
  
}

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
