import Foundation
import Testing
import XPC
@testable import XPCCoding

@Suite("Strict UTF-8 Decoding")
struct StrictUTF8DecodingTests {

  @Test(
    arguments: [
      XPCDecoder.StringValueStrategy.passthrough,
      .percentEscape,
    ]
  )
  func `malformed XPC string values throw at their complete path`(
    strategy: XPCDecoder.StringValueStrategy
  ) throws {
    let dictionary = xpc_dictionary_create(nil, nil, 0)
    let malformedValue = malformedUTF8XPCString()
    #expect(xpc_string_get_length(malformedValue) == 1)
    xpc_dictionary_set_value(
      dictionary,
      "value",
      malformedValue
    )
    let decoder = XPCDecoder(stringValueStrategy: strategy)

    do {
      let result = try decoder.decode(
        StrictUTF8ValueProbe.self,
        from: dictionary
      )
      Issue.record(
        "Expected malformed UTF-8 to throw, but decoded \(String(reflecting: result.value))."
      )
      #expect(!result.value.contains("\u{FFFD}"))
    } catch let error as DecodingError {
      expectMalformedUTF8Error(
        error,
        codingPath: ["value"],
        debugDescriptionFragment: "string value"
      )
    }
  }

  @Test(
    arguments: [
      XPCDecoder.StringKeyStrategy.passthrough,
      .percentEscape,
    ]
  )
  func `malformed dictionary keys fail before allKeys is exposed`(
    strategy: XPCDecoder.StringKeyStrategy
  ) throws {
    let decoder = XPCDecoder(stringKeyStrategy: strategy)

    do {
      let result = try decoder.decode(
        StrictUTF8KeyProbe.self,
        from: dictionaryWithMalformedUTF8Key()
      )
      Issue.record(
        "Expected keyed-container creation to reject malformed UTF-8."
      )
      #expect(!result.keys.contains("\u{FFFD}"))
    } catch let error as DecodingError {
      expectMalformedUTF8Error(
        error,
        codingPath: [],
        debugDescriptionFragment: "dictionary key"
      )
    }
  }

  @Test
  func `percent unescaping runs only after key UTF-8 validation`() throws {
    let dictionary = xpc_dictionary_create(nil, nil, 0)
    xpc_dictionary_set_value(
      dictionary,
      "%GG",
      xpc_int64_create(1)
    )

    do {
      _ = try XPCDecoder(
        stringKeyStrategy: .percentEscape
      ).decode(
        StrictUTF8KeyProbe.self,
        from: dictionary
      )
      Issue.record(
        "Expected keyed-container creation to reject malformed percent escapes."
      )
    } catch let DecodingError.dataCorrupted(context) {
      #expect(context.codingPath.isEmpty)
      guard
        let extractionError = context.underlyingError
          as? XPCStringExtractionError,
        case .unableToRemovePercentEscapes = extractionError
      else {
        Issue.record(
          "Expected an unableToRemovePercentEscapes underlying error."
        )
        return
      }
    }
  }

  @Test
  func `valid Unicode percent escapes and empty strings remain valid`() throws {
    let passthroughValue = [
      "": "",
      "é": "東京🚀",
      "%": "100%",
    ]
    let passthroughCodec = XPCCodec(
      configuration: XPCCodec.Configuration(
        stringKeyStrategy: .assumeAbsent,
        stringValueStrategy: .assumeAbsent
      )
    )
    #expect(
      try passthroughCodec.decode(
        [String: String].self,
        from: passthroughCodec.encode(passthroughValue)
      ) == passthroughValue
    )

    let percentEscapedValue = [
      "": "",
      "é%\0": "東京🚀%\0",
    ]
    let percentEscapeCodec = XPCCodec(
      configuration: XPCCodec.Configuration(
        stringKeyStrategy: .percentEscape,
        stringValueStrategy: .percentEscape
      )
    )
    #expect(
      try percentEscapeCodec.decode(
        [String: String].self,
        from: percentEscapeCodec.encode(percentEscapedValue)
      ) == percentEscapedValue
    )
  }

  @Test(
    arguments: [
      XPCDecoder.StringKeyStrategy.passthrough,
      .percentEscape,
    ]
  )
  func `canonically-equivalent valid Unicode keys remain distinct`(
    strategy: XPCDecoder.StringKeyStrategy
  ) throws {
    let dictionary = xpc_dictionary_create(nil, nil, 0)
    "é".withCString {
      xpc_dictionary_set_value(
        dictionary,
        $0,
        xpc_int64_create(1)
      )
    }
    "e\u{301}".withCString {
      xpc_dictionary_set_value(
        dictionary,
        $0,
        xpc_int64_create(2)
      )
    }

    let result = try XPCDecoder(
      stringKeyStrategy: strategy
    ).decode(
      ExactUnicodeKeyProbe.self,
      from: dictionary
    )
    #expect(result.observations.count == 2)
    #expect(result.observations.allSatisfy { $0.isContained })
    #expect(Set(result.observations.map(\.value)) == [1, 2])
    #expect(
      Set(result.observations.map(\.unicodeScalars)) == [
        [0xE9],
        [0x65, 0x301],
      ]
    )
  }

  @Test
  func `known-key decoding defers CodingKey materialization`() throws {
    let dictionary = xpc_dictionary_create(nil, nil, 0)
    xpc_dictionary_set_value(
      dictionary,
      "value",
      xpc_int64_create(42)
    )

    let result = try XPCDecoder().decode(
      DeferredCodingKeyProbe.self,
      from: dictionary
    )

    #expect(result.value == 42)
    #expect(result.initializationsAfterContainerCreation == 0)
    #expect(result.initializationsAfterKnownKeyLookup == 0)
    #expect(result.initializationsAfterAllKeys == 1)
    #expect(result.allKeys == ["value"])
  }
}

