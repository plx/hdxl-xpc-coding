import Foundation
import XPCCoding

@main
struct XPCCodingPublicAPIConsumer {

  static func main() throws {
    let message = ConsumerMessage(
      identifier: 29,
      metadata: ["route\u{0}%": "same-host\u{0}%"]
    )

    // Compile and run the XPCEncoder and XPCDecoder API documentation examples.
    let documentedEncoder = XPCEncoder()
    let documentedDecoder = XPCDecoder()
    let documentedObject = try documentedEncoder.encode(message)
    guard
      try documentedDecoder.decode(
        ConsumerMessage.self,
        from: documentedObject
      ) == message
    else {
      throw ConsumerFailure.roundTripMismatch
    }

    // Compile and run the XPCCodec API documentation example with concrete values.
    let configuration = XPCCodec.Configuration(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    let codec = XPCCodec(configuration: configuration)
    let encoded = try codec.encode(message)
    guard try codec.decode(ConsumerMessage.self, from: encoded) == message else {
      throw ConsumerFailure.roundTripMismatch
    }

    try exerciseExplicitFacades(
      configuration: configuration,
      message: message
    )
    try exerciseTransientEncoder(configuration: configuration)
    try exerciseEnhancedAPI(configuration: configuration)
  }

  private static func exerciseExplicitFacades(
    configuration: XPCCodec.Configuration,
    message: ConsumerMessage
  ) throws {
    let encoder = XPCEncoder(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    let decoder = XPCDecoder(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape,
      resourceLimits: .standard
    )
    let object = try encoder.encode(message)

    guard try decoder.decode(ConsumerMessage.self, from: object) == message else {
      throw ConsumerFailure.roundTripMismatch
    }
    guard
      encoder.description.contains("string-keys"),
      encoder.debugDescription.contains("XPCEncoder"),
      decoder.description.contains("resource-limits"),
      decoder.debugDescription.contains("XPCDecoder"),
      decoder.resourceLimits.description.contains("depth"),
      decoder.resourceLimits.debugDescription.contains("XPCDecoder.ResourceLimits")
    else {
      throw ConsumerFailure.descriptionMismatch
    }

    let codec = XPCCodec(configuration: configuration)
    guard
      codec.makeEncoder().stringKeyStrategy == .percentEscape,
      codec.makeDecoder().stringKeyStrategy == .percentEscape
    else {
      throw ConsumerFailure.configurationMismatch
    }
  }

  private static func exerciseTransientEncoder(
    configuration: XPCCodec.Configuration
  ) throws {
    let encoder = XPCEncoder(configuration: configuration)
    let decoder = XPCDecoder(configuration: configuration)
    let object = try encoder.withTransientEncoder {
      var container = $0.singleValueContainer()
      try container.encode(29)
    }

    guard try decoder.decode(Int.self, from: object) == 29 else {
      throw ConsumerFailure.roundTripMismatch
    }

    do {
      _ = try encoder.withTransientEncoder { _ in }
      throw ConsumerFailure.missingTransientError
    } catch TransientEncoderError.noEncodingOccurred {
      // The public error case is expected.
    }
  }

  private static func exerciseEnhancedAPI(
    configuration: XPCCodec.Configuration
  ) throws {
    let encoder = XPCEncoder(configuration: configuration)
    let decoder = XPCDecoder(configuration: configuration)
    let bytes: [UInt8] = [0, 1, 2, 3, 5, 8, 13, 255]

    let singleValueObject = try encoder.encode(
      ConsumerSingleValueBinaryPayload(bytes: bytes)
    )
    guard try decoder.decode(Data.self, from: singleValueObject) == Data(bytes) else {
      throw ConsumerFailure.roundTripMismatch
    }

    let unkeyedObject = try encoder.encode(
      ConsumerUnkeyedBinaryPayload(bytes: bytes)
    )
    guard
      try decoder.decode([Data].self, from: unkeyedObject) == [Data(bytes)]
    else {
      throw ConsumerFailure.roundTripMismatch
    }
  }

}

private enum ConsumerFailure: Error {
  case configurationMismatch
  case descriptionMismatch
  case missingSingleValueEnhancement
  case missingTransientError
  case missingUnkeyedEnhancement
  case roundTripMismatch
}

private struct ConsumerMessage: Codable, Equatable {
  let identifier: Int
  let metadata: [String: String]
}

private struct ConsumerSingleValueBinaryPayload: Encodable {
  let bytes: [UInt8]

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    guard container is any XPCEnhancedSingleValueEncodingContainer else {
      throw ConsumerFailure.missingSingleValueEnhancement
    }
    try bytes.withUnsafeBytes {
      try container.efficientlyEncodeBinaryData($0)
    }
  }
}

private struct ConsumerUnkeyedBinaryPayload: Encodable {
  let bytes: [UInt8]

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    guard container is any XPCEnhancedUnkeyedEncodingContainer else {
      throw ConsumerFailure.missingUnkeyedEnhancement
    }
    try bytes.withUnsafeBytes {
      try container.efficientlyEncodeBinaryData($0)
    }
  }
}
