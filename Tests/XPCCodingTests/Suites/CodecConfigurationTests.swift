import Testing
import XPC
import XPCCoding

// MARK: - Codec Configuration Tests

@Suite("XPCCodec Configuration")
struct CodecConfigurationTests {

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `factories return fresh compatible facades`(
    configuration: XPCCodec.Configuration
  ) {
    let codec = XPCCodec(configuration: configuration)
    let firstEncoder = codec.makeEncoder()
    let secondEncoder = codec.makeEncoder()
    let expectedEncoder = XPCEncoder(configuration: configuration)
    let firstDecoder = codec.makeDecoder()
    let secondDecoder = codec.makeDecoder()
    let expectedDecoder = XPCDecoder(configuration: configuration)

    #expect(firstEncoder !== secondEncoder)
    #expect(firstDecoder !== secondDecoder)
    #expect(firstEncoder.stringKeyStrategy == expectedEncoder.stringKeyStrategy)
    #expect(firstEncoder.stringValueStrategy == expectedEncoder.stringValueStrategy)
    #expect(firstDecoder.stringKeyStrategy == expectedDecoder.stringKeyStrategy)
    #expect(firstDecoder.stringValueStrategy == expectedDecoder.stringValueStrategy)
    #expect(firstDecoder.resourceLimits == .standard)
  }

  @Test
  func `factory mutations do not affect codec operations or later factories`() throws {
    let configuration = XPCCodec.Configuration(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    let codec = XPCCodec(configuration: configuration)
    let independentEncoder = codec.makeEncoder()
    let independentDecoder = codec.makeDecoder()

    independentEncoder.stringKeyStrategy = .assumeAbsent
    independentEncoder.stringValueStrategy = .useDataRepresentation(.utf8)
    independentDecoder.stringKeyStrategy = .passthrough
    independentDecoder.stringValueStrategy = .useDataRepresentation(.utf8)
    independentDecoder.resourceLimits = .init(
      maximumNestingDepth: 0,
      maximumContainerElementCount: 0,
      maximumTotalNodeCount: 1,
      maximumStringByteCount: 0,
      maximumDataByteCount: 0,
      maximumCumulativeByteCount: 0
    )

    let expected = ["key\u{0}%": "value\u{0}%"]
    let encoded = try codec.encode(expected)

    #expect(try codec.decode([String: String].self, from: encoded) == expected)

    let nextEncoder = codec.makeEncoder()
    let nextDecoder = codec.makeDecoder()
    let expectedEncoder = XPCEncoder(configuration: configuration)
    let expectedDecoder = XPCDecoder(configuration: configuration)

    #expect(nextEncoder !== independentEncoder)
    #expect(nextDecoder !== independentDecoder)
    #expect(nextEncoder.stringKeyStrategy == expectedEncoder.stringKeyStrategy)
    #expect(nextEncoder.stringValueStrategy == expectedEncoder.stringValueStrategy)
    #expect(nextDecoder.stringKeyStrategy == expectedDecoder.stringKeyStrategy)
    #expect(nextDecoder.stringValueStrategy == expectedDecoder.stringValueStrategy)
    #expect(nextDecoder.resourceLimits == .standard)
  }

  @Test
  func `codec copies share no mutable coder state`() throws {
    let configuration = XPCCodec.Configuration(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    let original = XPCCodec(configuration: configuration)
    let copy = original
    let originalEncoder = original.makeEncoder()
    let copyDecoder = copy.makeDecoder()

    originalEncoder.stringValueStrategy = .useDataRepresentation(.utf16)
    copyDecoder.stringValueStrategy = .useDataRepresentation(.utf32)

    let expected = "copy\u{0}%"
    let encodedByCopy = try copy.encode(expected)
    let decodedByOriginal = try original.decode(
      String.self,
      from: encodedByCopy
    )

    #expect(decodedByOriginal == expected)
    #expect(original.configuration == configuration)
    #expect(copy.configuration == configuration)
    #expect(original.makeEncoder() !== originalEncoder)
    #expect(copy.makeDecoder() !== copyDecoder)
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `every configuration reports and uses its strategies`(
    configuration: XPCCodec.Configuration
  ) throws {
    let codec = XPCCodec(configuration: configuration)

    #expect(codec.configuration == configuration)
    #expect(codec.stringKeyStrategy == configuration.stringKeyStrategy)
    #expect(codec.stringValueStrategy == configuration.stringValueStrategy)

    let encodedKey = try codec.encode(["%": "value"])
    let expectedDictionaryKey =
      configuration.stringKeyStrategy == .percentEscape
      ? "%25"
      : "%"

    #expect(xpc_get_type(encodedKey) == XPC_TYPE_DICTIONARY)
    #expect(xpc_dictionary_get_count(encodedKey) == 1)
    #expect(xpc_dictionary_get_value(encodedKey, expectedDictionaryKey) != nil)

    let encodedValue = try codec.encode("%")
    switch configuration.stringValueStrategy {
    case .assumeAbsent, .throwOnDiscovery:
      #expect(xpc_get_type(encodedValue) == XPC_TYPE_STRING)
      #expect(xpc_string_get_string_ptr(encodedValue).map(String.init(cString:)) == "%")
    case .percentEscape:
      #expect(xpc_get_type(encodedValue) == XPC_TYPE_STRING)
      #expect(xpc_string_get_string_ptr(encodedValue).map(String.init(cString:)) == "%25")
    case .useDataRepresentation:
      #expect(xpc_get_type(encodedValue) == XPC_TYPE_DATA)
    }

    #expect(try codec.decode(String.self, from: encodedValue) == "%")

    let factoryEncoded = try codec.makeEncoder().encode("%")
    #expect(xpc_equal(encodedValue, factoryEncoded))
    #expect(try codec.makeDecoder().decode(String.self, from: encodedValue) == "%")
  }

}
