import Foundation
import XPC

extension String {
  
  /// Represents errors that can occur when converting a string to an `xpc_object_t`.
  @usableFromInline
  internal enum XPCObjectConversionError: Error {
    /// The string contains null bytes (relevant for the `.throwOnDiscovery` strategy).
    case containsNullBytes(String)

    /// The string could not be converted to the specified data representation.
    case unableToConvertToData(String, XPCCodec.StringValueDataRepresentation)
  }
  
  /// Converts the string to an `xpc_object_t` representation, as per `stringKeyStrategy`.
  @inlinable
  internal func makeXPCObjectRepresentation(
    stringKeyStrategy: XPCEncoder.StringKeyStrategy
  ) -> xpc_object_t {
    withUTF8CString(stringKeyStrategy: stringKeyStrategy) { cStringPtr in
      xpc_string_create(cStringPtr)
    }
  }

  /// Converts the string to an `xpc_object_t` representation, as per `stringValueStrategy`.
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
