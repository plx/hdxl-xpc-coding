import Testing
import XPC
@testable import XPCCoding

func verifyXPCConversion<T>(
  of value: T,
  sourceLocation: SourceLocation = #_sourceLocation
) throws where T: Equatable & XPCObjectConvertible & XPCObjectExtractable {
  let xpcObject = try value.makeXPCObjectRepresentation()
  #expect(
    xpc_get_type(xpcObject) == T.associatedXPCObjectType,
    """
    Found mismatch in conversion and extraction types for \(T.self):
    
    - value: \(value)
    - expected-type: \(T.associatedXPCObjectType.typeDescription)
    - observed-type: \(xpcObject.typeDescription)
    """,
    sourceLocation: sourceLocation
  )
  let roundTripped = try #require(
    T.extracting(from: xpcObject),
    """
    Expected successful extraction of \(T.self) value from \(xpcObject) created-from \(value)!
    """,
    sourceLocation: sourceLocation
  )
  #expect(
    value == roundTripped,
    """
    Found mismatch between original and round-tripped values for \(T.self):
    
    - value: \(value)
    - roundTripped: \(roundTripped)
    """
  )
}

func verifyXPCConversion<T>(
  of value: T,
  sourceLocation: SourceLocation = #_sourceLocation,
  equivalence: (T, T) -> Bool
) throws where T: XPCObjectConvertible & XPCObjectExtractable {
  let xpcObject = try value.makeXPCObjectRepresentation()
  #expect(
    xpc_get_type(xpcObject) == T.associatedXPCObjectType,
    """
    Found mismatch in conversion and extraction types for \(T.self):
    
    - value: \(value)
    - expected-type: \(T.associatedXPCObjectType.typeDescription)
    - observed-type: \(xpcObject.typeDescription)
    """,
    sourceLocation: sourceLocation
  )
  let roundTripped = try #require(
    T.extracting(from: xpcObject),
    """
    Expected successful extraction of \(T.self) value from \(xpcObject) created-from \(value)!
    """,
    sourceLocation: sourceLocation
  )
  #expect(
    equivalence(value, roundTripped),
    """
    Found mismatch between original and round-tripped values for \(T.self):
    
    - value: \(value)
    - roundTripped: \(roundTripped)
    """
  )
}

func verifyXPCConversion(
  forStringValueWithoutEmbeddedNullBytes stringValue: String,
  stringValueStrategy: XPCCodec.StringValueStrategy,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try #require(
    !stringValue.containsNullBytes,
    """
    \(#function) is only meant to be called on strings without embedded null bytes!
    """,
    sourceLocation: sourceLocation
  )
  let xpcObject = try stringValue.makeXPCObjectRepresentation(stringValueStrategy: stringValueStrategy.encodingStrategy)
  let roundTripped = try xpcObject._extractStringValue(
    stringValueStrategy: stringValueStrategy.decodingStrategy
  )
  
  #expect(
    stringValue == roundTripped,
    """
    Round-trip failure for strategy \(stringValueStrategy)!
    
    - original:      `\(stringValue)`
    - round-tripped: `\(roundTripped)`
    """,
    sourceLocation: sourceLocation
  )
}