private struct StrictUTF8ValueProbe: Decodable {
  let value: String
}

private struct StrictUTF8CodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

private struct StrictUTF8KeyProbe: Decodable {
  let keys: [String]

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(
      keyedBy: StrictUTF8CodingKey.self
    )
    self.keys = container.allKeys.map(\.stringValue)
  }
}

private struct ExactUnicodeKeyProbe: Decodable {
  struct Observation {
    let unicodeScalars: [UInt32]
    let isContained: Bool
    let value: Int
  }

  let observations: [Observation]

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(
      keyedBy: StrictUTF8CodingKey.self
    )
    self.observations = try container.allKeys.map { key in
      Observation(
        unicodeScalars: key.stringValue.unicodeScalars.map(\.value),
        isContained: container.contains(key),
        value: try container.decode(Int.self, forKey: key)
      )
    }
  }
}

private struct DeferredCodingKey: CodingKey {
  // This type is used by one non-parameterized synchronous test. Keeping the
  // counter here lets the test observe protocol-driven key materialization.
  nonisolated(unsafe) private static var stringInitializationCount = 0

  let stringValue: String
  let intValue: Int?

  init(knownStringValue: String) {
    self.stringValue = knownStringValue
    self.intValue = nil
  }

  init?(stringValue: String) {
    Self.stringInitializationCount += 1
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }

  static func resetStringInitializationCount() {
    stringInitializationCount = 0
  }

  static var currentStringInitializationCount: Int {
    stringInitializationCount
  }
}

private struct DeferredCodingKeyProbe: Decodable {
  let value: Int
  let initializationsAfterContainerCreation: Int
  let initializationsAfterKnownKeyLookup: Int
  let initializationsAfterAllKeys: Int
  let allKeys: [String]

  init(from decoder: any Decoder) throws {
    DeferredCodingKey.resetStringInitializationCount()
    let container = try decoder.container(keyedBy: DeferredCodingKey.self)
    self.initializationsAfterContainerCreation =
      DeferredCodingKey.currentStringInitializationCount
    self.value = try container.decode(
      Int.self,
      forKey: DeferredCodingKey(knownStringValue: "value")
    )
    self.initializationsAfterKnownKeyLookup =
      DeferredCodingKey.currentStringInitializationCount
    self.allKeys = container.allKeys.map(\.stringValue)
    self.initializationsAfterAllKeys =
      DeferredCodingKey.currentStringInitializationCount
  }
}

private func malformedUTF8XPCString() -> xpc_object_t {
  let bytes: [CChar] = [-1, 0]
  return bytes.withUnsafeBufferPointer { buffer in
    guard let baseAddress = buffer.baseAddress else {
      preconditionFailure("A nonempty test buffer must have a base address.")
    }
    return xpc_string_create(baseAddress)
  }
}

private func dictionaryWithMalformedUTF8Key() -> xpc_object_t {
  let dictionary = xpc_dictionary_create(nil, nil, 0)
  let malformedBytes: [CChar] = [-1, 0]
  malformedBytes.withUnsafeBufferPointer { buffer in
    guard let baseAddress = buffer.baseAddress else {
      preconditionFailure("A nonempty test buffer must have a base address.")
    }
    xpc_dictionary_set_value(
      dictionary,
      baseAddress,
      xpc_int64_create(1)
    )
  }
  "\u{FFFD}".withCString { validReplacementCharacter in
    xpc_dictionary_set_value(
      dictionary,
      validReplacementCharacter,
      xpc_int64_create(2)
    )
  }
  return dictionary
}

private func expectMalformedUTF8Error(
  _ error: DecodingError,
  codingPath: [String],
  debugDescriptionFragment: String,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  guard case .dataCorrupted(let context) = error else {
    Issue.record(
      "Expected dataCorrupted, got \(String(reflecting: error)).",
      sourceLocation: sourceLocation
    )
    return
  }

  #expect(
    context.codingPath.map(\.stringValue) == codingPath,
    sourceLocation: sourceLocation
  )
  #expect(
    context.debugDescription.contains(debugDescriptionFragment),
    sourceLocation: sourceLocation
  )
  guard
    let extractionError = context.underlyingError
      as? XPCStringExtractionError,
    case .unableToDecode = extractionError
  else {
    Issue.record(
      "Expected an unableToDecode underlying error.",
      sourceLocation: sourceLocation
    )
    return
  }
}
