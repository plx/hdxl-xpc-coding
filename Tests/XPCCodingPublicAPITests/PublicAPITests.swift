import Foundation
import Testing
import XPCCoding

@Suite("Black-box Public API")
struct PublicAPITests {

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
