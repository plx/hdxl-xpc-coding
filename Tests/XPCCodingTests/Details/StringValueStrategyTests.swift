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

  @Test(
    arguments: String.embeddedNullByteExamples
  )
  func `assumeAbsent <-> xpc (nulls)`(probe: String) throws {
    withKnownIssue("Assume absent will 'succeed' but with truncated values!") {
      try verifyStringRoundTrip(
        probe,
        stringValueStrategy: .assumeAbsent
      )
    }
  }

  @Test(
    arguments: String.embeddedNullByteExamples
  )
  func `throwOnDiscovery <-> xpc throws (nulls)`(probe: String) throws {
    #expect(throws: (any Error).self) {
      try verifyStringRoundTrip(
        probe,
        stringValueStrategy: .throwOnDiscovery
      )
    }
  }

  @Test(
    arguments: String.embeddedNullByteExamples
  )
  func `percentEscape <-> xpc (nulls)`(probe: String) throws {
    try verifyStringRoundTrip(
      probe,
      stringValueStrategy: .percentEscape
    )
  }

  @Test(
    arguments: String.embeddedNullByteExamples
  )
  func `utf8 <-> xpc (nulls)`(probe: String) throws {
    try verifyStringRoundTrip(
      probe,
      stringValueStrategy: .useDataRepresentation(.utf8)
    )
  }

  @Test(
    arguments: String.embeddedNullByteExamples
  )
  func `utf16 <-> xpc (nulls)`(probe: String) throws {
    try verifyStringRoundTrip(
      probe,
      stringValueStrategy: .useDataRepresentation(.utf16)
    )
  }

  @Test(
    arguments: String.embeddedNullByteExamples
  )
  func `utf32 <-> xpc (nulls)`(probe: String) throws {
    try verifyStringRoundTrip(
      probe,
      stringValueStrategy: .useDataRepresentation(.utf32)
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
