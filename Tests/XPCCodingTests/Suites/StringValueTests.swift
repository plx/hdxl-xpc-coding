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

  /// Check `.assumeAbsent` truncates at the first null byte, in every container
  /// shape, and therefore stays lossy — distinct from every safe strategy below.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.StringKeyStrategy.allCases, EmbeddedNullStringProbe.allCases
  )
  func `assumeAbsent truncates (lossy)`(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    probe: EmbeddedNullStringProbe
  ) throws {
    try verifyTruncatingRoundTrip(
      of: probe,
      using: embeddedNullCodec(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: .assumeAbsent
      )
    )
  }

  /// Check `.throwOnDiscovery` throws `EncodingError.invalidValue`, caused by
  /// the internal `containsNullBytes` conversion failure, in every shape.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.StringKeyStrategy.allCases, EmbeddedNullStringProbe.allCases
  )
  func `throwOnDiscovery (fails)`(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    probe: EmbeddedNullStringProbe
  ) throws {
    verifyThrowOnDiscoveryFailure(
      for: probe,
      using: embeddedNullCodec(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: .throwOnDiscovery
      )
    )
  }

  /// Check `.percentEscape` should round-trip strings even with embedded null bytes.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.StringKeyStrategy.allCases, EmbeddedNullStringProbe.allCases
  )
  func `percentEscape (ok)`(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    probe: EmbeddedNullStringProbe
  ) throws {
    try verifyExactRoundTrip(
      of: probe,
      using: embeddedNullCodec(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: .percentEscape
      )
    )
  }

  /// Check `.useDataRepresentation(.utf8)` should round-trip strings even with embedded null bytes.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.StringKeyStrategy.allCases, EmbeddedNullStringProbe.allCases
  )
  func `utf-8 (ok)`(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    probe: EmbeddedNullStringProbe
  ) throws {
    try verifyExactRoundTrip(
      of: probe,
      using: embeddedNullCodec(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: .useDataRepresentation(.utf8)
      )
    )
  }

  /// Check `.useDataRepresentation(.utf16)` should round-trip strings even with embedded null bytes.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.StringKeyStrategy.allCases, EmbeddedNullStringProbe.allCases
  )
  func `utf-16 (ok)`(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    probe: EmbeddedNullStringProbe
  ) throws {
    try verifyExactRoundTrip(
      of: probe,
      using: embeddedNullCodec(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: .useDataRepresentation(.utf16)
      )
    )
  }

  /// Check `.useDataRepresentation(.utf32)` should round-trip strings even with embedded null bytes.
  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.StringKeyStrategy.allCases, EmbeddedNullStringProbe.allCases
  )
  func `utf-32 (ok)`(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    probe: EmbeddedNullStringProbe
  ) throws {
    try verifyExactRoundTrip(
      of: probe,
      using: embeddedNullCodec(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: .useDataRepresentation(.utf32)
      )
    )
  }

  @Test(
    arguments: XPCCodec.StringValueDataRepresentation.allCases
  )
  func `data-backed decoded strings own their storage`(
    representation: XPCCodec.StringValueDataRepresentation
  ) throws {
    let expected = String(
      repeating: "owned\u{0}storage-%-🙂",
      count: 4_096
    )
    let decoded = try decodeStringInsideXPCObjectScope(
      expected,
      representation: representation
    )

    #expect(decoded == expected)
  }

  private func embeddedNullCodec(
    stringKeyStrategy: XPCCodec.StringKeyStrategy,
    stringValueStrategy: XPCCodec.StringValueStrategy
  ) -> XPCCodec {
    XPCCodec(
      configuration: XPCCodec.Configuration(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: stringValueStrategy
      )
    )
  }

  private func decodeStringInsideXPCObjectScope(
    _ expected: String,
    representation: XPCCodec.StringValueDataRepresentation
  ) throws -> String {
    let codec = XPCCodec(
      configuration: .init(
        stringKeyStrategy: .percentEscape,
        stringValueStrategy: .useDataRepresentation(representation)
      )
    )
    let object = try codec.encode(expected)
    return try codec.decode(String.self, from: object)
  }

}
