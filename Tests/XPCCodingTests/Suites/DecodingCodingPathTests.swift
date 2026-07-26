import Testing
@testable import XPCCoding

@Suite("Decoding Coding Paths")
struct DecodingCodingPathTests {

  @Test
  func `keyed nested unkeyed primitive failure reports complete path`() throws {
    let input = try XPCEncoder.standard.encode(
      KeyedArrayWire(a: ["not an integer"])
    )

    let error = try #require(throws: DecodingError.self) {
      _ = try XPCDecoder.standard.decode(
        KeyedPrimitiveMismatchProbe.self,
        from: input
      )
    }

    try verifyCodingPath(of: error, matches: ["a", "0"])
  }

  @Test
  func `keyed nested unkeyed generic child receives complete path`() throws {
    let input = try XPCEncoder.standard.encode(
      KeyedArrayWire(a: [17])
    )

    let decoded = try XPCDecoder.standard.decode(
      KeyedGenericPathProbe.self,
      from: input
    )

    #expect(decoded.childPath == ["a", "0"])
  }

  @Test
  func `unkeyed nested keyed generic child receives complete path`() throws {
    let input = try XPCEncoder.standard.encode(
      KeyedArrayWire(a: [["leaf": 17]])
    )

    let decoded = try XPCDecoder.standard.decode(
      UnkeyedNestedKeyedPathProbe.self,
      from: input
    )

    #expect(decoded.containerPath == ["a", "0"])
    #expect(decoded.childPath == ["a", "0", "leaf"])
  }

  @Test
  func `unkeyed nested unkeyed generic child receives complete path`() throws {
    let input = try XPCEncoder.standard.encode(
      KeyedArrayWire(a: [[17]])
    )

    let decoded = try XPCDecoder.standard.decode(
      UnkeyedNestedUnkeyedPathProbe.self,
      from: input
    )

    #expect(decoded.containerPath == ["a", "0"])
    #expect(decoded.childPath == ["a", "0", "0"])
  }

  @Test
  func `unkeyed super decoder receives complete path`() throws {
    let input = try XPCEncoder.standard.encode(
      KeyedArrayWire(a: [17])
    )

    let decoded = try XPCDecoder.standard.decode(
      UnkeyedSuperDecoderPathProbe.self,
      from: input
    )

    #expect(decoded.childPath == ["a", "0"])
  }

  @Test
  func `retained sibling unkeyed containers remain path-independent`() throws {
    let input = try XPCEncoder.standard.encode(
      SiblingArrayWire(first: [17], second: [29], marker: 41)
    )

    let decoded = try XPCDecoder.standard.decode(
      RetainedSiblingDecodingPathProbe.self,
      from: input
    )

    #expect(decoded.firstContainerPath == ["first"])
    #expect(decoded.secondContainerPath == ["second"])
    #expect(decoded.firstChildPath == ["first", "0"])
    #expect(decoded.secondChildPath == ["second", "0"])
  }

  @Test
  func `failed child decode preserves index and path for retry`() throws {
    let input = try XPCEncoder.standard.encode(RetryWire())

    let decoded = try XPCDecoder.standard.decode(
      FailureRetryPathProbe.self,
      from: input
    )

    #expect(decoded.failurePath == ["a", "0"])
    #expect(decoded.indexAfterFailure == 0)
    #expect(decoded.retriedValue == "not an integer")
    #expect(decoded.indexAfterRetry == 1)
    #expect(decoded.nextValue == 17)
    #expect(decoded.indexAfterNextValue == 2)
  }

}

private enum DecodingPathKey: String, CodingKey {
  case a
  case leaf
  case first
  case second
  case marker
}

private struct KeyedArrayWire<Element: Encodable>: Encodable {
  let a: [Element]
}

private struct SiblingArrayWire<Element: Encodable>: Encodable {
  let first: [Element]
  let second: [Element]
  let marker: Int
}

private struct RetryWire: Encodable {

  func encode(to encoder: any Encoder) throws {
    var root = encoder.container(keyedBy: DecodingPathKey.self)
    var array = root.nestedUnkeyedContainer(forKey: .a)
    try array.encode("not an integer")
    try array.encode(17)
  }

}

