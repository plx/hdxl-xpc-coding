import Foundation
import Testing
import XPC
@testable import XPCCoding

@Suite("Percent-Escape Regression Tests")
struct PercentEscapeRegressionTests {

  @Test
  func `encoding uses the canonical percent-escape grammar`() throws {
    let expectedRepresentations = [
      "plain": "plain",
      "%": "%25",
      "%00": "%2500",
      "%25": "%2525",
      "\0": "%00",
      "a\0%b": "a%00%25b",
      "%\u{301}": "%25\u{301}",
      "%\u{FE0F}": "%25\u{FE0F}",
    ]
    let encoder = percentEscapeEncoder()

    for (source, expectedRepresentation) in expectedRepresentations {
      let encodedValue = try encoder.encode(source)
      #expect(rawXPCString(encodedValue) == expectedRepresentation)
      #expect(percentEscapedKeyRepresentation(source) == expectedRepresentation)
    }
  }

  @Test
  func `values round-trip through every container shape`() throws {
    let probes = [
      "",
      "plain",
      "%",
      "%0",
      "%00",
      "%25",
      "%41",
      "%GG",
      "100%",
      "a%20b",
      "a%00b",
      "a\0b",
      "%\u{301}",
      "x%\u{301}41",
      "%\u{FE0F}",
      "\0leading",
      "trailing\0",
      "\0repeated\0",
      "é",
      "e\u{301}",
      "🚀",
    ]
    let codec = percentEscapeCodec()

    for probe in probes {
      try expectScalarExactRoundTrip(probe, as: String.self, using: codec)
      try expectScalarExactRoundTrip(
        KeyedValueWrapper(probe),
        as: KeyedValueWrapper<String>.self,
        using: codec
      )
      try expectScalarExactRoundTrip(
        UnkeyedValueWrapper(probe),
        as: UnkeyedValueWrapper<String>.self,
        using: codec
      )
      try expectScalarExactRoundTrip(
        ExplicitPercentEscapeNesting(keyedValue: probe, unkeyedValue: probe),
        as: ExplicitPercentEscapeNesting.self,
        using: codec
      )
    }
  }

  @Test
  func `dictionary keys remain distinct and support all keyed operations`() throws {
    let source = [
      "\0": 1,
      "%00": 2,
      "%": 3,
      "%25": 4,
      "%41": 5,
      "x%\u{301}41": 6,
    ]
    let codec = percentEscapeCodec()
    let encoded = try codec.encode(source)

    #expect(xpc_get_type(encoded) == XPC_TYPE_DICTIONARY)
    #expect(xpc_dictionary_get_count(encoded) == source.count)

    let inspection = try codec.decode(PercentEscapeKeyInspection.self, from: encoded)
    #expect(inspection.allKeys == Set(source.keys))
    #expect(inspection.containedKeys == Set(source.keys))
    #expect(inspection.values == source)

    let decoded = try codec.decode([String: Int].self, from: encoded)
    #expect(decoded == source)
  }

  @Test
  func `unsupported percent escapes throw data-corrupted at the complete path`() throws {
    let decoder = percentEscapeDecoder()

    for malformedRepresentation in ["%", "%0", "%GG", "%41"] {
      let encoded = nestedXPCString(malformedRepresentation)
      let error: DecodingError
      do {
        _ = try decoder.decode(NestedPercentEscapeValue.self, from: encoded)
        throw PercentEscapeRegressionTestError.expectedDecodingFailure(
          malformedRepresentation
        )
      } catch let decodingError as DecodingError {
        error = decodingError
      }

      guard case .dataCorrupted = error else {
        throw PercentEscapeRegressionTestError.unexpectedDecodingError(
          String(reflecting: error)
        )
      }
      try verifyCodingPath(of: error, matches: ["outer", "value"])
    }
  }

  @Test
  func `deterministic generated strings round-trip and encode injectively`() throws {
    let codec = percentEscapeCodec()
    var inputScalarsByEncodedKeyBytes: [[UInt8]: [UInt32]] = [:]

    for input in deterministicPercentEscapeCorpus(count: 1_024) {
      let inputScalars = input.unicodeScalars.map(\.value)
      let encodedKey = percentEscapedKeyRepresentation(input)
      let encodedKeyBytes = Array(encodedKey.utf8)
      let previousInputScalars = inputScalarsByEncodedKeyBytes[encodedKeyBytes]

      #expect(
        previousInputScalars == nil || previousInputScalars == inputScalars,
        "Distinct strings encoded as the same XPC dictionary key: \(String(reflecting: encodedKey))"
      )
      inputScalarsByEncodedKeyBytes[encodedKeyBytes] = inputScalars

      let encodedValue = try codec.encode(input)
      let decodedValue = try codec.decode(String.self, from: encodedValue)
      #expect(decodedValue.unicodeScalars.map(\.value) == inputScalars)
    }
  }
}

private struct ExplicitPercentEscapeNesting: Codable {
  let keyedValue: String
  let unkeyedValue: String

  enum CodingKeys: String, CodingKey {
    case nestedKeyed
    case nestedUnkeyed
  }

  enum NestedCodingKeys: String, CodingKey {
    case value
  }

