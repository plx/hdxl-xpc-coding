import Testing
import XPC
@testable import XPCCoding

@Suite("Keyed decodeNil")
struct KeyedDecodeNilTests {

  @Test
  func `missing key throws key-not-found at the parent path`() throws {
    let input = xpc_dictionary_create(nil, nil, 0)

    let error = try #require(throws: DecodingError.self) {
      _ = try XPCDecoder.standard.decode(
        DirectDecodeNilProbe.self,
        from: input
      )
    }

    guard case .keyNotFound(let key, let context) = error else {
      Issue.record(
        "Expected keyNotFound, received \(String(reflecting: error))."
      )
      return
    }
    #expect(key.stringValue == DecodeNilKey.value.stringValue)
    try verifyCodingPath(context.codingPath, matches: [])
  }

  @Test
  func `explicit XPC null returns true`() throws {
    let input = xpc_dictionary_create(nil, nil, 0)
    input.setNil(
      forKey: DecodeNilKey.value,
      strategy: .percentEscape
    )

    let decoded = try XPCDecoder.standard.decode(
      DirectDecodeNilProbe.self,
      from: input
    )

    #expect(decoded.isNil)
  }

  @Test
  func `present non-null value returns false`() throws {
    let input = xpc_dictionary_create(nil, nil, 0)
    input.setValue(
      Int64(42),
      forKey: DecodeNilKey.value,
      strategy: .percentEscape
    )

    let decoded = try XPCDecoder.standard.decode(
      DirectDecodeNilProbe.self,
      from: input
    )

    #expect(!decoded.isNil)
  }

  @Test
  func `nested missing key reports its parent container path`() throws {
    let input = xpc_dictionary_create(nil, nil, 0)
    input.setValue(
      xpc_dictionary_create(nil, nil, 0),
      forKey: DecodeNilKey.outer,
      strategy: .percentEscape
    )

    let error = try #require(throws: DecodingError.self) {
      _ = try XPCDecoder.standard.decode(
        NestedDecodeNilProbe.self,
        from: input
      )
    }

    guard case .keyNotFound(let key, let context) = error else {
      Issue.record(
        "Expected keyNotFound, received \(String(reflecting: error))."
      )
      return
    }
    #expect(key.stringValue == DecodeNilKey.value.stringValue)
    try verifyCodingPath(context.codingPath, matches: ["outer"])
  }

  @Test
  func `percent and null scalar keys preserve escaped lookup behavior`() throws {
    let input = xpc_dictionary_create(nil, nil, 0)
    input.setNil(
      forKey: DecodeNilKey.percent,
      strategy: .percentEscape
    )
    input.setValue(
      Int64(42),
      forKey: DecodeNilKey.nullScalar,
      strategy: .percentEscape
    )

    let decoded = try XPCDecoder.standard.decode(
      EscapedKeyDecodeNilProbe.self,
      from: input
    )

    #expect(decoded.percentIsNil)
    #expect(!decoded.nullScalarIsNil)
  }

  @Test
  func `decodeIfPresent still returns nil for an absent key`() throws {
    let input = xpc_dictionary_create(nil, nil, 0)

    let decoded = try XPCDecoder.standard.decode(
      DecodeIfPresentProbe.self,
      from: input
    )

    #expect(decoded.value == nil)
  }

}

private enum DecodeNilKey: String, CodingKey {
  case value
  case outer
  case percent = "percent%key"
  case nullScalar = "null\0key"
}

private struct DirectDecodeNilProbe: Decodable {

  let isNil: Bool

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: DecodeNilKey.self)
    isNil = try container.decodeNil(forKey: .value)
  }

}

private struct NestedDecodeNilProbe: Decodable {

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: DecodeNilKey.self)
    let nested = try container.nestedContainer(
      keyedBy: DecodeNilKey.self,
      forKey: .outer
    )
    _ = try nested.decodeNil(forKey: .value)
  }

}

private struct EscapedKeyDecodeNilProbe: Decodable {

  let percentIsNil: Bool
  let nullScalarIsNil: Bool

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: DecodeNilKey.self)
    percentIsNil = try container.decodeNil(forKey: .percent)
    nullScalarIsNil = try container.decodeNil(forKey: .nullScalar)
  }

}

private struct DecodeIfPresentProbe: Decodable {

  let value: Int?

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: DecodeNilKey.self)
    value = try container.decodeIfPresent(Int.self, forKey: .value)
  }

}
