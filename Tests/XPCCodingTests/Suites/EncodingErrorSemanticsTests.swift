import Testing
@testable import XPCCoding

@Suite("Encoding Error Semantics")
struct EncodingErrorSemanticsTests {

  @Test
  func `user errors propagate unchanged from every placement`() {
    let sentinel = SentinelUserEncodingError()
    let leaf = UserErrorLeaf(error: sentinel)
    let encoder = XPCEncoder.standard

    expectSameUserError(sentinel, placement: "root") {
      _ = try encoder.encode(leaf)
    }
    expectSameUserError(sentinel, placement: "keyed") {
      _ = try encoder.encode(KeyedUserErrorProbe(value: leaf))
    }
    expectSameUserError(sentinel, placement: "unkeyed") {
      _ = try encoder.encode(UnkeyedUserErrorProbe(value: leaf))
    }
    expectSameUserError(sentinel, placement: "single-value") {
      _ = try encoder.encode(SingleValueUserErrorProbe(value: leaf))
    }
    expectSameUserError(sentinel, placement: "nested") {
      _ = try encoder.encode(NestedUserErrorProbe(value: leaf))
    }
  }

  @Test
  func `existing encoding errors retain descendant context through unkeyed placement`() {
    let underlyingError = SentinelUnderlyingEncodingError()

    do {
      _ = try XPCEncoder.standard.encode(
        NestedUnkeyedEncodingErrorProbe(
          value: DescendantEncodingErrorLeaf(
            underlyingError: underlyingError
          )
        )
      )
      Issue.record("Expected EncodingError.invalidValue.")
    } catch let EncodingError.invalidValue(invalidValue, context) {
      #expect(invalidValue as? String == DescendantEncodingErrorLeaf.invalidValue)
      #expect(
        context.codingPath.map(\.stringValue)
          == ["outer", "0", "descendant"]
      )
      #expect(
        context.debugDescription
          == DescendantEncodingErrorLeaf.debugDescription
      )
      #expect(
        (context.underlyingError as? SentinelUnderlyingEncodingError)
          === underlyingError
      )
    } catch {
      Issue.record(
        "Expected EncodingError.invalidValue, received \(String(reflecting: error))."
      )
    }
  }

  @Test
  func `throw-on-discovery reports invalid-value at every exact value path`() {
    let value = "embedded\u{0}null"
    let encoder = XPCEncoder(
      stringKeyStrategy: .standard,
      stringValueStrategy: .throwOnDiscovery
    )
    let codec = XPCCodec(
      configuration: .init(
        stringKeyStrategy: .standard,
        stringValueStrategy: .throwOnDiscovery
      )
    )

    expectNullStringInvalidValue(value, path: [], placement: "encoder root") {
      _ = try encoder.encode(value)
    }
    expectNullStringInvalidValue(value, path: [], placement: "codec root") {
      _ = try codec.encode(value)
    }
    expectNullStringInvalidValue(
      value,
      path: ["value"],
      placement: "keyed"
    ) {
      _ = try encoder.encode(KeyedNullStringProbe(value: value))
    }
    expectNullStringInvalidValue(
      value,
      path: ["0"],
      placement: "unkeyed"
    ) {
      _ = try encoder.encode(UnkeyedNullStringProbe(value: value))
    }
    expectNullStringInvalidValue(
      value,
      path: ["outer", "value"],
      placement: "nested"
    ) {
      _ = try encoder.encode(NestedNullStringProbe(value: value))
    }
    expectNullStringInvalidValue(
      value,
      path: [],
      placement: "transient single-value"
    ) {
      _ = try encoder.withTransientEncoder { transientEncoder in
        var container = transientEncoder.singleValueContainer()
        try container.encode(value)
      }
    }
  }

}

private final class SentinelUserEncodingError: Error, Sendable {}

private final class SentinelUnderlyingEncodingError: Error, Sendable {}

private enum EncodingErrorSemanticsKey: String, CodingKey {
  case value
  case outer
  case descendant
}

private struct UserErrorLeaf: Encodable {

  let error: SentinelUserEncodingError

  func encode(to encoder: any Encoder) throws {
    throw error
  }

}

private struct KeyedUserErrorProbe: Encodable {

