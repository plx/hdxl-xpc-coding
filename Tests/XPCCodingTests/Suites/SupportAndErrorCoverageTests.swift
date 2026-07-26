import Foundation
import Testing
import XPC
@testable import XPCCoding

// MARK: - Support And Error Coverage Tests

@Suite("Support And Error Coverage")
struct SupportAndErrorCoverageTests {

  @Test
  func `manual strategy diagnostics cover every case`() throws {
    // The strategy enums are part of the public facade surface. This pins down
    // their exhaustive case lists plus the human-readable and debug forms used
    // by the facade descriptions.
    #expect(XPCEncoder.StringKeyStrategy.allCases == [.assumeAbsent, .percentEscape])
    #expect(XPCDecoder.StringKeyStrategy.allCases == [.passthrough, .percentEscape])

    for strategy in XPCEncoder.StringKeyStrategy.allCases {
      #expect(!strategy.description.isEmpty)
      #expect(strategy.debugDescription.contains("\(type(of: strategy))"))
    }
    for strategy in XPCDecoder.StringKeyStrategy.allCases {
      #expect(!strategy.description.isEmpty)
      #expect(strategy.debugDescription.contains("\(type(of: strategy))"))
    }
    for strategy in XPCEncoder.StringValueStrategy.allCases {
      #expect(!strategy.description.isEmpty)
      #expect(strategy.debugDescription.contains("\(type(of: strategy))"))
    }
    for strategy in XPCDecoder.StringValueStrategy.allCases {
      #expect(!strategy.description.isEmpty)
      #expect(strategy.debugDescription.contains("\(type(of: strategy))"))
    }
  }

  @Test
  func `generated strategy diagnostics cover every case`() throws {
    for probe in generatedStrategyProbes(count: 48) {
      #expect(!probe.encoderKey.description.isEmpty)
      #expect(probe.encoderKey.debugDescription.contains("\(type(of: probe.encoderKey))"))
      #expect(!probe.decoderKey.description.isEmpty)
      #expect(probe.decoderKey.debugDescription.contains("\(type(of: probe.decoderKey))"))
      #expect(!probe.encoderValue.description.isEmpty)
      #expect(probe.encoderValue.debugDescription.contains("\(type(of: probe.encoderValue))"))
      #expect(!probe.decoderValue.description.isEmpty)
      #expect(probe.decoderValue.debugDescription.contains("\(type(of: probe.decoderValue))"))
    }
  }

