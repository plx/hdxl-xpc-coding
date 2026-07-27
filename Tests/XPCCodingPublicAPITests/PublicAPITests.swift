import Foundation
import Testing
import XPCCoding

@Suite("Black-box Public API")
struct PublicAPITests {

  @Test
  func `standard default forms compile and use one safe configuration`() throws {
    let encoderKeyStrategy: XPCEncoder.StringKeyStrategy = .standard
    let encoderValueStrategy: XPCEncoder.StringValueStrategy = .standard
    let decoderKeyStrategy: XPCDecoder.StringKeyStrategy = .standard
    let decoderValueStrategy: XPCDecoder.StringValueStrategy = .standard
    let codecKeyStrategy: XPCCodec.StringKeyStrategy = .standard
    let codecValueStrategy: XPCCodec.StringValueStrategy = .standard

    let configuration = XPCCodec.Configuration()
    let standardConfiguration: XPCCodec.Configuration = .standard
    let defaultedKeyConfiguration = XPCCodec.Configuration(
      stringValueStrategy: .standard
    )
    let defaultedValueConfiguration = XPCCodec.Configuration(
      stringKeyStrategy: .standard
    )
    let codec = XPCCodec()
    let explicitlyStandardCodec = XPCCodec(configuration: .standard)
    let standardCodec = XPCCodec.standard
    let encoder = XPCEncoder()
    let standardEncoder = XPCEncoder.standard
    let decoder = XPCDecoder()
    let standardDecoder = XPCDecoder.standard

    let expectedConfiguration = XPCCodec.Configuration(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    #expect(encoderKeyStrategy == .percentEscape)
    #expect(encoderValueStrategy == .percentEscape)
    #expect(decoderKeyStrategy == .percentEscape)
    #expect(decoderValueStrategy == .percentEscape)
    #expect(codecKeyStrategy == .percentEscape)
    #expect(codecValueStrategy == .percentEscape)
    #expect(configuration == expectedConfiguration)
    #expect(standardConfiguration == expectedConfiguration)
    #expect(defaultedKeyConfiguration == expectedConfiguration)
    #expect(defaultedValueConfiguration == expectedConfiguration)
    #expect(codec.configuration == expectedConfiguration)
    #expect(explicitlyStandardCodec.configuration == expectedConfiguration)
    #expect(standardCodec.configuration == expectedConfiguration)
    #expect(encoder.stringKeyStrategy == .percentEscape)
    #expect(encoder.stringValueStrategy == .percentEscape)
    #expect(standardEncoder.stringKeyStrategy == .percentEscape)
    #expect(standardEncoder.stringValueStrategy == .percentEscape)
    #expect(decoder.stringKeyStrategy == .percentEscape)
    #expect(decoder.stringValueStrategy == .percentEscape)
    #expect(standardDecoder.stringKeyStrategy == .percentEscape)
    #expect(standardDecoder.stringValueStrategy == .percentEscape)

    let value = ["key\u{0}%": "value\u{0}%"]
    for defaultCodec in [codec, explicitlyStandardCodec, standardCodec] {
      let encoded = try defaultCodec.encode(value)
      #expect(
        try defaultCodec.decode([String: String].self, from: encoded) == value
      )
    }

    for (defaultEncoder, defaultDecoder) in [
      (encoder, decoder),
      (standardEncoder, standardDecoder),
    ] {
      let encoded = try defaultEncoder.encode(value)
      #expect(
        try defaultDecoder.decode([String: String].self, from: encoded) == value
      )
    }
  }

  @Test
  func `documented facades compile and round-trip from a plain import`() throws {
    let message = PublicMessage(
      identifier: 29,
      metadata: ["route\u{0}%": "same-host\u{0}%"]
    )

    // XPCEncoder and XPCDecoder API documentation examples.
    let documentedEncoder = XPCEncoder()
    let documentedDecoder = XPCDecoder()
    let documentedObject = try documentedEncoder.encode(message)
    #expect(
      try documentedDecoder.decode(PublicMessage.self, from: documentedObject) == message
    )

    // XPCCodec API documentation example, with concrete example values.
    let configuration = XPCCodec.Configuration(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    let codec = XPCCodec(configuration: configuration)
    let encoded = try codec.encode(message)
    let decoded = try codec.decode(PublicMessage.self, from: encoded)
    #expect(decoded == message)

    #expect(codec.configuration == configuration)
    #expect(codec.stringKeyStrategy == .percentEscape)
    #expect(codec.stringValueStrategy == .percentEscape)
  }

  @Test
  func `immutable codec is shareable from a plain import`() async throws {
    let codec = XPCCodec(
      configuration: .init(
        stringKeyStrategy: .percentEscape,
        stringValueStrategy: .percentEscape
      )
    )
    requireSendable(codec)

    try await withThrowingTaskGroup(of: Bool.self) { group in
      for identifier in 0..<64 {
        group.addTask {
          let message = PublicMessage(
            identifier: identifier,
            metadata: ["route\u{0}%": "same-host\u{0}%\(identifier)"]
          )
          let object = try codec.encode(message)
          return try codec.decode(PublicMessage.self, from: object) == message
        }
      }

      for try await succeeded in group {
        #expect(succeeded)
      }
    }
  }

  @Test
  func `explicit public strategies configure compatible facades`() throws {
    let encoder = XPCEncoder(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    let decoder = XPCDecoder(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape,
      resourceLimits: .standard
    )
    let value = ["key\u{0}%": "value\u{0}%"]

    #expect(
      try decoder.decode(
        [String: String].self,
        from: encoder.encode(value)
      ) == value
    )
    #expect(encoder.stringKeyStrategy == .percentEscape)
    #expect(encoder.stringValueStrategy == .percentEscape)
    #expect(decoder.stringKeyStrategy == .percentEscape)
    #expect(decoder.stringValueStrategy == .percentEscape)
    #expect(decoder.resourceLimits == .standard)

    let codec = XPCCodec(
      configuration: .init(
        stringKeyStrategy: .assumeAbsent,
        stringValueStrategy: .assumeAbsent
      )
    )
    let factoryEncoder = codec.makeEncoder()
    let factoryDecoder = codec.makeDecoder()
    #expect(factoryEncoder.stringKeyStrategy == .assumeAbsent)
    #expect(factoryEncoder.stringValueStrategy == .assumeAbsent)
    #expect(factoryDecoder.stringKeyStrategy == .passthrough)
    #expect(factoryDecoder.stringValueStrategy == .passthrough)
  }

  @Test
  func `transient encoding exposes its public result and error paths`() throws {
    let configuration = XPCCodec.Configuration(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    let encoder = XPCEncoder(configuration: configuration)
    let decoder = XPCDecoder(configuration: configuration)

    let object = try encoder.withTransientEncoder {
      var container = $0.singleValueContainer()
      try container.encode(29)
    }
    #expect(try decoder.decode(Int.self, from: object) == 29)

    do {
      _ = try encoder.withTransientEncoder { _ in }
      Issue.record("Expected a TransientEncoderError.")
    } catch TransientEncoderError.noEncodingOccurred {
      // This exact public case is the expected result.
    }
  }

  @Test
  func `encoding errors keep their documented public contract`() {
    let sentinel = PublicUserEncodingError()

    do {
      _ = try XPCEncoder.standard.encode(
        [PublicThrowingEncodingLeaf(error: sentinel)]
      )
      Issue.record("Expected the user encoding error.")
    } catch {
      #expect((error as? PublicUserEncodingError) === sentinel)
    }

    let value = "embedded\u{0}null"
    let encoder = XPCEncoder(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .throwOnDiscovery
    )
    do {
      _ = try encoder.encode(value)
      Issue.record("Expected EncodingError.invalidValue.")
    } catch let EncodingError.invalidValue(invalidValue, context) {
      #expect(invalidValue as? String == value)
      #expect(context.codingPath.isEmpty)
      #expect(context.underlyingError != nil)
    } catch {
      Issue.record(
        "Expected EncodingError.invalidValue, received \(String(reflecting: error))."
      )
    }
  }

  @Test
  func `decoding errors keep their documented public taxonomy`() throws {
    let encoder = XPCEncoder.standard
    let decoder = XPCDecoder.standard
    let absentInt: Int? = nil

    do {
      _ = try decoder.decode(
        Int.self,
        from: encoder.encode(absentInt)
      )
      Issue.record("Expected DecodingError.valueNotFound.")
    } catch let DecodingError.valueNotFound(type, context) {
      #expect(ObjectIdentifier(type) == ObjectIdentifier(Int.self))
      #expect(context.codingPath.isEmpty)
    } catch {
      Issue.record(
        "Expected valueNotFound, received \(String(reflecting: error))."
      )
    }

    do {
      _ = try decoder.decode(
        String.self,
        from: encoder.encode(17)
      )
      Issue.record("Expected DecodingError.typeMismatch.")
    } catch let DecodingError.typeMismatch(type, context) {
      #expect(ObjectIdentifier(type) == ObjectIdentifier(String.self))
      #expect(context.codingPath.isEmpty)
    } catch {
      Issue.record(
        "Expected typeMismatch, received \(String(reflecting: error))."
      )
    }

    do {
      _ = try decoder.decode(
        PublicKeyedContainerProbe.self,
        from: encoder.encode([17])
      )
      Issue.record("Expected a keyed-container typeMismatch.")
    } catch let DecodingError.typeMismatch(type, context) {
      #expect(
        ObjectIdentifier(type)
          == ObjectIdentifier([String: Any].self)
      )
      #expect(context.codingPath.isEmpty)
    } catch {
      Issue.record(
        "Expected keyed typeMismatch, received \(String(reflecting: error))."
      )
    }

    do {
      _ = try decoder.decode(
        PublicUnkeyedContainerProbe.self,
        from: encoder.encode(["value": 17])
      )
      Issue.record("Expected an unkeyed-container typeMismatch.")
    } catch let DecodingError.typeMismatch(type, context) {
      #expect(ObjectIdentifier(type) == ObjectIdentifier([Any].self))
      #expect(context.codingPath.isEmpty)
    } catch {
      Issue.record(
        "Expected unkeyed typeMismatch, received \(String(reflecting: error))."
      )
    }

    do {
      _ = try decoder.decode(
        PublicMissingValueProbe.self,
        from: encoder.encode([String: Int]())
      )
      Issue.record("Expected DecodingError.keyNotFound.")
    } catch let DecodingError.keyNotFound(key, context) {
      #expect(key.stringValue == "value")
      #expect(context.codingPath.isEmpty)
    } catch {
      Issue.record(
        "Expected keyNotFound, received \(String(reflecting: error))."
      )
    }

    let limits = XPCDecoder.ResourceLimits(
      maximumNestingDepth: 128,
      maximumContainerElementCount: 65_536,
      maximumTotalNodeCount: 262_144,
      maximumStringByteCount: 0,
      maximumDataByteCount: 32 * 1_024 * 1_024,
      maximumCumulativeByteCount: 64 * 1_024 * 1_024
    )
    do {
      _ = try XPCDecoder(
        resourceLimits: limits
      ).decode(
        String.self,
        from: encoder.encode("x")
      )
      Issue.record("Expected DecodingError.dataCorrupted.")
    } catch let DecodingError.dataCorrupted(context) {
      #expect(context.codingPath.isEmpty)
    } catch {
      Issue.record(
        "Expected dataCorrupted, received \(String(reflecting: error))."
      )
    }
  }

  @Test
  func `enhanced protocols and helpers are usable across the module boundary`() throws {
    let encoder = XPCEncoder(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    let decoder = XPCDecoder(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    let bytes: [UInt8] = [0, 1, 2, 3, 5, 8, 13, 255]

    let singleValueObject = try encoder.encode(
      PublicSingleValueBinaryPayload(bytes: bytes)
    )
    #expect(
      try decoder.decode(Data.self, from: singleValueObject) == Data(bytes)
    )

    let unkeyedObject = try encoder.encode(
      PublicUnkeyedBinaryPayload(bytes: bytes)
    )
    #expect(
      try decoder.decode([Data].self, from: unkeyedObject) == [Data(bytes)]
    )

    let keyedObject = try encoder.encode(
      PublicKeyedHelperPayload(bytes: bytes, elements: [3, 1, 4, 1, 5])
    )
    #expect(
      try decoder.decode(PublicKeyedHelperValue.self, from: keyedObject)
        == PublicKeyedHelperValue(
          bytes: Data(bytes),
          elements: [3, 1, 4, 1, 5]
        )
    )
  }

  @Test
  func `public descriptions report facade and limit types`() {
    let configuration = XPCCodec.Configuration(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    let encoder = XPCEncoder(configuration: configuration)
    let decoder = XPCDecoder(configuration: configuration)
    let limits = XPCDecoder.ResourceLimits.standard

    #expect(encoder.description.contains("string-keys"))
    #expect(encoder.debugDescription.contains("XPCEncoder"))
    #expect(decoder.description.contains("resource-limits"))
    #expect(decoder.debugDescription.contains("XPCDecoder"))
    #expect(limits.description.contains("depth"))
    #expect(limits.debugDescription.contains("XPCDecoder.ResourceLimits"))
    #expect(XPCCodec.StringKeyStrategy.percentEscape.description == "%-escape")
    #expect(XPCCodec.StringValueStrategy.percentEscape.debugDescription == ".percentEscape")
  }

}

