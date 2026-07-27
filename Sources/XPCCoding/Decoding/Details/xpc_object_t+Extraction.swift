// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

// MARK: XPCStringExtractionError

/// Errors that can occur when extracting a string from an `xpc_object_t`.
internal enum XPCStringExtractionError: Error {

  /// The xpc object is not of the expected type.
  case typeMismatch(String)

  /// We were unable to remove percent escapes from the string.
  case unableToRemovePercentEscapes(String)

  /// We were unable to copy the string content from the xpc data object.
  case unableToCopyStringContent(String)

  /// We were unable to decode the string content from the xpc data object.
  case unableToDecode(String)
}

// MARK: - Extraction API

extension xpc_object_t {

  /// Entry point for string-value extraction.
  internal func extractStringValue(
    stringValueStrategy: XPCDecoder.StringValueStrategy,
    at codingPath: [any CodingKey]
  ) throws(DecodingError) -> String {
    do {
      return try _extractStringValue(stringValueStrategy: stringValueStrategy)
    } catch let error {
      switch error {
      case .typeMismatch:
        if isNull {
          throw DecodingError.valueNotFound(
            String.self,
            DecodingError.Context(
              codingPath: codingPath,
              debugDescription: "Expected a String value, but found XPC null."
            )
          )
        }
        throw DecodingError.typeMismatch(
          String.self,
          DecodingError.Context(
            codingPath: codingPath,
            debugDescription:
              """
              Expected the XPC object kind required by the \
              \(String(reflecting: stringValueStrategy)) string-value strategy, but found \
              \(typeDescription).
              """,
            underlyingError: nil
          )
        )
      case .unableToRemovePercentEscapes,
        .unableToCopyStringContent,
        .unableToDecode:
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Unable to extract a valid string value from its XPC representation.",
            underlyingError: error
          )
        )
      }
    }
  }

  /// Underlying logic for string extraction from an `xpc_object_t`.
  internal func _extractStringValue(
    stringValueStrategy: XPCDecoder.StringValueStrategy
  ) throws(XPCStringExtractionError) -> String {
    switch stringValueStrategy {
    case .passthrough, .percentEscape:
      guard hasType(XPC_TYPE_STRING) else {
        throw XPCStringExtractionError.typeMismatch(
          "Expected xpc string object, but got: \(typeDescription)."
        )
      }
      let expectedLength = xpc_string_get_length(self)
      guard expectedLength > 0 else {
        return ""
      }
      let cString = infalliblyUnwrap(
        xpc_string_get_string_ptr(self),
        explanation:
          "`xpc_string_get_string_ptr` returns NULL only for non-string xpc objects, but `self` was just verified to be `XPC_TYPE_STRING`."
      )

      guard
        let string = String(
          validatingUTF8CString: cString,
          byteCount: expectedLength
        )
      else {
        throw .unableToDecode(
          "Unable to decode \(expectedLength) XPC string bytes as UTF-8."
        )
      }
      guard stringValueStrategy == .percentEscape else {
        return string
      }
      guard let withoutEscapes = string.removingXPCCodingPercentEscapes() else {
        throw .unableToRemovePercentEscapes(string)
      }
      return withoutEscapes
    case .useDataRepresentation(let representation):
      guard hasType(XPC_TYPE_DATA) else {
        throw .typeMismatch("Expected xpc data, but got \(typeDescription).")
      }
      let expectedLength = xpc_data_get_length(self)
      guard expectedLength > 0 else {
        return ""
      }
      var data = Data(repeating: 0, count: expectedLength)
      let copiedOK = data.withUnsafeMutableBytes { (unsafeMutableBytesPtr: UnsafeMutableRawBufferPointer) in
        let baseAddress = infalliblyUnwrap(
          unsafeMutableBytesPtr.baseAddress,
          explanation:
            "`UnsafeMutableRawBufferPointer.baseAddress` is nil only for empty buffers, but we already early-returned for `expectedLength == 0`."
        )

        let copiedCount = xpc_data_get_bytes(
          self,
          baseAddress,
          0,
          expectedLength
        )
        return expectedLength == copiedCount
      }
      guard copiedOK else {
        throw .unableToCopyStringContent("Unable to copy \(expectedLength) bytes from xpc data.")
      }

      guard
        let decodedString = String(
          bytes: data,
          encoding: representation.stringEncoding
        )
      else {
        throw .unableToDecode(
          "Unable to decode \(data.count) bytes as \(representation)"
        )
      }

      return decodedString
    }
  }

  /// Extract a value of type `Value` directly from the receiving `xpc_object_t`, reporting errors as having occurred at the given `codingPath`.
  func extractValue<Value>(
    ofType valueType: Value.Type,
    at codingPath: [any CodingKey]
  ) throws -> Value where Value: XPCObjectExtractable {
    let actualXPCObjectType = xpc_get_type(self)
    guard actualXPCObjectType == valueType.associatedXPCObjectType else {
      if actualXPCObjectType == XPC_TYPE_NULL {
        throw DecodingError.valueNotFound(
          valueType,
          DecodingError.Context(
            codingPath: codingPath,
            debugDescription:
              "Expected a nonoptional \(String(reflecting: valueType)) value, but found XPC null."
          )
        )
      }
      throw DecodingError.typeMismatch(
        valueType,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
            """
            Type mismatch: expected \(String(reflecting: valueType)) represented as \
            \(valueType.associatedXPCObjectType.typeDescription), but the XPC object is actually \
            \(actualXPCObjectType.typeDescription).
            """,
          underlyingError: nil
        )
      )
    }

    guard let extractedValue = valueType.extracting(from: self) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
            """
            Data corruption: unable to construct \(String(reflecting: valueType)) from an XPC \
            object of type \(typeDescription).
            """,
          underlyingError: nil
        )
      )
    }

    return extractedValue
  }

  /// Extract a value of type `Value` from an `xpc_object_t` at the given `key`, reporting errors as having occurred at the given `codingPath`.
  func extractValue<Value>(
    ofType valueType: Value.Type,
    at codingPath: [any CodingKey],
    forKey key: any CodingKey,
    stringKeyStrategy: XPCDecoder.StringKeyStrategy
  ) throws -> Value where Value: XPCObjectExtractable {
    guard isDictionary else {
      throw DecodingError.typeMismatch(
        [String: Any].self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
            """
            Type mismatch: expected to extract \(String(reflecting: valueType)) for key `\(key)` \
            from an XPC dictionary, but the object is \(typeDescription).
            """,
          underlyingError: nil
        )
      )
    }

    let possibleXPCValue = key.withUTF8CString(
      embeddedNullByteRepresentation: stringKeyStrategy.embeddedNullByteRepresentation
    ) { cString in
      xpc_dictionary_get_value(self, cString)
    }
    guard let xpcValue = possibleXPCValue else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
            """
            Key not found: couldn't find an expected \(String(reflecting: valueType)) value for \
            key `\(key.stringValue)`.
            """,
          underlyingError: nil
        )
      )
    }

    return try xpcValue.extractValue(
      ofType: valueType,
      at: codingPath
    )
  }

  /// Extract a `String` from an `xpc_object_t` at the given `key`, reporting errors as having occurred at the given `codingPath`.
  func extractString(
    at codingPath: [any CodingKey],
    forKey key: any CodingKey,
    stringKeyStrategy: XPCDecoder.StringKeyStrategy,
    stringValueStrategy: XPCDecoder.StringValueStrategy
  ) throws -> String {
    guard isDictionary else {
      throw DecodingError.typeMismatch(
        [String: Any].self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
            """
            Type mismatch: expected to extract a String for key `\(key)` from an XPC dictionary, \
            but the object is \(typeDescription).
            """,
          underlyingError: nil
        )
      )
    }

    let possibleXPCValue = key.withUTF8CString(
      embeddedNullByteRepresentation: stringKeyStrategy.embeddedNullByteRepresentation
    ) { cString in
      xpc_dictionary_get_value(self, cString)
    }
    guard let xpcValue = possibleXPCValue else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
            """
            Key not found: couldn't find the expected value for key `\(key.stringValue)`.
            """,
          underlyingError: nil
        )
      )
    }

    return try xpcValue.extractStringValue(
      stringValueStrategy: stringValueStrategy,
      at: codingPath
    )
  }

}