  @Test
  func `manual support helpers preserve key and data representations`() throws {
    // These helpers sit underneath the containers. Calling them directly covers
    // overloads that are otherwise easy for Swift's overload resolution to skip
    // in synthesized Codable paths.
    let lossyKey = SupportCoverageKey(stringValue: "a\0b")!
    let xpcCodingKey = try #require(XPCCodingKey(stringValue: "manual"))
    #expect(!"a\0b".isLosslesslyRepresentableAsXPCStringObject)
    #expect(!lossyKey.isLosslesslyRepresentableAsXPCStringObject)
    #expect(xpcCodingKey.stringValue == "manual")
    #expect(xpcCodingKey.intValue == nil)

    let escapedCString = lossyKey.withUTF8CString(stringKeyStrategy: XPCEncoder.StringKeyStrategy.percentEscape) {
      String(cString: $0)
    }
    #expect(escapedCString == "a%00b")

    let keyObject = "key\0value".makeXPCObjectRepresentation(stringKeyStrategy: .percentEscape)
    #expect(try keyObject._extractStringValue(stringValueStrategy: .percentEscape) == "key\0value")

    let percentEscaped = "100%\0done".addingXPCCodingPercentEscapes()
    #expect(percentEscaped == "100%25%00done")

    let dictionary = xpc_dictionary_create(nil, nil, 0)
    dictionary.setNil(forKey: lossyKey, strategy: .percentEscape)
    setNilWithConcreteKey(dictionary, key: SupportCoverageKey("concreteNil"))

    let anyKey: any CodingKey = SupportCoverageKey.value
    dictionary.setValue(Int64(42), forKey: anyKey, strategy: .percentEscape)
    dictionary.setValue(UInt16(7), forKey: "number", strategy: .percentEscape)
    dictionary.setValue(xpc_bool_create(true), forKey: SupportCoverageKey.flag, strategy: .percentEscape)
    setLosslessValueWithExistentialKey(dictionary, key: SupportCoverageKey("existential"), value: 99)
    setXPCObjectWithConcreteKey(dictionary, key: SupportCoverageKey("direct"), value: xpc_bool_create(false))

    #expect(dictionary.decodeNil(at: [], forKey: lossyKey, strategy: .percentEscape))
    #expect(dictionary.decodeNil(at: [], forKey: SupportCoverageKey("concreteNil"), strategy: .percentEscape))
    #expect(try dictionary.extractValue(ofType: Int64.self, at: [], forKey: anyKey, stringKeyStrategy: .percentEscape) == 42)
    #expect(try dictionary.extractValue(ofType: UInt16.self, at: [], forKey: SupportCoverageKey(stringValue: "number")!, stringKeyStrategy: .percentEscape) == 7)
    #expect(try dictionary.extractValue(ofType: Bool.self, at: [], forKey: SupportCoverageKey.flag, stringKeyStrategy: .percentEscape))
    #expect(try dictionary.extractValue(ofType: Int64.self, at: [], forKey: SupportCoverageKey("existential"), stringKeyStrategy: .percentEscape) == 99)
    #expect(try !dictionary.extractValue(ofType: Bool.self, at: [], forKey: SupportCoverageKey("direct"), stringKeyStrategy: .percentEscape))

    let array = xpc_array_create(nil, 0)
    array.appendValue(UInt8(9))
    #expect(xpc_array_get_count(array) == 1)

    let original: Int16 = -1234
    let representation = original.xpcBinaryDataRepresentation
    #expect(Int16(xpcBinaryDataRepresentation: representation) == original)
    #expect(Int16(xpcBinaryDataRepresentation: Data([0])) == nil)
    #expect(Int16(unsafeXPCBinaryDataRepresentationRawBufferPointer: UnsafeRawBufferPointer(start: nil, count: 0)) == nil)
  }

