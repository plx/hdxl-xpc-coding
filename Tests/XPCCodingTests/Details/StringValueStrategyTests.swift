import Foundation
import XPC
import Testing
@testable import XPCCoding

@Suite("StringKeyStrategy Tests")
private struct StringKeyStrategyTests {

  // MARK: - No Embedded Null Bytes

  @Test(
    arguments: String.nullFreeExampleValues
  )
  func `assumeAbsent <-> xpc (nonnull)`(probe: String) throws {
    try verifyStringRoundTrip(
      probe,
      stringValueStrategy: .assumeAbsent
    )
  }

  @Test(
    arguments: String.nullFreeExampleValues
  )
  func `throwOnDiscovery <-> xpc (nonnull)`(probe: String) throws {
    try verifyStringRoundTrip(
      probe,
      stringValueStrategy: .throwOnDiscovery
    )
  }

  @Test(
    arguments: String.nullFreeExampleValues
  )
  func `percentEscape <-> xpc (nonnull)`(probe: String) throws {
    try verifyStringRoundTrip(
      probe,
      stringValueStrategy: .percentEscape
    )
  }

  @Test(
    arguments: String.nullFreeExampleValues
  )
  func `utf8 <-> xpc (nonnull)`(probe: String) throws {
    try verifyStringRoundTrip(
      probe,
      stringValueStrategy: .useDataRepresentation(.utf8)
    )
  }

  @Test(
    arguments: String.nullFreeExampleValues
  )
  func `utf16 <-> xpc (nonnull)`(probe: String) throws {
    try verifyStringRoundTrip(
      probe,
      stringValueStrategy: .useDataRepresentation(.utf16)
    )
  }

  @Test(
    arguments: String.nullFreeExampleValues
  )
  func `utf32 <-> xpc (nonnull)`(probe: String) throws {
    try verifyStringRoundTrip(
      probe,
      stringValueStrategy: .useDataRepresentation(.utf32)
    )
  }

  // MARK: - Embedded Null Bytes

  /// Verifies `.assumeAbsent` truncates at the first null byte.
  ///
  /// It hands the string to `xpc_string_create` as a C string, so the
  /// representation ends there. That truncation is the documented,
  /// intentionally lossy behavior, so assert it exactly.
  @Test(
    arguments: EmbeddedNullStringProbe.allCases
  )
  func `assumeAbsent <-> xpc truncates (nulls)`(probe: EmbeddedNullStringProbe) throws {
    probe.verifyFixtureIntegrity()

    let transcodedUTF8 = try probe.transcodedUTF8(stringValueStrategy: .assumeAbsent)

    #expect(transcodedUTF8 == probe.expectedTruncatedUTF8)
    #expect(transcodedUTF8 != probe.valueUTF8)
  }

  @Test(
    arguments: EmbeddedNullStringProbe.allCases
  )
  func `throwOnDiscovery <-> xpc throws (nulls)`(probe: EmbeddedNullStringProbe) throws {
    probe.verifyFixtureIntegrity()
    probe.verifyThrowOnDiscoveryConversionFailure()
  }

  @Test(
    arguments: EmbeddedNullStringProbe.allCases
  )
  func `percentEscape <-> xpc (nulls)`(probe: EmbeddedNullStringProbe) throws {
    #expect(try probe.transcodedUTF8(stringValueStrategy: .percentEscape) == probe.valueUTF8)
  }

  @Test(
    arguments: EmbeddedNullStringProbe.allCases
  )
  func `utf8 <-> xpc (nulls)`(probe: EmbeddedNullStringProbe) throws {
    #expect(
      try probe.transcodedUTF8(stringValueStrategy: .useDataRepresentation(.utf8))
        == probe.valueUTF8
    )
  }

  @Test(
    arguments: EmbeddedNullStringProbe.allCases
  )
  func `utf16 <-> xpc (nulls)`(probe: EmbeddedNullStringProbe) throws {
    #expect(
      try probe.transcodedUTF8(stringValueStrategy: .useDataRepresentation(.utf16))
        == probe.valueUTF8
    )
  }

  @Test(
    arguments: EmbeddedNullStringProbe.allCases
  )
  func `utf32 <-> xpc (nulls)`(probe: EmbeddedNullStringProbe) throws {
    #expect(
      try probe.transcodedUTF8(stringValueStrategy: .useDataRepresentation(.utf32))
        == probe.valueUTF8
    )
  }

}

func verifyStringRoundTrip(
  _ probe: String,
  stringValueStrategy: XPCCodec.StringValueStrategy,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let xpc = try probe.makeXPCObjectRepresentation(stringValueStrategy: stringValueStrategy.encodingStrategy)
  let extractedString = try xpc._extractStringValue(stringValueStrategy: stringValueStrategy.decodingStrategy)
  #expect(
    probe == extractedString,
    "Failed for strategy: \(stringValueStrategy): `\(probe)` => `\(extractedString) (instead-of round-tripping)",
    sourceLocation: sourceLocation
  )

}
