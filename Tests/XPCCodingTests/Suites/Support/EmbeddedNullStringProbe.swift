import Testing
import XPC
@testable import XPCCoding

// MARK: - EmbeddedNullStringProbe

/// A `String` fixture that always contains at least one embedded null byte.
///
/// These probes exist to pin down *exact* behavior, including the intentionally
/// lossy `.assumeAbsent` behavior, so they deliberately never expose their raw
/// value to the test transcript:
///
/// - ``testDescription`` supplies a null-free label for the test-case name that
///   swift-testing derives from the parameter value; and
/// - the verification helpers below compare UTF-8 byte arrays, so even a
///   failure message reports bytes rather than a raw null byte.
struct EmbeddedNullStringProbe: Sendable, CustomTestStringConvertible {

  /// A null-free label identifying this probe in test-case names and messages.
  let testDescription: String

  /// The probe value; always contains at least one embedded null byte.
  let value: String

  /// Exactly what the intentionally-lossy `.assumeAbsent` strategies produce:
  /// everything preceding the first embedded null byte.
  let expectedTruncatedValue: String

  /// The probe value's UTF-8 bytes.
  var valueUTF8: [UInt8] {
    Array(value.utf8)
  }

  /// The truncated value's UTF-8 bytes.
  var expectedTruncatedUTF8: [UInt8] {
    Array(expectedTruncatedValue.utf8)
  }

  static let allCases: [Self] = [
    Self(
      testDescription: "null-only",
      value: "\0",
      expectedTruncatedValue: ""
    ),
    Self(
      testDescription: "interior-null",
      value: "Hello\0world",
      expectedTruncatedValue: "Hello"
    ),
    Self(
      testDescription: "trailing-null",
      value: "bar\0",
      expectedTruncatedValue: "bar"
    ),
    Self(
      testDescription: "leading-null",
      value: "\0baz",
      expectedTruncatedValue: ""
    ),
    Self(
      testDescription: "repeated-nulls",
      value: "q\0u\0u\0x",
      expectedTruncatedValue: "q"
    ),
  ]

}

// MARK: - Fixture Integrity

extension EmbeddedNullStringProbe {

  /// Verifies this probe is a meaningful embedded-null fixture: it contains a
  /// null byte, and truncating at the first null byte actually loses data.
  ///
  /// Without this, a future edit could silently reduce the embedded-null suites
  /// to null-free round trips that pass for the wrong reason.
  func verifyFixtureIntegrity(
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    #expect(
      valueUTF8.contains(0),
      """
      Probe `\(testDescription)` must contain an embedded null byte.
      """,
      sourceLocation: sourceLocation
    )
    #expect(
      valueUTF8 != expectedTruncatedUTF8,
      """
      Probe `\(testDescription)` must lose data when truncated at its first null byte.
      """,
      sourceLocation: sourceLocation
    )
    #expect(
      expectedTruncatedUTF8 == Array(valueUTF8.prefix(while: { $0 != 0 })),
      """
      Probe `\(testDescription)` declares a truncation that is not the prefix preceding its first null byte.

      - declared-utf8: \(expectedTruncatedUTF8)
      - prefix-utf8:   \(Array(valueUTF8.prefix(while: { $0 != 0 })))
      """,
      sourceLocation: sourceLocation
    )
  }

}

// MARK: - Codec-Level Verification

/// Encodes and decodes `value` in each supported container shape, reporting the
/// decoded UTF-8 bytes alongside a label for the shape that produced them.
private func transcodedUTF8ByShape(
  of value: String,
  using codec: XPCCodec
) throws -> [(shape: String, decodedUTF8: [UInt8])] {
  [
    (
      "direct",
      Array(try transcodedValue(value, using: codec).utf8)
    ),
    (
      "single-value-wrapped",
      Array(try transcodedValue(SingleValueWrapper(value), using: codec).value.utf8)
    ),
    (
      "unkeyed-wrapped",
      Array(try transcodedValue(UnkeyedValueWrapper(value), using: codec).value.utf8)
    ),
    (
      "keyed-wrapped",
      Array(try transcodedValue(KeyedValueWrapper(value), using: codec).value.utf8)
    ),
  ]
}

/// Verifies `codec` round-trips `probe` exactly, in every container shape.
///
/// This is the contract for the safe string-value strategies, which must
/// preserve embedded null bytes.
func verifyExactRoundTrip(
  of probe: EmbeddedNullStringProbe,
  using codec: XPCCodec,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  for (shape, decodedUTF8) in try transcodedUTF8ByShape(of: probe.value, using: codec) {
    #expect(
      decodedUTF8 == probe.valueUTF8,
      """
      Expected an exact round trip for probe `\(probe.testDescription)`, \(shape), \
      with configuration \(codec.configuration):

      - original-utf8: \(probe.valueUTF8)
      - decoded-utf8:  \(decodedUTF8)
      """,
      sourceLocation: sourceLocation
    )
  }
}

