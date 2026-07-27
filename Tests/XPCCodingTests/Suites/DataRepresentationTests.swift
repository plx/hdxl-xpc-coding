import Foundation
import Testing
import XPC
@testable import XPCCoding

// MARK: - Data Representation Tests

@Suite("Data Representation")
struct DataRepresentationTests {

  @Test(arguments: [0, 1, 16, 4_096, 1_048_576])
  func `top-level Data uses one XPC data object`(
    byteCount: Int
  ) throws {
    let expected = dataFixture(byteCount: byteCount)
    let encoded = try XPCEncoder.standard.encode(expected)

    try requireXPCData(encoded, equals: expected)
    #expect(xpcObjectCount(encoded) == 1)
    #expect(try XPCDecoder.standard.decode(Data.self, from: encoded) == expected)
  }

  @Test(arguments: [0, 1, 4_096, 1_048_576])
  func `decoded Data owns bytes beyond the XPC object scope`(
    byteCount: Int
  ) throws {
    let expected = dataFixture(byteCount: byteCount)
    let decoded = try decodeDataInsideXPCObjectScope(expected)

    #expect(decoded == expected)
  }

  @Test
  func `missing keyed Data preserves the key-not-found error`() throws {
    let key = try #require(XPCCodingKey(stringValue: "value"))
    let error = try #require(throws: DecodingError.self) {
      try xpc_dictionary_create_empty().extractValue(
        ofType: Data.self,
        at: [],
        forKey: key,
        stringKeyStrategy: .standard
      )
    }