  @Test
  func `generated support helpers preserve key and data representations`() throws {
    for probe in generatedSupportProbes(count: 48) {
      let key = SupportCoverageKey(stringValue: probe.key)!
      let xpcCodingKey = try #require(XPCCodingKey(stringValue: probe.key))
      let escapedKey = key.withUTF8CString(stringKeyStrategy: XPCEncoder.StringKeyStrategy.percentEscape) {
        String(cString: $0)
      }
      let expectedEscapedKey = probe.key.addingXPCCodingPercentEscapes()
      #expect(escapedKey == expectedEscapedKey)
      #expect(key.isLosslesslyRepresentableAsXPCStringObject == !probe.key.containsNullBytes)
      #expect(xpcCodingKey.stringValue == probe.key)
      #expect(xpcCodingKey.intValue == nil)

      let keyObject = probe.key.makeXPCObjectRepresentation(stringKeyStrategy: .percentEscape)
      #expect(try keyObject._extractStringValue(stringValueStrategy: .percentEscape) == probe.key)

      let dictionary = xpc_dictionary_create(nil, nil, 0)
      dictionary.setValue(probe.value, forKey: key, strategy: .percentEscape)
      setNilWithConcreteKey(dictionary, key: SupportCoverageKey("\(probe.key)-nil"))
      setLosslessValueWithExistentialKey(
        dictionary,
        key: SupportCoverageKey("\(probe.key)-existential"),
        value: probe.value &+ 1
      )
      setXPCObjectWithConcreteKey(
        dictionary,
        key: SupportCoverageKey("\(probe.key)-direct"),
        value: xpc_int64_create(probe.value &+ 2)
      )
      #expect(
        try dictionary.extractValue(
          ofType: Int64.self,
          at: [],
          forKey: key,
          stringKeyStrategy: .percentEscape
        ) == probe.value
      )
      #expect(dictionary.decodeNil(at: [], forKey: SupportCoverageKey("\(probe.key)-nil"), strategy: .percentEscape))
      #expect(
        try dictionary.extractValue(
          ofType: Int64.self,
          at: [],
          forKey: SupportCoverageKey("\(probe.key)-existential"),
          stringKeyStrategy: .percentEscape
        ) == probe.value &+ 1
      )
      #expect(
        try dictionary.extractValue(
          ofType: Int64.self,
          at: [],
          forKey: SupportCoverageKey("\(probe.key)-direct"),
          stringKeyStrategy: .percentEscape
        ) == probe.value &+ 2
      )

      let representation = probe.short.xpcBinaryDataRepresentation
      #expect(Int16(xpcBinaryDataRepresentation: representation) == probe.short)
      #expect(Int16(xpcBinaryDataRepresentation: Data(repeating: 0, count: probe.invalidByteCount)) == nil)
    }
  }

  @Test
  func `manual compatibility error descriptions are redacted`() throws {
    // Compatibility errors intentionally report the explanation without echoing
    // the original incompatible string, so null-bearing user content does not
    // leak through diagnostics.
    let error = XPCObjectCompatibilityError.incompatibleStringContent("contains null bytes", "secret\0value")

    #expect(error.description == "contains null bytes")
    #expect(error.debugDescription == "contains null bytes")
  }

  @Test
  func `generated compatibility error descriptions are redacted`() throws {
    for probe in generatedSupportProbes(count: 32) {
      let error = XPCObjectCompatibilityError.incompatibleStringContent(probe.explanation, probe.key)

      #expect(error.description == probe.explanation)
      #expect(error.debugDescription == probe.explanation)
      #expect(!error.debugDescription.contains(probe.key))
    }
  }

  @Test
  func `manual malformed extraction reports decoding errors`() throws {
    // These calls target the lossy edge of decoding: wrong XPC type, missing
    // dictionary values, malformed percent escapes, invalid string bytes, and
    // extractable types that decline an otherwise correctly-typed object.
    #expect(throws: DecodingError.self) {
      try xpc_int64_create(1).extractStringValue(stringValueStrategy: .passthrough, at: [])
    }

    #expect(throws: XPCStringExtractionError.self) {
      try xpcString("bad%zz")._extractStringValue(stringValueStrategy: .percentEscape)
    }

    let invalidUTF8 = xpcData(Data([0xff]))
    #expect(throws: XPCStringExtractionError.self) {
      try invalidUTF8._extractStringValue(stringValueStrategy: .useDataRepresentation(.utf8))
    }
    #expect(throws: XPCStringExtractionError.self) {
      try xpc_bool_create(true)._extractStringValue(stringValueStrategy: .useDataRepresentation(.utf8))
    }

    #expect(throws: DecodingError.self) {
      try xpc_int64_create(5).extractValue(ofType: FailingExtractable.self, at: [])
    }
    #expect(Double.extracting(from: xpc_int64_create(1)) == nil)
    #expect(Int._extracting(from: xpc_double_create(1)) == nil)
    #expect(UInt._extracting(from: xpc_int64_create(1)) == nil)
    #expect(Int16._extracting(from: xpcData(Data([0]))) == nil)

    let array = xpc_array_create(nil, 0)
    #expect(throws: DecodingError.self) {
      try array.extractValue(
        ofType: Int.self,
        at: [],
        forKey: SupportCoverageKey.value,
        stringKeyStrategy: .percentEscape
      )
    }
    #expect(throws: DecodingError.self) {
      try array.extractString(
        at: [],
        forKey: SupportCoverageKey.value,
        stringKeyStrategy: .percentEscape,
        stringValueStrategy: .percentEscape
      )
    }

    let dictionary = xpc_dictionary_create(nil, nil, 0)
    #expect(throws: DecodingError.self) {
      try dictionary.extractString(
        at: [],
        forKey: SupportCoverageKey.value,
        stringKeyStrategy: .percentEscape,
        stringValueStrategy: .percentEscape
      )
    }

    dictionary.setValue(xpc_int64_create(1), forKey: SupportCoverageKey.value, strategy: .percentEscape)
    #expect(throws: DecodingError.self) {
      try dictionary.extractString(
        at: [],
        forKey: SupportCoverageKey.value,
        stringKeyStrategy: .percentEscape,
        stringValueStrategy: .percentEscape
      )
    }
  }

  @Test
  func `generated malformed extraction reports decoding errors`() throws {
    for probe in generatedSupportProbes(count: 32) {
      let key = SupportCoverageKey(stringValue: probe.key)!

      #expect(throws: DecodingError.self) {
        try xpc_bool_create(true).extractStringValue(stringValueStrategy: .passthrough, at: [key])
      }

      #expect(throws: XPCStringExtractionError.self) {
        try xpcString("bad-\(probe.explanation)-%xz")._extractStringValue(stringValueStrategy: .percentEscape)
      }

      #expect(throws: XPCStringExtractionError.self) {
        try xpcData(Data([0xff, UInt8(truncatingIfNeeded: probe.value)]))
          ._extractStringValue(stringValueStrategy: .useDataRepresentation(.utf8))
      }
      #expect(throws: XPCStringExtractionError.self) {
        try xpc_bool_create(probe.value.isMultiple(of: 2))
          ._extractStringValue(stringValueStrategy: .useDataRepresentation(.utf8))
      }

      #expect(throws: DecodingError.self) {
        try xpc_int64_create(probe.value).extractValue(ofType: FailingExtractable.self, at: [key])
      }
      #expect(Bool.extracting(from: xpc_int64_create(probe.value)) == nil)
      #expect(Int._extracting(from: xpc_double_create(Double(probe.value))) == nil)
      #expect(UInt._extracting(from: xpc_int64_create(probe.value)) == nil)
      #expect(UInt32._extracting(from: xpcData(Data([UInt8(truncatingIfNeeded: probe.value)]))) == nil)

      let dictionary = xpc_dictionary_create(nil, nil, 0)
      dictionary.setValue(xpc_double_create(Double(probe.value)), forKey: key, strategy: .percentEscape)
      #expect(throws: DecodingError.self) {
        try dictionary.extractString(
          at: [key],
          forKey: key,
          stringKeyStrategy: .percentEscape,
          stringValueStrategy: .passthrough
        )
      }
    }
  }

  @Test
  func `manual decoding containers report structural errors`() throws {
    // These checks exercise container-level validation directly. Synthesized
    // Codable paths usually fail earlier through dictionary extraction helpers,
    // so the container initializers and required-object lookup need explicit
    // coverage.
    let root = xpc_dictionary_create(nil, nil, 0)
    let decodingState = _XPCDecodingState(limits: .standard)
    try decodingState.prepareToVisit(atDepth: 0, codingPath: [])
    let decoder = _XPCDecoder(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape,
      decoding: root,
      decodingState: decodingState,
      depth: 0
    )

    #expect(throws: DecodingError.self) {
      _ = try XPCKeyedDecodingContainer<SupportCoverageKey>(
        referencing: decoder,
        wrapping: xpc_array_create(nil, 0),
        codingPath: [SupportCoverageKey.value]
      )
    }
    #expect(throws: DecodingError.self) {
      _ = try XPCUnkeyedDecodingContainer(
        referencing: decoder,
        wrapping: xpc_dictionary_create(nil, nil, 0),
        codingPath: [SupportCoverageKey.value]
      )
    }

    let dictionary = xpc_dictionary_create(nil, nil, 0)
    dictionary.setValue(Int64(7), forKey: "keep", strategy: .percentEscape)
    dictionary.setValue(Int64(8), forKey: "drop-this-key", strategy: .percentEscape)
    let keyed = try XPCKeyedDecodingContainer<RejectingCodingKey>(
      referencing: decoder,
      wrapping: dictionary,
      codingPath: []
    )
    #expect(keyed.allKeys == [RejectingCodingKey("keep")])
    #expect(throws: DecodingError.self) {
      try keyed.requiredXPCObject(for: SupportCoverageKey("missing"))
    }

    var unkeyed = try XPCUnkeyedDecodingContainer(
      referencing: decoder,
      wrapping: xpc_array_create(nil, 0),
      codingPath: []
    )
    #expect(throws: DecodingError.self) {
      try unkeyed.decodeNil()
    }

    #expect("bad%zz".withCString {
      String(cString: $0, embeddedNullByteRepresentation: .percentEscaped)
    } == nil)
  }

  @Test
  func `generated decoding containers report structural errors`() throws {
    for probe in generatedSupportProbes(count: 32) {
      let codingPathKey = SupportCoverageKey(stringValue: probe.key)!
      let root = xpc_dictionary_create(nil, nil, 0)
      let decodingState = _XPCDecodingState(limits: .standard)
      try decodingState.prepareToVisit(
        atDepth: 0,
        codingPath: [codingPathKey]
      )
      let decoder = _XPCDecoder(
        stringKeyStrategy: .percentEscape,
        stringValueStrategy: .percentEscape,
        decoding: root,
        at: [codingPathKey],
        decodingState: decodingState,
        depth: 0
      )

      #expect(throws: DecodingError.self) {
        _ = try XPCKeyedDecodingContainer<SupportCoverageKey>(
          referencing: decoder,
          wrapping: xpc_array_create(nil, 0),
          codingPath: [codingPathKey]
        )
      }
      #expect(throws: DecodingError.self) {
        _ = try XPCUnkeyedDecodingContainer(
          referencing: decoder,
          wrapping: xpc_dictionary_create(nil, nil, 0),
          codingPath: [codingPathKey]
        )
      }

      let acceptedKey = "keep-\(probe.explanation)"
      let rejectedKey = "drop-\(probe.explanation)"
      let dictionary = xpc_dictionary_create(nil, nil, 0)
      dictionary.setValue(probe.value, forKey: acceptedKey, strategy: .percentEscape)
      dictionary.setValue(probe.value &+ 1, forKey: rejectedKey, strategy: .percentEscape)
      let keyed = try XPCKeyedDecodingContainer<RejectingCodingKey>(
        referencing: decoder,
        wrapping: dictionary,
        codingPath: [codingPathKey]
      )
      #expect(keyed.allKeys == [RejectingCodingKey(acceptedKey)])
      #expect(throws: DecodingError.self) {
        try keyed.requiredXPCObject(for: SupportCoverageKey("missing-\(probe.explanation)"))
      }

      var unkeyed = try XPCUnkeyedDecodingContainer(
        referencing: decoder,
        wrapping: xpc_array_create(nil, 0),
        codingPath: [codingPathKey]
      )
      #expect(throws: DecodingError.self) {
        try unkeyed.decodeNil()
      }

      #expect("bad-\(probe.explanation)-%xz".withCString {
        String(cString: $0, embeddedNullByteRepresentation: .percentEscaped)
      } == nil)
    }
  }

  @Test
  func `manual encoding error paths report invalid values`() throws {
    // The container initializers and encode wrappers translate malformed
    // internal state and arbitrary Encodable failures into EncodingError values
    // at the boundary Swift's Encoder APIs expose.
    let encoder = _XPCEncoder(stringKeyStrategy: .standard, stringValueStrategy: .throwOnDiscovery)
    #expect(throws: EncodingError.self) {
      _ = try XPCKeyedEncodingContainer<SupportCoverageKey>(
        referencing: encoder,
        wrapping: xpc_array_create(nil, 0)
      )
    }
    #expect(throws: EncodingError.self) {
      _ = try XPCUnkeyedEncodingContainer(
        referencing: encoder,
        wrapping: xpc_dictionary_create(nil, nil, 0)
      )
    }

    var keyed = try XPCKeyedEncodingContainer<SupportCoverageKey>(
      referencing: encoder,
      wrapping: xpc_dictionary_create(nil, nil, 0)
    )
    #expect(keyed.codingPath.isEmpty)
    #expect(throws: EncodingError.self) {
      try keyed.encode(ThrowingEncodable(id: 1), forKey: .value)
    }
    #expect(throws: String.XPCObjectConversionError.self) {
      try keyed.encode("a\0b", forKey: .name)
    }

    var unkeyed = try XPCUnkeyedEncodingContainer(
      referencing: _XPCEncoder(stringKeyStrategy: .standard, stringValueStrategy: .throwOnDiscovery),
      wrapping: xpc_array_create(nil, 0)
    )
    #expect(unkeyed.codingPath.isEmpty)
    #expect(throws: EncodingError.self) {
      try unkeyed.encode("a\0b")
    }
    #expect(throws: EncodingError.self) {
      try unkeyed.encode(ThrowingEncodable(id: 2))
    }

    let referencing = _XPCArrayReferencingEncoder(
      stringKeyStrategy: .standard,
      stringValueStrategy: .standard,
      codingPath: [],
      index: 0,
      array: xpc_array_create(nil, 0)
    )
    var singleValue = referencing.singleValueContainer()
    #expect(throws: EncodingError.self) {
      try singleValue.encode(5)
    }
  }

  @Test
  func `generated encoding error paths report invalid values`() throws {
    for probe in generatedSupportProbes(count: 32) {
      let encoder = _XPCEncoder(
        stringKeyStrategy: .percentEscape,
        stringValueStrategy: .throwOnDiscovery,
        codingPath: [SupportCoverageKey(stringValue: probe.key)!]
      )

      var keyed = try XPCKeyedEncodingContainer<SupportCoverageKey>(
        referencing: encoder,
        wrapping: xpc_dictionary_create(nil, nil, 0)
      )
      #expect(keyed.codingPath.map(\.stringValue) == [probe.key])
      #expect(throws: EncodingError.self) {
        try keyed.encode(ThrowingEncodable(id: Int(probe.value)), forKey: .value)
      }
      #expect(throws: String.XPCObjectConversionError.self) {
        try keyed.encode("\(probe.key)\0", forKey: .name)
      }

      var unkeyed = try XPCUnkeyedEncodingContainer(
        referencing: encoder,
        wrapping: xpc_array_create(nil, 0)
      )
      #expect(unkeyed.codingPath.map(\.stringValue) == [probe.key])
      #expect(throws: EncodingError.self) {
        try unkeyed.encode("\(probe.key)\0")
      }
      #expect(throws: EncodingError.self) {
        try unkeyed.encode(ThrowingEncodable(id: Int(probe.value)))
      }

      let referencing = _XPCArrayReferencingEncoder(
        stringKeyStrategy: .percentEscape,
        stringValueStrategy: .percentEscape,
        codingPath: [SupportCoverageKey.value],
        index: Int(abs(probe.value % 4)),
        array: xpc_array_create(nil, 0)
      )
      var singleValue = referencing.singleValueContainer()
      #expect(throws: EncodingError.self) {
        try singleValue.encode(probe.value)
      }
    }
  }

}