private struct DecodingPathLeaf: Decodable {

  let path: [String]

  init(from decoder: any Decoder) throws {
    path = decoder.codingPath.map(\.stringValue)
    let container = try decoder.singleValueContainer()
    _ = try container.decode(Int.self)
  }

}

private struct KeyedPrimitiveMismatchProbe: Decodable {

  init(from decoder: any Decoder) throws {
    let root = try decoder.container(keyedBy: DecodingPathKey.self)
    var array = try root.nestedUnkeyedContainer(forKey: .a)
    _ = try array.decode(Int.self)
  }

}

private struct KeyedGenericPathProbe: Decodable {

  let childPath: [String]

  init(from decoder: any Decoder) throws {
    let root = try decoder.container(keyedBy: DecodingPathKey.self)
    var array = try root.nestedUnkeyedContainer(forKey: .a)
    childPath = try array.decode(DecodingPathLeaf.self).path
  }

}

private struct UnkeyedNestedKeyedPathProbe: Decodable {

  let containerPath: [String]
  let childPath: [String]

  init(from decoder: any Decoder) throws {
    let root = try decoder.container(keyedBy: DecodingPathKey.self)
    var array = try root.nestedUnkeyedContainer(forKey: .a)
    let nested = try array.nestedContainer(keyedBy: DecodingPathKey.self)
    containerPath = nested.codingPath.map(\.stringValue)
    childPath = try nested.decode(
      DecodingPathLeaf.self,
      forKey: .leaf
    ).path
  }

}

private struct UnkeyedNestedUnkeyedPathProbe: Decodable {

  let containerPath: [String]
  let childPath: [String]

  init(from decoder: any Decoder) throws {
    let root = try decoder.container(keyedBy: DecodingPathKey.self)
    var array = try root.nestedUnkeyedContainer(forKey: .a)
    var nested = try array.nestedUnkeyedContainer()
    containerPath = nested.codingPath.map(\.stringValue)
    childPath = try nested.decode(DecodingPathLeaf.self).path
  }

}

private struct UnkeyedSuperDecoderPathProbe: Decodable {

  let childPath: [String]

  init(from decoder: any Decoder) throws {
    let root = try decoder.container(keyedBy: DecodingPathKey.self)
    var array = try root.nestedUnkeyedContainer(forKey: .a)
    childPath = try DecodingPathLeaf(
      from: array.superDecoder()
    ).path
  }

}

private struct RetainedSiblingDecodingPathProbe: Decodable {

  let firstContainerPath: [String]
  let secondContainerPath: [String]
  let firstChildPath: [String]
  let secondChildPath: [String]

  init(from decoder: any Decoder) throws {
    let root = try decoder.container(keyedBy: DecodingPathKey.self)
    var first = try root.nestedUnkeyedContainer(forKey: .first)
    var second = try root.nestedUnkeyedContainer(forKey: .second)

    _ = try root.decode(Int.self, forKey: .marker)
    firstContainerPath = first.codingPath.map(\.stringValue)
    secondContainerPath = second.codingPath.map(\.stringValue)
    firstChildPath = try first.decode(DecodingPathLeaf.self).path
    secondChildPath = try second.decode(DecodingPathLeaf.self).path
  }

}

private struct FailureRetryPathProbe: Decodable {

  let failurePath: [String]
  let indexAfterFailure: Int
  let retriedValue: String
  let indexAfterRetry: Int
  let nextValue: Int
  let indexAfterNextValue: Int

  init(from decoder: any Decoder) throws {
    let root = try decoder.container(keyedBy: DecodingPathKey.self)
    var array = try root.nestedUnkeyedContainer(forKey: .a)

    do {
      _ = try array.decode(Int.self)
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: array.codingPath,
          debugDescription: "Expected the first integer decode to fail."
        )
      )
    } catch let DecodingError.typeMismatch(_, context) {
      failurePath = context.codingPath.map(\.stringValue)
    }

    indexAfterFailure = array.currentIndex
    retriedValue = try array.decode(String.self)
    indexAfterRetry = array.currentIndex
    nextValue = try array.decode(Int.self)
    indexAfterNextValue = array.currentIndex
  }

}
