import Foundation
import XPC

// MARK: XPCStringExtractionError

/// Errors that can occur when extracting a string from an `xpc_object_t`.
@usableFromInline
internal enum XPCStringExtractionError: Error {

  /// The xpc object is not of the expected type.
  case typeMismatch(String)

  /// We were unable to remove percent escapes from the string.
  case unableToRemovePercentEscapes(String)

  /// We were unable to decode the string content from the xpc data object.
  case unableToDecode(String)
}

// MARK: - Extraction API

extension xpc_object_t {

  /// Generic entrypoint for attempting to extract a value from an `xpc_object_t`.
  /// 
  /// - Parameters:
  ///   - type: The type of value to attempt to extract.
  ///   - stringValueStrategy: The strategy to use when extracting a string value.
  /// - Returns: The extracted value, if successful.
  /// - Note: This method does not throw.
  /// - Note: this method detects when `T` is `String` and uses the `stringValueStrategy` to extract the string.
  /// 
  @usableFromInline
  internal func attemptDirectExtraction<T: Decodable>(
    _ type: T.Type,
    stringValueStrategy: XPCDecoder.StringValueStrategy
  ) -> T? {
    if type is String.Type {
      return try? _extractStringValue(stringValueStrategy: stringValueStrategy) as? T
    }
    guard
      let extractableType = type as? XPCObjectExtractable.Type,
      hasType(extractableType.associatedXPCObjectType),
      let _extractedValue = extractableType.extracting(from: self),
      let extractedValue = _extractedValue as? T
    else {
      return nil
    }
    return extractedValue
  }

  /// Entry point for string-value extraction. 
  @usableFromInline
  internal func extractStringValue(
    stringValueStrategy: XPCDecoder.StringValueStrategy,
    at codingPath: [any CodingKey]
  ) throws(DecodingError) -> String {
    do {
      return try _extractStringValue(stringValueStrategy: stringValueStrategy)
    }
    catch let error {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Couldn't extract a string value!",
          underlyingError: error
        )
      )
    }
  }
  
  /// Underlying logic for string extraction from an `xpc_object_t`.
  @usableFromInline
  internal func _extractStringValue(
    stringValueStrategy: XPCDecoder.StringValueStrategy
  ) throws(XPCStringExtractionError) -> String {
    switch stringValueStrategy {
    case .passthrough: fallthrough
    case .percentEscape:
      guard hasType(XPC_TYPE_STRING) else {
        throw XPCStringExtractionError.typeMismatch(
          "Expected xpc string object, but got: \(typeDescription)."
        )
      }
      let expectedLength = xpc_string_get_length(self)
      guard expectedLength > 0 else {
        return ""
      }
      let cString = xpc_string_get_string_ptr(self)!
      
      let string = String(cString: cString)
      guard stringValueStrategy == .percentEscape else {
        return string
      }
      guard let withoutEscapes = string.removingPercentEncoding else {
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
      data.withUnsafeMutableBytes { (unsafeMutableBytesPtr: UnsafeMutableRawBufferPointer) in
        let copiedCount = xpc_data_get_bytes(
          self,
          unsafeMutableBytesPtr.baseAddress!,
          0,
          expectedLength
        )
        precondition(copiedCount == expectedLength)
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
  @usableFromInline
  func extractValue<Value>(
    ofType valueType: Value.Type,
    at codingPath: [any CodingKey]
  ) throws -> Value where Value: XPCObjectExtractable {
    guard hasType(valueType.associatedXPCObjectType) else {
      throw DecodingError.typeMismatch(
        valueType,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
          """
          Type mismatch: expected \(String(reflecting: valueType)) represented-as \(valueType.associatedXPCObjectType.typeDescription), but xpc object is actually \(typeDescription).",
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
          Data corruption: unable to construct a value of type \(String(reflecting: valueType)) from an xpc object of type \(typeDescription).",
          """,
          underlyingError: nil
        )
      )
    }
    
    return extractedValue
  }

  /// Extract a value of type `Value` from an `xpc_object_t` at the given `key`, reporting errors as having occurred at the given `codingPath`.
  @usableFromInline
  func extractValue<Value>(
    ofType valueType: Value.Type,
    at codingPath: [any CodingKey],
    forKey key: any CodingKey,
    stringKeyStrategy: XPCDecoder.StringKeyStrategy    
  ) throws -> Value where Value: XPCObjectExtractable {
    guard isDictionary else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
          """
          Data corruption: expected to be extracting a value of type \(String(reflecting: valueType)) for key `\(key)` from a dictionary, but our xpc object is actually \(typeDescription).",
          """,
          underlyingError: nil
        )
      )
    }
    
    let possible_xpc_value = key.withUTF8CString(embeddedNullByteRepresentation: stringKeyStrategy.embeddedNullByteRepresentation) { cString in
      xpc_dictionary_get_value(self, cString)
    }
    guard let xpc_value = possible_xpc_value else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
          """
          Key not found: couldn't find expected value of type \(String(reflecting: valueType)) for key: `\(key.stringValue)`.",
          """,
          underlyingError: nil
        )
      )
    }
    
    return try xpc_value.extractValue(
      ofType: valueType,
      at: codingPath
    )
  }

  /// Extract a `String` from an `xpc_object_t` at the given `key`, reporting errors as having occurred at the given `codingPath`.
  @usableFromInline
  func extractString(
    at codingPath: [any CodingKey],
    forKey key: any CodingKey,
    stringKeyStrategy: XPCDecoder.StringKeyStrategy,
    stringValueStrategy: XPCDecoder.StringValueStrategy
  ) throws -> String {
    guard isDictionary else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
          """
          Data corruption: expected to be extracting a `String` for key `\(key)` from a dictionary, but our xpc object is actually \(typeDescription).",
          """,
          underlyingError: nil
        )
      )
    }
    
    let possible_xpc_value = key.withUTF8CString(embeddedNullByteRepresentation: stringKeyStrategy.embeddedNullByteRepresentation) { cString in
      xpc_dictionary_get_value(self, cString)
    }
    guard let xpcValue = possible_xpc_value else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
          """
          Key not found: couldn't find expected value for key: `\(key.stringValue)`.",
          """,
          underlyingError: nil
        )
      )
    }
    
    do {
      return try xpcValue._extractStringValue(stringValueStrategy: stringValueStrategy)
    }
    catch let error {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription:
          """
          Data corrupted: unable to decode string value for key: `\(key.stringValue)`.",
          """,
          underlyingError: error
        )
      )
    }
  }

}
