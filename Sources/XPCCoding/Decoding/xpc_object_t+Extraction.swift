import Foundation
import XPC

// MARK: - Extraction Support

@usableFromInline
internal enum XPCStringExtractionError: Error {
  case typeMismatch(String)
  case unexpectedNilCString
  case unableToRemovePercentEscapes(String)
  case unableToCopyStringContent(String)
  case unableToDecode(String)
}


extension xpc_object_t {
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
      guard let cString = xpc_string_get_string_ptr(self) else {
        throw .unexpectedNilCString
      }
      
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
      let copiedOK = data.withUnsafeMutableBytes { (unsafeMutableBytesPtr: UnsafeMutableRawBufferPointer) in
        guard let baseAddress = unsafeMutableBytesPtr.baseAddress else {
          return false
        }
        
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