private struct PublicMessage: Codable, Equatable {
  let identifier: Int
  let metadata: [String: String]
}

private func requireSendable<T: Sendable>(_: T) {}

private final class PublicUserEncodingError: Error, Sendable {}

private struct PublicThrowingEncodingLeaf: Encodable {
  let error: PublicUserEncodingError

  func encode(to encoder: any Encoder) throws {
    _ = encoder
    throw error
  }
}

private enum PublicDecodingKey: String, CodingKey {
  case value
}

private struct PublicKeyedContainerProbe: Decodable {

  init(from decoder: any Decoder) throws {
    _ = try decoder.container(keyedBy: PublicDecodingKey.self)
  }

}

private struct PublicUnkeyedContainerProbe: Decodable {

  init(from decoder: any Decoder) throws {
    _ = try decoder.unkeyedContainer()
  }

}

private struct PublicMissingValueProbe: Decodable {
  let value: Int
}

private enum PublicEnhancedEncodingError: Error {
  case missingSingleValueEnhancement
  case missingUnkeyedEnhancement
}

private struct PublicSingleValueBinaryPayload: Encodable {
  let bytes: [UInt8]

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    guard container is any XPCEnhancedSingleValueEncodingContainer else {
      throw PublicEnhancedEncodingError.missingSingleValueEnhancement
    }
    try bytes.withUnsafeBytes {
      try container.efficientlyEncodeBinaryData($0)
    }
  }
}

private struct PublicUnkeyedBinaryPayload: Encodable {
  let bytes: [UInt8]

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    guard container is any XPCEnhancedUnkeyedEncodingContainer else {
      throw PublicEnhancedEncodingError.missingUnkeyedEnhancement
    }
    try bytes.withUnsafeBytes {
      try container.efficientlyEncodeBinaryData($0)
    }
  }
}

private struct PublicKeyedHelperPayload: Encodable {
  let bytes: [UInt8]
  let elements: [Int]

  private enum CodingKeys: String, CodingKey {
    case bytes
    case elements
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try bytes.withUnsafeBytes {
      try container.efficientlyEncodeBinaryData($0, forKey: .bytes)
    }
    try elements.withUnsafeBufferPointer {
      try container.efficientlyEncodeElements($0, forKey: .elements)
    }
  }
}

private struct PublicKeyedHelperValue: Decodable, Equatable {
  let bytes: Data
  let elements: [Int]
}