/// Verifies `codec` truncates `probe` at its first null byte, in every
/// container shape, and that the result is genuinely lossy.
///
/// This is the contract for the intentionally lossy `.assumeAbsent` string-value
/// strategy; the inequality assertion is what keeps it behaviorally distinct
/// from the safe strategies verified by ``verifyExactRoundTrip(of:using:sourceLocation:)``.
func verifyTruncatingRoundTrip(
  of probe: EmbeddedNullStringProbe,
  using codec: XPCCodec,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  probe.verifyFixtureIntegrity(sourceLocation: sourceLocation)

  for (shape, decodedUTF8) in try transcodedUTF8ByShape(of: probe.value, using: codec) {
    #expect(
      decodedUTF8 == probe.expectedTruncatedUTF8,
      """
      Expected truncation at the first null byte for probe `\(probe.testDescription)`, \(shape), \
      with configuration \(codec.configuration):

      - expected-utf8: \(probe.expectedTruncatedUTF8)
      - decoded-utf8:  \(decodedUTF8)
      """,
      sourceLocation: sourceLocation
    )
    #expect(
      decodedUTF8 != probe.valueUTF8,
      """
      `.assumeAbsent` round-tripped probe `\(probe.testDescription)` exactly, \(shape); \
      it is required to stay lossy and therefore distinct from the safe strategies.
      """,
      sourceLocation: sourceLocation
    )
  }
}

/// Verifies `codec` refuses to encode `probe` in every container shape, with the
/// exact `EncodingError.invalidValue` the `.throwOnDiscovery` strategy documents.
func verifyThrowOnDiscoveryFailure(
  for probe: EmbeddedNullStringProbe,
  using codec: XPCCodec,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  probe.verifyFixtureIntegrity(sourceLocation: sourceLocation)

  verifyEmbeddedNullEncodingFailure(probe, shape: "direct", sourceLocation: sourceLocation) {
    try codec.encode(probe.value)
  }
  verifyEmbeddedNullEncodingFailure(probe, shape: "single-value-wrapped", sourceLocation: sourceLocation) {
    try codec.encode(SingleValueWrapper(probe.value))
  }
  verifyEmbeddedNullEncodingFailure(probe, shape: "unkeyed-wrapped", sourceLocation: sourceLocation) {
    try codec.encode(UnkeyedValueWrapper(probe.value))
  }
  verifyEmbeddedNullEncodingFailure(probe, shape: "keyed-wrapped", sourceLocation: sourceLocation) {
    try codec.encode(KeyedValueWrapper(probe.value))
  }
}

private func verifyEmbeddedNullEncodingFailure(
  _ probe: EmbeddedNullStringProbe,
  shape: String,
  sourceLocation: SourceLocation,
  operation: () throws -> xpc_object_t
) {
  do {
    _ = try operation()
    Issue.record(
      """
      Expected `EncodingError.invalidValue` for probe `\(probe.testDescription)`, \(shape).
      """,
      sourceLocation: sourceLocation
    )
  } catch let EncodingError.invalidValue(invalidValue, context) {
    #expect(
      (invalidValue as? String).map { Array($0.utf8) } == probe.valueUTF8,
      """
      The reported invalid value changed for probe `\(probe.testDescription)`, \(shape).
      """,
      sourceLocation: sourceLocation
    )
    guard
      let conversionError = context.underlyingError as? String.XPCObjectConversionError,
      case .containsNullBytes(let reportedValue) = conversionError
    else {
      Issue.record(
        """
        Expected `containsNullBytes` as the underlying cause for probe \
        `\(probe.testDescription)`, \(shape).
        """,
        sourceLocation: sourceLocation
      )
      return
    }
    #expect(
      Array(reportedValue.utf8) == probe.valueUTF8,
      """
      The underlying string-conversion value changed for probe \
      `\(probe.testDescription)`, \(shape).
      """,
      sourceLocation: sourceLocation
    )
  } catch {
    // Deliberately reports the error *type*: the error payload carries the
    // probe value, and reflecting it would put a raw null byte in the log.
    Issue.record(
      """
      Expected `EncodingError.invalidValue` for probe `\(probe.testDescription)`, \(shape), \
      but received \(type(of: error)).
      """,
      sourceLocation: sourceLocation
    )
  }
}

// MARK: - Conversion-Level Verification

extension EmbeddedNullStringProbe {

  /// The UTF-8 bytes obtained by converting this probe to an `xpc_object_t` and
  /// back with `stringValueStrategy`, bypassing the `Codable` machinery.
  func transcodedUTF8(
    stringValueStrategy: XPCCodec.StringValueStrategy
  ) throws -> [UInt8] {
    let xpcObject = try value.makeXPCObjectRepresentation(
      stringValueStrategy: stringValueStrategy.encodingStrategy
    )
    let extractedString = try xpcObject._extractStringValue(
      stringValueStrategy: stringValueStrategy.decodingStrategy
    )

    return Array(extractedString.utf8)
  }

  /// Verifies the raw string-conversion layer rejects this probe under
  /// `.throwOnDiscovery`, reporting the offending value.
  func verifyThrowOnDiscoveryConversionFailure(
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    do {
      _ = try value.makeXPCObjectRepresentation(
        stringValueStrategy: XPCCodec.StringValueStrategy.throwOnDiscovery.encodingStrategy
      )
      Issue.record(
        """
        Expected `containsNullBytes` for probe `\(testDescription)`.
        """,
        sourceLocation: sourceLocation
      )
    } catch {
      // `makeXPCObjectRepresentation(stringValueStrategy:)` uses typed throws,
      // so `error` is already the exact conversion-error type; switching over
      // it pins the specific case and its payload, and stays exhaustive.
      switch error {
      case .containsNullBytes(let reportedValue):
        #expect(
          Array(reportedValue.utf8) == valueUTF8,
          """
          The reported offending value changed for probe `\(testDescription)`.
          """,
          sourceLocation: sourceLocation
        )
      }
    }
  }

}