    guard case .keyNotFound(let missingKey, let context) = error else {
      Issue.record("Expected DecodingError.keyNotFound, received \(error).")
      return
    }
    #expect(missingKey.stringValue == key.stringValue)
    #expect(context.codingPath.isEmpty)
  }

  @Test
  func `keyed nested and generic Data positions retain exact shape`() throws {
    let expected = dataFixture(byteCount: 16)
    let keyed = KeyedDataFixture(
      neighbor: 17,
      data: expected
    )
    let encodedKeyed = try XPCEncoder.standard.encode(keyed)
    let keyedData = try requireDictionaryValue(encodedKeyed, key: "data")

    try requireXPCData(keyedData, equals: expected)
    #expect(xpcObjectCount(encodedKeyed) == 3)
    #expect(try XPCDecoder.standard.decode(KeyedDataFixture.self, from: encodedKeyed) == keyed)

    let nested = NestedDataFixture(
      sibling: "neighbor",
      inner: keyed
    )
    let encodedNested = try XPCEncoder.standard.encode(nested)
    let inner = try requireDictionaryValue(encodedNested, key: "inner")
    let nestedData = try requireDictionaryValue(inner, key: "data")

    try requireXPCData(nestedData, equals: expected)
    #expect(xpcObjectCount(encodedNested) == 5)
    #expect(
      try XPCDecoder.standard.decode(
        NestedDataFixture.self,
        from: encodedNested
      ) == nested
    )

    let generic = GenericDataFixture(value: expected)
    let encodedGeneric = try XPCEncoder.standard.encode(generic)
    let genericData = try requireDictionaryValue(encodedGeneric, key: "value")

    try requireXPCData(genericData, equals: expected)
    #expect(xpcObjectCount(encodedGeneric) == 2)
    #expect(
      try XPCDecoder.standard.decode(
        GenericDataFixture<Data>.self,
        from: encodedGeneric
      ) == generic
    )
  }

  @Test
  func `unkeyed Data elements are XPC data children`() throws {
    let expected = [
      Data(),
      dataFixture(byteCount: 1),
      dataFixture(byteCount: 16),
    ]
    let encoded = try XPCEncoder.standard.encode(expected)

    #expect(xpc_get_type(encoded) == XPC_TYPE_ARRAY)
    #expect(xpc_array_get_count(encoded) == expected.count)
    #expect(xpcObjectCount(encoded) == expected.count + 1)
    for (index, data) in expected.enumerated() {
      try requireXPCData(
        xpc_array_get_value(encoded, index),
        equals: data
      )
    }
    #expect(try XPCDecoder.standard.decode([Data].self, from: encoded) == expected)
  }

  @Test
  func `optional and single-value Data use the direct shape`() throws {
    let expected = dataFixture(byteCount: 16)
    let optional: Data? = expected
    let encodedOptional = try XPCEncoder.standard.encode(optional)

    try requireXPCData(encodedOptional, equals: expected)
    #expect(xpcObjectCount(encodedOptional) == 1)
    #expect(try XPCDecoder.standard.decode(Data?.self, from: encodedOptional) == optional)

    let keyedOptional = OptionalDataFixture(value: expected)
    let encodedKeyedOptional = try XPCEncoder.standard.encode(keyedOptional)
    let keyedOptionalData = try requireDictionaryValue(
      encodedKeyedOptional,
      key: "value"
    )

    try requireXPCData(keyedOptionalData, equals: expected)
    #expect(xpcObjectCount(encodedKeyedOptional) == 2)
    #expect(
      try XPCDecoder.standard.decode(
        OptionalDataFixture.self,
        from: encodedKeyedOptional
      ) == keyedOptional
    )

    let singleValue = SingleValueDataFixture(value: expected)
    let encodedSingleValue = try XPCEncoder.standard.encode(singleValue)

    try requireXPCData(encodedSingleValue, equals: expected)
    #expect(xpcObjectCount(encodedSingleValue) == 1)
    #expect(
      try XPCDecoder.standard.decode(
        SingleValueDataFixture.self,
        from: encodedSingleValue
      ) == singleValue
    )
  }

  @Test
  func `super encoder retains Data and neighboring fields`() throws {
    let expected = DataChildFixture(
      baseData: dataFixture(byteCount: 16),
      baseNeighbor: 17,
      childNeighbor: "child"
    )
    let encoded = try XPCEncoder.standard.encode(expected)
    let encodedSuper = try requireDictionaryValue(
      encoded,
      key: XPCCodingKey.superKey.stringValue
    )
    let encodedData = try requireDictionaryValue(
      encodedSuper,
      key: "baseData"
    )

    try requireXPCData(encodedData, equals: expected.baseData)
    #expect(xpc_dictionary_get_count(encoded) == 2)
    #expect(xpc_dictionary_get_count(encodedSuper) == 2)
    #expect(xpcObjectCount(encoded) == 5)
    #expect(
      xpc_string_get_string_ptr(
        try requireDictionaryValue(encoded, key: "childNeighbor")
      ).map(String.init(cString:)) == expected.childNeighbor
    )
    #expect(
      xpc_int64_get_value(
        try requireDictionaryValue(encodedSuper, key: "baseNeighbor")
      ) == expected.baseNeighbor
    )

    let decoded = try XPCDecoder.standard.decode(
      DataChildFixture.self,
      from: encoded
    )
    #expect(decoded.baseData == expected.baseData)
    #expect(decoded.baseNeighbor == expected.baseNeighbor)
    #expect(decoded.childNeighbor == expected.childNeighbor)
  }

  @Test
  func `historical byte-array Data shape is rejected`() throws {
    let historicalShape = historicalDataArray(
      dataFixture(byteCount: 16)
    )

    try requireHistoricalDataShapeRejection(
      decoding: Data.self,
      from: historicalShape,
      expectedCodingPath: []
    )

    let envelope = xpc_dictionary_create_empty()
    envelope.setValue(
      historicalShape,
      forKey: "value",
      strategy: .standard
    )
    try requireHistoricalDataShapeRejection(
      decoding: DataOnlyEnvelope.self,
      from: envelope,
      expectedCodingPath: ["value"]
    )
  }

}

// MARK: - Fixtures

private struct KeyedDataFixture: Codable, Equatable {
  let neighbor: Int
  let data: Data
}

private struct NestedDataFixture: Codable, Equatable {
  let sibling: String
  let inner: KeyedDataFixture
}

private struct GenericDataFixture<Value: Codable & Equatable>: Codable, Equatable {
  let value: Value
}

private struct OptionalDataFixture: Codable, Equatable {
  let value: Data?
}

private struct SingleValueDataFixture: Codable, Equatable {
  let value: Data

  init(value: Data) {
    self.value = value
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    value = try container.decode(Data.self)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(value)
  }
}

private struct DataOnlyEnvelope: Decodable {
  let value: Data
}

private class DataBaseFixture: Codable {
  let baseData: Data
  let baseNeighbor: Int

  init(
    baseData: Data,
    baseNeighbor: Int
  ) {
    self.baseData = baseData
    self.baseNeighbor = baseNeighbor
  }
}