// MARK: - Fixtures

private struct SupportCoverageKey: CodingKey, Hashable {
  static let flag = SupportCoverageKey("flag")
  static let name = SupportCoverageKey("name")
  static let value = SupportCoverageKey("value")

  let stringValue: String
  let intValue: Int?

  init(_ stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(stringValue: String) {
    self.init(stringValue)
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

private struct RejectingCodingKey: CodingKey, Hashable {
  let stringValue: String
  let intValue: Int?

  init(_ stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(stringValue: String) {
    guard !stringValue.hasPrefix("drop-") else {
      return nil
    }
    self.init(stringValue)
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

private struct FailingExtractable: XPCObjectExtractable {
  static var associatedXPCObjectType: xpc_type_t { XPC_TYPE_INT64 }

  static func _extracting(from object: xpc_object_t) -> FailingExtractable? {
    _ = object
    return nil
  }
}

private enum SupportCoverageThrownError: Error {
  case intentional(Int)
}

private struct ThrowingEncodable: Encodable {
  let id: Int

  func encode(to encoder: any Encoder) throws {
    _ = encoder
    throw SupportCoverageThrownError.intentional(id)
  }
}

private func setNilWithConcreteKey<Key: CodingKey>(
  _ dictionary: xpc_object_t,
  key: Key
) {
  dictionary.setNil(forKey: key, strategy: .percentEscape)
}

private func setLosslessValueWithExistentialKey(
  _ dictionary: xpc_object_t,
  key: any CodingKey,
  value: Int64
) {
  dictionary.setValue(value, forKey: key, strategy: .percentEscape)
}

private func setXPCObjectWithConcreteKey<Key: CodingKey>(
  _ dictionary: xpc_object_t,
  key: Key,
  value: xpc_object_t
) {
  dictionary.setValue(value, forKey: key, strategy: .percentEscape)
}

private struct StrategyProbe {
  let encoderKey: XPCEncoder.StringKeyStrategy
  let decoderKey: XPCDecoder.StringKeyStrategy
  let encoderValue: XPCEncoder.StringValueStrategy
  let decoderValue: XPCDecoder.StringValueStrategy
}

private struct SupportProbe {
  let key: String
  let value: Int64
  let short: Int16
  let invalidByteCount: Int
  let explanation: String
}

private struct SupportSeededGenerator: RandomNumberGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

private func generatedStrategyProbes(count: Int) -> [StrategyProbe] {
  var generator = SupportSeededGenerator(state: 0x5eed_5000_1111)
  return (0..<count).map { _ in
    let encoderKeys = XPCEncoder.StringKeyStrategy.allCases
    let decoderKeys = XPCDecoder.StringKeyStrategy.allCases
    let encoderValues = XPCEncoder.StringValueStrategy.allCases
    let decoderValues = XPCDecoder.StringValueStrategy.allCases

    return StrategyProbe(
      encoderKey: encoderKeys[Int(generator.next() % UInt64(encoderKeys.count))],
      decoderKey: decoderKeys[Int(generator.next() % UInt64(decoderKeys.count))],
      encoderValue: encoderValues[Int(generator.next() % UInt64(encoderValues.count))],
      decoderValue: decoderValues[Int(generator.next() % UInt64(decoderValues.count))]
    )
  }
}

private func generatedSupportProbes(count: Int) -> [SupportProbe] {
  var generator = SupportSeededGenerator(state: 0x5eed_5000_2222)
  return (0..<count).map { index in
    let prefix = generatedSupportFragment(using: &generator)
    let suffix = generatedSupportFragment(using: &generator)
    let key: String
    if index.isMultiple(of: 3) {
      key = "\(prefix)\0\(suffix)"
    } else if index.isMultiple(of: 3, remainder: 1) {
      key = "\(prefix)-\(suffix)"
    } else {
      key = "\(prefix)%\0\(suffix)"
    }

    let invalidByteCount = Int(generator.next() % 4)
    return SupportProbe(
      key: key,
      value: Int64(truncatingIfNeeded: generator.next()),
      short: Int16(truncatingIfNeeded: generator.next()),
      invalidByteCount: invalidByteCount == MemoryLayout<Int16>.size ? invalidByteCount + 1 : invalidByteCount,
      explanation: "generated incompatibility \(index)"
    )
  }
}

private func generatedSupportFragment(using generator: inout SupportSeededGenerator) -> String {
  let length = 2 + Int(generator.next() % 6)
  var result = ""
  result.reserveCapacity(length)
  for _ in 0..<length {
    let scalar = UInt8(ascii: "a") + UInt8(generator.next() % 26)
    result.append(Character(UnicodeScalar(scalar)))
  }
  return result
}

private extension Int {
  func isMultiple(of divisor: Int, remainder: Int) -> Bool {
    self % divisor == remainder
  }
}
