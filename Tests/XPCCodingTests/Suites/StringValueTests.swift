import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: String Serialization

/// Tests exercising string-serialization.
@Suite(.tags(.edgeCases, .strings))
struct `String-Value Tests` {

  /// Verifies behavior on the empty string.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Empty String`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: "",
      configuration: configuration
    )
  }

  // MARK: 2.2 Unicode Strings

  /// Verifies behavior on strings containing emojis.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, String.unicodeExamples
  )
  func `Emojis`(
    configuration: XPCCodec.Configuration,
    probe: String
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  /// Verifies behavior on strings containing rtl content.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, String.rtlExamples
  )
  func `RTL Text`(
    configuration: XPCCodec.Configuration,
    probe: String
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  /// Verifies behavior on strings containing CJK content.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, String.cjkExamples
  )
  func `CJK Text`(
    configuration: XPCCodec.Configuration,
    probe: String
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  /// Verifies behavior on strings containing combining characters.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, String.combiningExamples
  )
  func `Combining Characters`(
    configuration: XPCCodec.Configuration,
    probe: String
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Very Long (x)`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: String(
        repeating: "x",
        count: 100_000
      ),
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Very Long (unicode)`(configuration: XPCCodec.Configuration) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: String(
        repeating: "你好🌍",
        count: 10_000
      ),
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Non-null control characters`(configuration: XPCCodec.Configuration) throws {
    let controlChars = (1...31).map { Character(UnicodeScalar($0)) }

    try verifyRoundTrip(
      ofValueAndWrappers: String(controlChars),
      configuration: configuration
    )

    // also check these

    // Bell, backspace, form feed, vertical tab
    try verifyRoundTrip(
      ofValueAndWrappers: "\u{0007}\u{0008}\u{000C}\u{000B}",
      configuration: configuration
    )

    // Escape character
    try verifyRoundTrip(
      ofValueAndWrappers: "\u{001B}",
      configuration: configuration
    )

    // Delete character
    try verifyRoundTrip(
      ofValueAndWrappers: "\u{007F}",
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, String.newlineAndTabExamples
  )
  func `Newlines & Tabs`(
    configuration: XPCCodec.Configuration,
    probe: String
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  // MARK: - Embedded Null Scenarios

  /// Check `.assumeAbsent` "succeeds" at encoding, but fails to round-trip.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.StringKeyStrategy.allCases, String.embeddedNullByteExamples
  )
  func `assumeAbsent (fails)`(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    probe: String
  ) throws {
    try #require(probe.containsNullBytes)
    withKnownIssue("Encoding/decoding succeeds, but produces different values for embedded null byte values under `.assumeAbsent`") {
      try verifyRoundTrip(
        ofValueAndWrappers: probe,
        configuration: XPCCodec.Configuration(
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: .assumeAbsent
        )
      )
    }
  }

  /// Check `.throwsOnDiscovery` should throw when it detects embedded null bytes.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.StringKeyStrategy.allCases, String.embeddedNullByteExamples
  )
  func `throwOnDiscovery (fails)`(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    probe: String
  ) throws {
    try #require(probe.containsNullBytes)
    #expect(throws: (any Error).self) {
      try verifyRoundTrip(
        ofValueAndWrappers: probe,
        configuration: XPCCodec.Configuration(
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: .throwOnDiscovery
        )
      )
    }
  }

  /// Check `.percentEscape` should round-trip strings even with embedded null bytes.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.StringKeyStrategy.allCases, String.embeddedNullByteExamples
  )
  func `percentEscape (ok)`(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    probe: String
  ) throws {
    try #require(probe.containsNullBytes)
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: XPCCodec.Configuration(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: .percentEscape
      )
    )
  }

  /// Check `.useDataRepresentation(.utf8)` should round-trip strings even with embedded null bytes.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.StringKeyStrategy.allCases, String.embeddedNullByteExamples
  )
  func `utf-8 (ok)`(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    probe: String
  ) throws {
    try #require(probe.containsNullBytes)
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: XPCCodec.Configuration(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: .useDataRepresentation(.utf8)
      )
    )
  }

  /// Check `.useDataRepresentation(.utf16)` should round-trip strings even with embedded null bytes.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.StringKeyStrategy.allCases, String.embeddedNullByteExamples
  )
  func `utf-16 (ok)`(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    probe: String
  ) throws {
    try #require(probe.containsNullBytes)
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: XPCCodec.Configuration(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: .useDataRepresentation(.utf16)
      )
    )
  }

  /// Check `.useDataRepresentation(.utf32)` should round-trip strings even with embedded null bytes.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.StringKeyStrategy.allCases, String.embeddedNullByteExamples
  )
  func `utf-32 (ok)`(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    probe: String
  ) throws {
    try #require(probe.containsNullBytes)
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: XPCCodec.Configuration(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: .useDataRepresentation(.utf32)
      )
    )
  }

}
