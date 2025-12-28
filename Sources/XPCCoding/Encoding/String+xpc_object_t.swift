import Foundation
import XPC

extension String {
  
  @usableFromInline
  internal enum XPCObjectConversionError: Error {
    case containsNullBytes(String)
    case unableToConvertToData(String, XPCCodec.StringValueDataRepresentation)
  }
  
  @inlinable
  internal func makeXPCObjectRepresentation(
    stringKeyStrategy: XPCEncoder.StringKeyStrategy
  ) -> xpc_object_t {
    switch stringKeyStrategy {
    case .assumeAbsent:
      return withCString { cStringPtr in
        xpc_string_create(cStringPtr)
      }
    case .percentEscape:
      return withStringWithEmbeddedNullBytesPercentEncoded { cStringPtr in
        xpc_string_create(cStringPtr)
      }
    }
  }

  @inlinable
  internal func makeXPCObjectRepresentation(
    stringValueStrategy: XPCEncoder.StringValueStrategy
  ) throws(XPCObjectConversionError) -> xpc_object_t {
    switch stringValueStrategy {
    case .throwOnDiscovery:
      guard !containsNullBytes else {
        throw XPCObjectConversionError.containsNullBytes(self)
      }
      fallthrough
    case .assumeAbsent:
      return withCString { cStringPtr in
        xpc_string_create(cStringPtr)
      }
    case .percentEscape:
      return withStringWithEmbeddedNullBytesPercentEncoded { cStringPtr in
        xpc_string_create(cStringPtr)
      }
    case .useDataRepresentation(let representation):
      guard
        let dataRepresentation = data(
          using: representation.stringEncoding,
          allowLossyConversion: false
        )
      else {
        throw .unableToConvertToData(
          self,
          representation
        )
      }
      return dataRepresentation.withUnsafeBytes { (unsafeRawBufferPointer: UnsafeRawBufferPointer) in
        xpc_data_create(
          unsafeRawBufferPointer.baseAddress,
          unsafeRawBufferPointer.count
        )
      }
    }
  }

}
