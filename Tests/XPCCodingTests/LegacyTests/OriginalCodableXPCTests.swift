// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Testing
import Foundation
@testable import XPCCoding

@Suite(.tags(.original))
private struct `Original CodableXPC Tests` {
  
  // MARK: - Empty Aggregates
  
  /// ``EmptyStruct`` is a `Codable` struct with no fields.
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `EmptyStruct (top level)`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      of: EmptyStruct(),
      configuration: configuration
    )
  }
  
  /// ``EmptyClass`` is a `Codable` class with no fields.
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `EmptyClass (top level)`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      of: EmptyClass(),
      configuration: configuration
    )
  }

  // MARK: - Top-Level Single Values
  
  /// ``Switch`` is a simple enum with two cases and synthesized `Codable` conformance.
  @Test(arguments: XPCCodec.Configuration.allCases, Switch.allCases)
  func `enum (top level)`(
    configuration: XPCCodec.Configuration,
    probe: Switch
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  /// ``Timestamp`` is a simple struct with a single field, encoding itself using a single-value container.
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `struct (top level)`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      of: Timestamp(3141592653),
      configuration: configuration
    )
  }
  
  /// ``Counter`` is a simple class with a single field, encoding itself using a single-value container.
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `class (top level)`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      of: Counter(),
      configuration: configuration
    )
  }
  
  // MARK: - Top-Level Complex Types
  
  /// ``Address`` is a struct type with multiple fields.
  @Test(arguments: XPCCodec.Configuration.allCases, Address.testValues)
  func `Address (top level)`(configuration: XPCCodec.Configuration, probe: Address) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  /// ``Person`` is a class with multiple fields.
  @Test(arguments: XPCCodec.Configuration.allCases, testPersons())
  func `Person (top level)`(configuration: XPCCodec.Configuration, probe: Person) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  /// ``Numbers`` is a struct which encodes as an array through a single value container.
  @Test(arguments: XPCCodec.Configuration.allCases, Numbers.testValues)
  func `Numbers (top level)`(configuration: XPCCodec.Configuration, probe: Numbers) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  /// ``Mapping`` is a class which encodes as a dictionary through a single value container.
  @Test(arguments: XPCCodec.Configuration.allCases, Mapping.testValues)
  func `Mapping (top level)`(configuration: XPCCodec.Configuration, probe: Mapping) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  /// ``Programmer`` is a type which vends a "super encoder/decoder" to its superclass, ``Person``.
  @Test(arguments: XPCCodec.Configuration.allCases, testProgrammers())
  func `Programmer (top level)`(configuration: XPCCodec.Configuration, probe: Programmer) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  /// ``Employee`` is a type which shares its encoder & decoder with its superclass, ``Person``.
  @Test(arguments: XPCCodec.Configuration.allCases, testEmployees())
  func `Employee (top level)`(configuration: XPCCodec.Configuration, probe: Employee) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  /// ``Company`` is a type with fields which are Codable themselves.
  @Test(arguments: XPCCodec.Configuration.allCases, Company.testValues)
  func `Company (top level)`(configuration: XPCCodec.Configuration, probe: Company) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  /// ``EnhancedBool`` is a type that encodes and decodes via an optional representation.
  @Test(arguments: XPCCodec.Configuration.allCases, EnhancedBool.allCases)
  func `EnhancedBool (top level)`(configuration: XPCCodec.Configuration, probe: EnhancedBool) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  // MARK: - Test KeyPath during failure
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `codingPath (dictionary, encoding, root key)`(configuration: XPCCodec.Configuration) throws {
    let toEncode: [String: EncodeFailure] = ["key": EncodeFailure(someValue: 3.14)]
    let codec = XPCCodec(configuration: configuration)
    
    let encodingError = try #require(throws: EncodingError.self) {
      try codec.encode(toEncode)
    }
    
    try verifyCodingPath(
      of: encodingError,
      matches: ["key"]
    )
  }
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `codingPath (dictionary, encoding, nested key)`(configuration: XPCCodec.Configuration) throws {
    let toEncode: [String: [String: EncodeFailureNested]] = ["key": ["sub_key": EncodeFailureNested(nestedValue: EncodeFailure(someValue: 3.14))]]
    let codec = XPCCodec(configuration: configuration)

    let encodingError = try #require(throws: EncodingError.self) {
      try codec.encode(toEncode)
    }

    try verifyCodingPath(
      of: encodingError,
      matches: [
        "key",
        "sub_key",
        "nestedValue"
      ]
    )
  }
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `codingPath (dictionary, decoding, root key)`(configuration: XPCCodec.Configuration) throws {
    let input = createXPCDictionary(
      key: "intValue",
      value: createXPCString("not an integer")
    )
    
    let codec = XPCCodec(configuration: configuration)
    
    let decodingError = try #require(throws: DecodingError.self) {
      try codec.decode(DecodeFailure.self, from: input)
    }
    
    try verifyCodingPath(
      of: decodingError,
      matches: ["intValue"]
    )
  }
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `codingPath (dictionary, decoding, nested key)`(configuration: XPCCodec.Configuration) throws {
    let input = createXPCDictionary(
      key: "nestedValue",
      value: createXPCDictionary(
        key: "intValue",
        value: createXPCString("not an integer")
      )
    )
    
    let codec = XPCCodec(configuration: configuration)
    
    let decodingError = try #require(throws: DecodingError.self) {
      try codec.decode(DecodeFailureNested.self, from: input)
    }
    
    try verifyCodingPath(
      of: decodingError,
      matches: [
        "nestedValue",
        "intValue"
      ]
    )
  }
}

// MARK: - Support Types


private struct EncodeFailure : Encodable {
  enum Failure: Error {
    case Failure
  }
  
  var someValue: Double
  func encode(to encoder: Encoder) throws {
    throw EncodingError.invalidValue(
      self,
      EncodingError.Context(
        codingPath: encoder.codingPath,
        debugDescription: "Intentional encoding failure.",
        underlyingError: Failure.Failure
      )
    )
  }
}

private struct EncodeFailureNested : Encodable {
  var nestedValue: EncodeFailure
}

private struct DecodeFailure : Decodable {
  var intValue: Int
}

private struct DecodeFailureNested : Decodable {
  var nestedValue: DecodeFailure
}