  init(keyedValue: String, unkeyedValue: String) {
    self.keyedValue = keyedValue
    self.unkeyedValue = unkeyedValue
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let keyedContainer = try container.nestedContainer(
      keyedBy: NestedCodingKeys.self,
      forKey: .nestedKeyed
    )
    var unkeyedContainer = try container.nestedUnkeyedContainer(
      forKey: .nestedUnkeyed
    )
    self.init(
      keyedValue: try keyedContainer.decode(String.self, forKey: .value),
      unkeyedValue: try unkeyedContainer.decode(String.self)
    )
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    var keyedContainer = container.nestedContainer(
      keyedBy: NestedCodingKeys.self,
      forKey: .nestedKeyed
    )
    var unkeyedContainer = container.nestedUnkeyedContainer(
      forKey: .nestedUnkeyed
    )
    try keyedContainer.encode(keyedValue, forKey: .value)
    try unkeyedContainer.encode(unkeyedValue)
  }
}

private struct PercentEscapeKeyInspection: Decodable {
  let allKeys: Set<String>
  let containedKeys: Set<String>
  let values: [String: Int]

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: PercentEscapeCodingKey.self)
    let keys = container.allKeys
    self.allKeys = Set(keys.map(\.stringValue))
    self.containedKeys = Set(
      keys.lazy
        .filter { container.contains($0) }
        .map(\.stringValue)
    )
    self.values = Dictionary(
      uniqueKeysWithValues: try keys.map { key in
        (key.stringValue, try container.decode(Int.self, forKey: key))
      }
    )
  }
}

private struct NestedPercentEscapeValue: Decodable {
  let value: String

  enum CodingKeys: String, CodingKey {
    case outer
  }

  enum NestedCodingKeys: String, CodingKey {
    case value
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let nestedContainer = try container.nestedContainer(
      keyedBy: NestedCodingKeys.self,
      forKey: .outer
    )
    self.value = try nestedContainer.decode(String.self, forKey: .value)
  }
}

private struct PercentEscapeCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

private enum PercentEscapeRegressionTestError: Error {
  case expectedDecodingFailure(String)
  case unexpectedDecodingError(String)
}

private func percentEscapeCodec() -> XPCCodec {
  XPCCodec(
    configuration: XPCCodec.Configuration(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
  )
}

private func percentEscapeEncoder() -> XPCEncoder {
  XPCEncoder(
    stringKeyStrategy: .percentEscape,
    stringValueStrategy: .percentEscape
  )
}

private func percentEscapeDecoder() -> XPCDecoder {
  XPCDecoder(
    stringKeyStrategy: .percentEscape,
    stringValueStrategy: .percentEscape
  )
}

private func rawXPCString(_ object: xpc_object_t) -> String? {
  xpc_string_get_string_ptr(object).map {
    String(cString: $0)
  }
}

private func percentEscapedKeyRepresentation(_ string: String) -> String {
  string.withUTF8CString(
    stringKeyStrategy: XPCEncoder.StringKeyStrategy.percentEscape
  ) {
    String(cString: $0)
  }
}

private func nestedXPCString(_ rawString: String) -> xpc_object_t {
  let outerDictionary = xpc_dictionary_create(nil, nil, 0)
  let innerDictionary = xpc_dictionary_create(nil, nil, 0)
  let stringObject = rawString.withCString(xpc_string_create)
  xpc_dictionary_set_value(innerDictionary, "value", stringObject)
  xpc_dictionary_set_value(outerDictionary, "outer", innerDictionary)
  return outerDictionary
}

private func expectScalarExactRoundTrip<Value: Codable>(
  _ value: Value,
  as valueType: Value.Type,
  using codec: XPCCodec
) throws {
  let encoded = try codec.encode(value)
  let decoded = try codec.decode(valueType, from: encoded)
  #expect(percentEscapeScalarSignature(decoded) == percentEscapeScalarSignature(value))
}

private func percentEscapeScalarSignature<Value>(_ value: Value) -> [[UInt32]] {
  switch value {
  case let string as String:
    [string.unicodeScalars.map(\.value)]
  case let value as KeyedValueWrapper<String>:
    [value.value.unicodeScalars.map(\.value)]
  case let value as UnkeyedValueWrapper<String>:
    [value.value.unicodeScalars.map(\.value)]
  case let value as ExplicitPercentEscapeNesting:
    [
      value.keyedValue.unicodeScalars.map(\.value),
      value.unkeyedValue.unicodeScalars.map(\.value),
    ]
  default:
    []
  }
}

private struct PercentEscapeSeededGenerator: RandomNumberGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
    return state
  }
}

private func deterministicPercentEscapeCorpus(count: Int) -> [String] {
  precondition(count >= 16)

  var corpus = [
    "",
    "%",
    "%0",
    "%00",
    "%25",
    "%41",
    "%GG",
    "\0",
    "a\0%b",
    "%\u{301}",
    "%\u{FE0F}",
    "é",
    "e\u{301}",
    "水",
    "🚀",
    "\0%\0%",
  ]
  var scalarSignatures = Set(corpus.map { $0.unicodeScalars.map(\.value) })
  var generator = PercentEscapeSeededGenerator(state: 0x7e57_c0de_0000_0007)
  let specialScalars: [UnicodeScalar] = [
    "\0",
    "%",
    "\u{301}",
    "\u{FE0F}",
    "é",
    "水",
    "🚀",
  ]

  while corpus.count < count {
    let length = Int(generator.next() % 17)
    var candidate = ""
    candidate.reserveCapacity(length)

    for _ in 0..<length {
      let selection = generator.next() % 12
      let scalar: UnicodeScalar
      if selection < UInt64(specialScalars.count) {
        scalar = specialScalars[Int(selection)]
      } else {
        scalar = UnicodeScalar(
          UInt8(0x20 + generator.next() % UInt64(0x5f))
        )
      }
      candidate.unicodeScalars.append(scalar)
    }

    let signature = candidate.unicodeScalars.map(\.value)
    if scalarSignatures.insert(signature).inserted {
      corpus.append(candidate)
    }
  }

  return corpus
}