private final class DataChildFixture: DataBaseFixture {
  let childNeighbor: String

  private enum CodingKeys: String, CodingKey {
    case childNeighbor
  }

  init(
    baseData: Data,
    baseNeighbor: Int,
    childNeighbor: String
  ) {
    self.childNeighbor = childNeighbor
    super.init(
      baseData: baseData,
      baseNeighbor: baseNeighbor
    )
  }

  required init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    childNeighbor = try container.decode(
      String.self,
      forKey: .childNeighbor
    )
    try super.init(from: container.superDecoder())
  }

  override func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(
      childNeighbor,
      forKey: .childNeighbor
    )
    try super.encode(to: container.superEncoder())
  }
}

// MARK: - Assertions

private func dataFixture(byteCount: Int) -> Data {
  Data((0..<byteCount).map { UInt8(truncatingIfNeeded: $0 &* 31) })
}

private func decodeDataInsideXPCObjectScope(
  _ expected: Data
) throws -> Data {
  let object = xpcData(expected)
  return try XPCDecoder.standard.decode(Data.self, from: object)
}

private func requireXPCData(
  _ object: xpc_object_t,
  equals expected: Data,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try #require(
    xpc_get_type(object) == XPC_TYPE_DATA,
    "Expected one XPC data object.",
    sourceLocation: sourceLocation
  )
  let byteCount = xpc_data_get_length(object)
  #expect(
    byteCount == expected.count,
    sourceLocation: sourceLocation
  )

  guard byteCount > 0 else {
    return
  }
  var actual = Data(repeating: 0, count: byteCount)
  let copiedByteCount = actual.withUnsafeMutableBytes { bytes in
    guard let baseAddress = bytes.baseAddress else {
      return 0
    }
    return xpc_data_get_bytes(
      object,
      baseAddress,
      0,
      bytes.count
    )
  }
  #expect(
    copiedByteCount == byteCount,
    sourceLocation: sourceLocation
  )
  #expect(
    actual == expected,
    sourceLocation: sourceLocation
  )
}

private func requireDictionaryValue(
  _ dictionary: xpc_object_t,
  key: String,
  sourceLocation: SourceLocation = #_sourceLocation
) throws -> xpc_object_t {
  try #require(
    xpc_get_type(dictionary) == XPC_TYPE_DICTIONARY,
    "Expected an XPC dictionary.",
    sourceLocation: sourceLocation
  )
  return try #require(
    xpc_dictionary_get_value(dictionary, key),
    "Expected dictionary value for key `\(key)`.",
    sourceLocation: sourceLocation
  )
}

private func xpcObjectCount(_ object: xpc_object_t) -> Int {
  switch xpc_get_type(object) {
  case XPC_TYPE_ARRAY:
    var result = 1
    for index in 0..<xpc_array_get_count(object) {
      result += xpcObjectCount(xpc_array_get_value(object, index))
    }
    return result
  case XPC_TYPE_DICTIONARY:
    var result = 1
    xpc_dictionary_apply(object) { _, child in
      result += xpcObjectCount(child)
      return true
    }
    return result
  default:
    return 1
  }
}

private func historicalDataArray(
  _ data: Data
) -> xpc_object_t {
  let result = xpc_array_create_empty()
  for byte in data {
    xpc_array_append_value(
      result,
      xpcData(Data([byte]))
    )
  }
  return result
}

private func requireHistoricalDataShapeRejection<Value: Decodable>(
  decoding type: Value.Type,
  from object: xpc_object_t,
  expectedCodingPath: [String],
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  do {
    _ = try XPCDecoder.standard.decode(type, from: object)
    Issue.record(
      "Expected the historical Data byte-array shape to be rejected.",
      sourceLocation: sourceLocation
    )
  } catch DecodingError.typeMismatch(let decodedType, let context) {
    #expect(
      decodedType is Data.Type,
      sourceLocation: sourceLocation
    )
    #expect(
      context.codingPath.map(\.stringValue) == expectedCodingPath,
      sourceLocation: sourceLocation
    )
    #expect(
      context.debugDescription.contains(
        "Historical unkeyed byte-array representations are not supported."
      ),
      sourceLocation: sourceLocation
    )
  } catch {
    Issue.record(
      "Expected DecodingError.typeMismatch, received \(error).",
      sourceLocation: sourceLocation
    )
  }
}
