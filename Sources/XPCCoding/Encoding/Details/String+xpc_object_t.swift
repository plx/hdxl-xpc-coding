// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

extension String {

  /// Represents errors that can occur when converting a string to an `xpc_object_t`.
  internal enum XPCObjectConversionError: Error {
    /// The string contains null bytes (relevant for the `.throwOnDiscovery` strategy).
    case containsNullBytes(String)
  }

  /// Converts the string to an `xpc_object_t` representation, as per `stringKeyStrategy`.
  internal func makeXPCObjectRepresentation(
    stringKeyStrategy: XPCEncoder.StringKeyStrategy
  ) -> xpc_object_t {
    withUTF8CString(stringKeyStrategy: stringKeyStrategy) { cStringPtr in
      xpc_string_create(cStringPtr)
    }
  }

  /// Converts the string to an `xpc_object_t` representation, as per `stringValueStrategy`.
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
      return withXPCCodingPercentEscapedCString { cStringPtr in
        xpc_string_create(cStringPtr)
      }
    case .useDataRepresentation(let representation):
      let dataRepresentation = infalliblyUnwrap(
        data(
          using: representation.stringEncoding,
          allowLossyConversion: false
        ),
        explanation:
          "Every `XPCCodec.StringValueDataRepresentation` case (`.utf8`, `.utf16`, `.utf32`) is a lossless Unicode encoding, so `String.data(using:allowLossyConversion: false)` is total over all valid `String` values."
      )
      return dataRepresentation.withUnsafeBytes { (unsafeRawBufferPointer: UnsafeRawBufferPointer) in
        xpc_data_create(
          unsafeRawBufferPointer.baseAddress,
          unsafeRawBufferPointer.count
        )
      }
    }
  }

  /// Converts this string into its XPC representation and normalizes any
  /// codec-originated conversion failure at the exact value path.
  internal func makeXPCObjectRepresentation(
    stringValueStrategy: XPCEncoder.StringValueStrategy,
    codingPath: [any CodingKey]
  ) throws -> xpc_object_t {
    do {
      return try makeXPCObjectRepresentation(
        stringValueStrategy: stringValueStrategy
      )
    } catch let underlyingError {
      throw EncodingError.invalidValue(
        self,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: """
            Unable to represent a string containing an embedded null byte with \
            the .throwOnDiscovery string-value strategy.
            """,
          underlyingError: underlyingError
        )
      )
    }
  }

}
