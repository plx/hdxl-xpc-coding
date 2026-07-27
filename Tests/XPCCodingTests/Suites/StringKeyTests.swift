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

  /// Verify the exact truncation-and-collision outcome for embedded-null keys
  /// under `.assumeAbsent`.
  ///
  /// The four source keys truncate at their first null byte to `""`, `"bar"`,
  /// `""`, and `"q"`. Two of them collide on the empty key, and the later
  /// `.baz` write wins, so the encoded dictionary holds three entries and the
  /// decoded value differs from the original in exactly one field.
  @Test(
    .tags(.roundTrip, .keyed),
    arguments: XPCCodec.StringValueStrategy.allCases
  )
  func `assume absent truncates and collides (lossy)`(
    stringValueStrategy: XPCCodec.StringValueStrategy
  ) throws {
    let codec = XPCCodec(
      configuration: XPCCodec.Configuration(
        stringKeyStrategy: .assumeAbsent,
        stringValueStrategy: stringValueStrategy
      )
    )
    let value = KeysWithEmbeddedNullStruct.exampleValue
    let expected = KeysWithEmbeddedNullStruct.assumeAbsentDecodedValue

    // `.assumeAbsent` is intentionally lossy; it must not become a round trip.
    #expect(value != expected)

    let encoded = try codec.encode(value)
    #expect(xpc_get_type(encoded) == XPC_TYPE_DICTIONARY)
    #expect(xpc_dictionary_get_count(encoded) == 3)
    #expect(
      try codec.decode([String: Int].self, from: encoded) == [
        "": 3,
        "bar": 2,
        "q": 4,
      ]
    )

    #expect(try transcodedValue(value, using: codec) == expected)
    #expect(try transcodedValue(SingleValueWrapper(value), using: codec).value == expected)
    #expect(try transcodedValue(UnkeyedValueWrapper(value), using: codec).value == expected)
    #expect(try transcodedValue(KeyedValueWrapper(value), using: codec).value == expected)
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
