import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: String Keys

/// Tests exercising string-key functionality.
@Suite(.tags(.edgeCases, .strings))
struct `String-Key Tests` {
  

  // MARK: 5.1 Keys with Special Characters

  @Test(
    .tags(.roundTrip, .keyed),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Keys with ' '`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      of: KeyWithSpaceStruct(value: 42),
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .keyed),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Keys with .`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      of: KeyWithDotsStruct(value: 42),
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .keyed),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Keys with /`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      of: KeyWithSlashesStruct(value: 42),
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .keyed),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Keys with :`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      of: KeyWithColonStruct(value: 42),
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .keyed),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Keys with Unicode`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      of: KeyWithUnicodeStruct(value: 42),
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .keyed),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Empty key`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      of: EmptyKeyStruct(value: 42),
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .keyed),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Numeric key`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      of: NumericKeyStruct(value: 42),
      configuration: configuration
    )
  }

  // MARK: Embedded Null-Byte Cases
  
  /// Verify we encode/decode "ok" for keys with embedded nulls, but get unexpected values as a result.
  @Test(
    .tags(.roundTrip, .keyed),
    arguments: XPCCodec.StringValueStrategy.allCases
  )
  func `assume absent (fails)`(stringValueStrategy: XPCCodec.StringValueStrategy) throws {
    let configuration = XPCCodec.Configuration(
      stringKeyStrategy: .assumeAbsent,
      stringValueStrategy: stringValueStrategy
    )
    let value = KeysWithEmbeddedNullStruct.exampleValue
    
    withKnownIssue("`assume absent` will encode/decode, but won't round trip for keys with null bytes") {
      try verifyRoundTrip(
        ofValueAndWrappers: value,
        configuration: configuration
      )
    }
  }

  /// Verify in `.throwsOnDiscovery` mode we throw an error when trying to encode.
  @Test(
    .tags(.roundTrip, .keyed),
    arguments: XPCCodec.StringValueStrategy.allCases
  )
  func `throw on discovery (throws)`(stringValueStrategy: XPCCodec.StringValueStrategy) throws {
    let configuration = XPCCodec.Configuration(
      stringKeyStrategy: .throwOnDiscovery,
      stringValueStrategy: stringValueStrategy
    )
    let value = KeysWithEmbeddedNullStruct.exampleValue
    
    #expect(throws: (any Error).self) {
      try verifyRoundTrip(
        ofValueAndWrappers: value,
        configuration: configuration
      )
    }
  }

  /// Verify in `.percentEscape` mode we successfully round-trip.
  @Test(
    .tags(.roundTrip, .keyed),
    arguments: XPCCodec.StringValueStrategy.allCases
  )
  func `percent escape (ok)`(stringValueStrategy: XPCCodec.StringValueStrategy) throws {
    let configuration = XPCCodec.Configuration(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: stringValueStrategy
    )
    let value = KeysWithEmbeddedNullStruct.exampleValue
    
    try verifyRoundTrip(
      ofValueAndWrappers: value,
      configuration: configuration
    )
  }

}