  let value: UserErrorLeaf

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(
      keyedBy: EncodingErrorSemanticsKey.self
    )
    try container.encode(value, forKey: .value)
  }

}

private struct UnkeyedUserErrorProbe: Encodable {

  let value: UserErrorLeaf

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(value)
  }

}

private struct SingleValueUserErrorProbe: Encodable {

  let value: UserErrorLeaf

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(value)
  }

}

private struct NestedUserErrorProbe: Encodable {

  let value: UserErrorLeaf

  func encode(to encoder: any Encoder) throws {
    var root = encoder.container(keyedBy: EncodingErrorSemanticsKey.self)
    var nested = root.nestedContainer(
      keyedBy: EncodingErrorSemanticsKey.self,
      forKey: .outer
    )
    try nested.encode(value, forKey: .value)
  }

}

private struct DescendantEncodingErrorLeaf: Encodable {

  static let invalidValue = "intentional-invalid-value"
  static let debugDescription = "Intentional descendant encoding failure."

  let underlyingError: SentinelUnderlyingEncodingError

  func encode(to encoder: any Encoder) throws {
    var codingPath = encoder.codingPath
    codingPath.append(EncodingErrorSemanticsKey.descendant)
    throw EncodingError.invalidValue(
      Self.invalidValue,
      EncodingError.Context(
        codingPath: codingPath,
        debugDescription: Self.debugDescription,
        underlyingError: underlyingError
      )
    )
  }

}

private struct NestedUnkeyedEncodingErrorProbe: Encodable {

  let value: DescendantEncodingErrorLeaf

  func encode(to encoder: any Encoder) throws {
    var root = encoder.container(keyedBy: EncodingErrorSemanticsKey.self)
    var nested = root.nestedUnkeyedContainer(forKey: .outer)
    try nested.encode(value)
  }

}

private struct KeyedNullStringProbe: Encodable {

  let value: String

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(
      keyedBy: EncodingErrorSemanticsKey.self
    )
    try container.encode(value, forKey: .value)
  }

}

private struct UnkeyedNullStringProbe: Encodable {

  let value: String

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(value)
  }

}

private struct NestedNullStringProbe: Encodable {

  let value: String

  func encode(to encoder: any Encoder) throws {
    var root = encoder.container(keyedBy: EncodingErrorSemanticsKey.self)
    var nested = root.nestedContainer(
      keyedBy: EncodingErrorSemanticsKey.self,
      forKey: .outer
    )
    try nested.encode(value, forKey: .value)
  }

}

private func expectSameUserError(
  _ expectedError: SentinelUserEncodingError,
  placement: String,
  operation: () throws -> Void
) {
  do {
    try operation()
    Issue.record("Expected the sentinel user error from \(placement).")
  } catch {
    #expect(
      (error as? SentinelUserEncodingError) === expectedError,
      """
      Expected the original sentinel user error from \(placement), received \
      \(String(reflecting: error)).
      """
    )
  }
}

private func expectNullStringInvalidValue(
  _ expectedValue: String,
  path expectedPath: [String],
  placement: String,
  operation: () throws -> Void
) {
  do {
    try operation()
    Issue.record("Expected EncodingError.invalidValue from \(placement).")
  } catch let EncodingError.invalidValue(invalidValue, context) {
    #expect(
      invalidValue as? String == expectedValue,
      "The invalid value changed at \(placement)."
    )
    #expect(
      context.codingPath.map(\.stringValue) == expectedPath,
      "The coding path was incorrect at \(placement)."
    )
    guard
      let conversionError = context.underlyingError
        as? String.XPCObjectConversionError
    else {
      Issue.record(
        "Expected the internal string-conversion cause at \(placement)."
      )
      return
    }
    guard case .containsNullBytes(let underlyingValue) = conversionError else {
      Issue.record(
        "Expected containsNullBytes as the cause at \(placement)."
      )
      return
    }
    #expect(
      underlyingValue == expectedValue,
      "The underlying string-conversion value changed at \(placement)."
    )
  } catch {
    Issue.record(
      """
      Expected EncodingError.invalidValue from \(placement), received \
      \(String(reflecting: error)).
      """
    )
  }
}
