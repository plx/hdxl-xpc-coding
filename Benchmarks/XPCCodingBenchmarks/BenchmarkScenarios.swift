import Foundation
import XPCCoding
@preconcurrency import XPC

enum BenchmarkScenarios {
  static func all(smokeOnly: Bool = false) throws -> [BenchmarkScenario] {
    var scenarios = try coreScenarios(smokeOnly: smokeOnly)
    scenarios.append(contentsOf: try dataScenarios(smokeOnly: smokeOnly))
    scenarios.append(contentsOf: try stringScenarios(smokeOnly: smokeOnly))
    if !smokeOnly {
      scenarios.append(contentsOf: try stringKeyScenarios())
      scenarios.append(contentsOf: try collectionScenarios())
    }
    return scenarios
  }

  private static func coreScenarios(
    smokeOnly: Bool
  ) throws -> [BenchmarkScenario] {
    let encoder = XPCEncoder()
    let decoder = benchmarkDecoder()
    let primitive = PrimitivePayload(
      flag: true,
      signed: -9_223_372,
      unsigned: 18_446_744,
      floatingPoint: .pi,
      text: "same-machine IPC"
    )
    let encodedPrimitive = try encoder.encode(primitive)
    let nested = NestedPayload.fixture(depth: 5)
    let encodedNested = try encoder.encode(nested)
    var scenarios = [
      encodeScenario(
        name: "primitive/encode",
        category: "primitive",
        encoder: encoder,
        value: primitive,
        includedInSmokeRun: true
      ),
      decodeScenario(
        name: "primitive/decode",
        category: "primitive",
        decoder: decoder,
        object: encodedPrimitive,
        type: PrimitivePayload.self,
        includedInSmokeRun: true
      ) {
        UInt64(bitPattern: $0.signed) &+ UInt64($0.text.utf8.count)
      },
      encodeScenario(
        name: "nested/encode",
        category: "nested",
        encoder: encoder,
        value: nested,
        includedInSmokeRun: true
      ),
      decodeScenario(
        name: "nested/decode",
        category: "nested",
        decoder: decoder,
        object: encodedNested,
        type: NestedPayload.self,
        includedInSmokeRun: true
      ) {
        UInt64($0.nodeCount)
      },
    ]

    if !smokeOnly {
      let moderateNesting = NestedPayload.fixture(depth: 24, breadth: 1)
      let encodedModerateNesting = try encoder.encode(moderateNesting)
      scenarios.append(
        encodeScenario(
          name: "moderate-nesting/encode",
          category: "nested",
          encoder: encoder,
          value: moderateNesting
        )
      )
      scenarios.append(
        decodeScenario(
          name: "moderate-nesting/decode",
          category: "nested",
          decoder: decoder,
          object: encodedModerateNesting,
          type: NestedPayload.self
        ) {
          UInt64($0.nodeCount)
        }
      )
    }

    return scenarios
  }

  private static func dataScenarios(
    smokeOnly: Bool
  ) throws -> [BenchmarkScenario] {
    let encoder = XPCEncoder()
    let decoder = benchmarkDecoder()
    var scenarios: [BenchmarkScenario] = []

    let byteCounts =
      smokeOnly
      ? [1_024]
      : [0, 1_024, 64 * 1_024, 1_024 * 1_024]
    for byteCount in byteCounts {
      let data = fixtureData(count: byteCount)
      let fixtures: [(String, any Codable)] =
        smokeOnly
        ? [("top-level", data)]
        : [
          ("top-level", data),
          ("keyed", KeyedDataPayload(bytes: data)),
          ("unkeyed", UnkeyedDataPayload(bytes: data)),
        ]

      for (shape, fixture) in fixtures {
        let namePrefix = "data/\(byteCount)/\(shape)"
        let encoded = try encodeDataFixture(fixture, encoder: encoder)
        scenarios.append(
          BenchmarkScenario(
            name: "\(namePrefix)/encode",
            category: "data",
            operation: "encode",
            logicalByteCount: byteCount,
            encodedXPCObjectCount: xpcObjectCount(encoded),
            maximumIterationsPerSample: maximumIterations(forByteCount: byteCount),
            includedInSmokeRun: byteCount == 1_024 && shape == "top-level"
          ) {
            xpcDigest(try encodeDataFixture(fixture, encoder: encoder))
          }
        )

        switch shape {
        case "top-level":
          scenarios.append(
            decodeScenario(
              name: "\(namePrefix)/decode",
              category: "data",
              decoder: decoder,
              object: encoded,
              type: Data.self,
              logicalByteCount: byteCount,
              maximumIterationsPerSample: maximumIterations(forByteCount: byteCount),
              includedInSmokeRun: byteCount == 1_024
            ) {
              UInt64($0.count)
            }
          )
        case "keyed":
          scenarios.append(
            decodeScenario(
              name: "\(namePrefix)/decode",
              category: "data",
              decoder: decoder,
              object: encoded,
              type: KeyedDataPayload.self,
              logicalByteCount: byteCount,
              maximumIterationsPerSample: maximumIterations(forByteCount: byteCount)
            ) {
              UInt64($0.bytes.count)
            }
          )
        default:
          scenarios.append(
            decodeScenario(
              name: "\(namePrefix)/decode",
              category: "data",
              decoder: decoder,
              object: encoded,
              type: UnkeyedDataPayload.self,
              logicalByteCount: byteCount,
              maximumIterationsPerSample: maximumIterations(forByteCount: byteCount)
            ) {
              UInt64($0.bytes.count)
            }
          )
        }
      }

      if !smokeOnly {
        let direct = DirectDataPayload(bytes: data)
        scenarios.append(
          encodeScenario(
            name: "data/\(byteCount)/direct-buffer/encode",
            category: "data",
            encoder: encoder,
            value: direct,
            logicalByteCount: byteCount,
            maximumIterationsPerSample: maximumIterations(forByteCount: byteCount)
          )
        )
      }
    }

    return scenarios
  }

  private static func stringScenarios(
    smokeOnly: Bool
  ) throws -> [BenchmarkScenario] {
    var scenarios: [BenchmarkScenario] = []
    let longKey = String(repeating: "long-key-", count: 128)
    let longValue = String(repeating: "local-process-value-", count: 256)

    let keyStrategies: [XPCCodec.StringKeyStrategy] =
      smokeOnly ? [.percentEscape] : XPCCodec.StringKeyStrategy.allCases
    let valueStrategies: [XPCCodec.StringValueStrategy] =
      smokeOnly ? [.percentEscape] : XPCCodec.StringValueStrategy.allCases
    for keyStrategy in keyStrategies {
      for valueStrategy in valueStrategies {
        let configuration = XPCCodec.Configuration(
          stringKeyStrategy: keyStrategy,
          stringValueStrategy: valueStrategy
        )
        let fixture = DynamicStringMap(entries: [longKey: longValue])
        scenarios.append(
          try roundTripScenario(
            name: "strings/long/\(identifier(keyStrategy))/\(identifier(valueStrategy))/round-trip",
            category: "strings",
            configuration: configuration,
            fixture: fixture,
            logicalByteCount: longKey.utf8.count + longValue.utf8.count,
            includedInSmokeRun: keyStrategy == .percentEscape
              && valueStrategy == .percentEscape
          )
        )
      }
    }

    if !smokeOnly {
      let percentHeavy = String(repeating: "%value%", count: 1_024)
      scenarios.append(
        try roundTripScenario(
          name: "strings/percent-heavy/round-trip",
          category: "strings",
          configuration: .init(
            stringKeyStrategy: .percentEscape,
            stringValueStrategy: .percentEscape
          ),
          fixture: DynamicStringMap(entries: ["%key%": percentHeavy]),
          logicalByteCount: percentHeavy.utf8.count
        )
      )

      let nullHeavy = String(repeating: "a\u{0}b\u{0}", count: 1_024)
      for valueStrategy: XPCCodec.StringValueStrategy in [
        .percentEscape,
        .useDataRepresentation(.utf8),
        .useDataRepresentation(.utf16),
        .useDataRepresentation(.utf32),
      ] {
        scenarios.append(
          try roundTripScenario(
            name: "strings/null-heavy/\(identifier(valueStrategy))/round-trip",
            category: "strings",
            configuration: .init(
              stringKeyStrategy: .percentEscape,
              stringValueStrategy: valueStrategy
            ),
            fixture: DynamicStringMap(entries: ["key\u{0}with\u{0}nulls": nullHeavy]),
            logicalByteCount: nullHeavy.utf8.count
          )
        )
      }
    }

    return scenarios
  }

  private static func stringKeyScenarios() throws -> [BenchmarkScenario] {
    let manyShortEntries = (0..<1_024).map {
      ("short-key-\($0)", $0)
    }
    let longKeyPrefix = String(repeating: "x", count: 4_096)
    let fewLongEntries = (0..<16).map {
      ("\(longKeyPrefix)-\($0)", $0)
    }

    return try stringKeyScenarios(
      shape: "many-short",
      fixture: DynamicIntMap(entries: manyShortEntries),
      lookupKey: ShortBenchmarkLookupKey.self
    )
      + stringKeyScenarios(
        shape: "few-long",
        fixture: DynamicIntMap(entries: fewLongEntries),
        lookupKey: LongBenchmarkLookupKey.self
      )
  }

  private static func stringKeyScenarios<LookupKey: BenchmarkLookupKey>(
    shape: String,
    fixture: DynamicIntMap,
    lookupKey _: LookupKey.Type
  ) throws -> [BenchmarkScenario] {
    let logicalByteCount = fixture.entries.reduce(0) {
      $0 + $1.key.utf8.count
    }
    var scenarios: [BenchmarkScenario] = []

    for keyStrategy in XPCCodec.StringKeyStrategy.allCases {
      let configuration = XPCCodec.Configuration(
        stringKeyStrategy: keyStrategy,
        stringValueStrategy: .assumeAbsent
      )
      let encoder = XPCEncoder(configuration: configuration)
      let decoder = benchmarkDecoder(configuration: configuration)
      let encoded = try encoder.encode(fixture)
      let maximumIterationsPerSample = 4_096

      scenarios.append(
        encodeScenario(
          name: "string-keys/\(shape)/\(identifier(keyStrategy))/encode",
          category: "string-keys",
          encoder: encoder,
          value: fixture,
          logicalByteCount: logicalByteCount,
          maximumIterationsPerSample: maximumIterationsPerSample
        )
      )
      scenarios.append(
        decodeScenario(
          name: "string-keys/\(shape)/\(decodingIdentifier(keyStrategy))/lookup",
          category: "string-keys",
          operation: "lookup",
          decoder: decoder,
          object: encoded,
          type: DynamicIntLookup<LookupKey>.self,
          logicalByteCount: logicalByteCount,
          maximumIterationsPerSample: maximumIterationsPerSample
        ) {
          UInt64($0.value)
        }
      )
      scenarios.append(
        decodeScenario(
          name: "string-keys/\(shape)/\(decodingIdentifier(keyStrategy))/decode",
          category: "string-keys",
          decoder: decoder,
          object: encoded,
          type: DynamicIntMap.self,
          logicalByteCount: logicalByteCount,
          maximumIterationsPerSample: maximumIterationsPerSample
        ) {
          UInt64($0.entries.reduce(0) { $0 + $1.value })
        }
      )
    }

    return scenarios
  }

  private static func collectionScenarios() throws -> [BenchmarkScenario] {
    let encoder = XPCEncoder()
    let decoder = benchmarkDecoder()
    let array = Array(0..<16_384)
    let dictionary = Dictionary(
      uniqueKeysWithValues: (0..<4_096).map { ("key-\($0)", $0) }
    )
    let encodedArray = try encoder.encode(array)
    let encodedDictionary = try encoder.encode(dictionary)

    return [
      encodeScenario(
        name: "collections/large-array/encode",
        category: "collections",
        encoder: encoder,
        value: array,
        maximumIterationsPerSample: 8
      ),
      decodeScenario(
        name: "collections/large-array/decode",
        category: "collections",
        decoder: decoder,
        object: encodedArray,
        type: [Int].self,
        maximumIterationsPerSample: 8
      ) {
        UInt64($0.count)
      },
      encodeScenario(
        name: "collections/large-dictionary/encode",
        category: "collections",
        encoder: encoder,
        value: dictionary,
        maximumIterationsPerSample: 8
      ),
      decodeScenario(
        name: "collections/large-dictionary/decode",
        category: "collections",
        decoder: decoder,
        object: encodedDictionary,
        type: [String: Int].self,
        maximumIterationsPerSample: 8
      ) {
        UInt64($0.count)
      },
    ]
  }
}

private func encodeScenario<T: Encodable>(
  name: String,
  category: String,
  encoder: XPCEncoder,
  value: T,
  logicalByteCount: Int? = nil,
  maximumIterationsPerSample: Int = 10_000,
  includedInSmokeRun: Bool = false
) -> BenchmarkScenario {
  let encoded = try? encoder.encode(value)
  return BenchmarkScenario(
    name: name,
    category: category,
    operation: "encode",
    logicalByteCount: logicalByteCount,
    encodedXPCObjectCount: encoded.map(xpcObjectCount),
    maximumIterationsPerSample: maximumIterationsPerSample,
    includedInSmokeRun: includedInSmokeRun
  ) {
    xpcDigest(try encoder.encode(value))
  }
}

private func decodeScenario<T: Decodable>(
  name: String,
  category: String,
  operation: String = "decode",
  decoder: XPCDecoder,
  object: xpc_object_t,
  type: T.Type,
  logicalByteCount: Int? = nil,
  maximumIterationsPerSample: Int = 10_000,
  includedInSmokeRun: Bool = false,
  digest: @escaping (T) -> UInt64
) -> BenchmarkScenario {
  BenchmarkScenario(
    name: name,
    category: category,
    operation: operation,
    logicalByteCount: logicalByteCount,
    encodedXPCObjectCount: xpcObjectCount(object),
    maximumIterationsPerSample: maximumIterationsPerSample,
    includedInSmokeRun: includedInSmokeRun
  ) {
    digest(try decoder.decode(type, from: object))
  }
}

private func roundTripScenario(
  name: String,
  category: String,
  configuration: XPCCodec.Configuration,
  fixture: DynamicStringMap,
  logicalByteCount: Int,
  includedInSmokeRun: Bool = false
) throws -> BenchmarkScenario {
  let encoder = XPCEncoder(configuration: configuration)
  let decoder = benchmarkDecoder(configuration: configuration)
  let encoded = try encoder.encode(fixture)
  return BenchmarkScenario(
    name: name,
    category: category,
    operation: "round-trip",
    logicalByteCount: logicalByteCount,
    encodedXPCObjectCount: xpcObjectCount(encoded),
    maximumIterationsPerSample: 2_048,
    includedInSmokeRun: includedInSmokeRun
  ) {
    let object = try encoder.encode(fixture)
    let decoded = try decoder.decode(DynamicStringMap.self, from: object)
    let decodedByteCount = decoded.entries.reduce(0) {
      $0 + $1.key.utf8.count + $1.value.utf8.count
    }
    return xpcDigest(object) &+ UInt64(decodedByteCount)
  }
}

private func encodeDataFixture(
  _ fixture: any Encodable,
  encoder: XPCEncoder
) throws -> xpc_object_t {
  try encoder.encode(fixture)
}

private func benchmarkDecoder(
  configuration: XPCCodec.Configuration = .init(
    stringKeyStrategy: .standard,
    stringValueStrategy: .standard
  )
) -> XPCDecoder {
  #if BENCHMARK_AUDIT_BASELINE
    XPCDecoder(configuration: configuration)
  #else
    XPCDecoder(
      configuration: configuration,
      resourceLimits: .init(
        maximumNestingDepth: 512,
        maximumContainerElementCount: 2_000_000,
        maximumTotalNodeCount: 4_000_000,
        maximumStringByteCount: 32 * 1_024 * 1_024,
        maximumDataByteCount: 32 * 1_024 * 1_024,
        maximumCumulativeByteCount: 128 * 1_024 * 1_024
      )
    )
  #endif
}

private func fixtureData(count: Int) -> Data {
  Data((0..<count).map { UInt8(truncatingIfNeeded: $0 &* 31) })
}

private func maximumIterations(forByteCount byteCount: Int) -> Int {
  switch byteCount {
  case 0..<1_024:
    4_096
  case 1_024..<(64 * 1_024):
    256
  case (64 * 1_024)..<(1_024 * 1_024):
    8
  default:
    1
  }
}

private func identifier(_ strategy: XPCCodec.StringKeyStrategy) -> String {
  switch strategy {
  case .assumeAbsent:
    "assume-absent"
  case .percentEscape:
    "percent-escape"
  }
}

private func decodingIdentifier(_ strategy: XPCCodec.StringKeyStrategy) -> String {
  switch strategy {
  case .assumeAbsent:
    "passthrough"
  case .percentEscape:
    "percent-escape"
  }
}

private func identifier(_ strategy: XPCCodec.StringValueStrategy) -> String {
  switch strategy {
  case .assumeAbsent:
    "assume-absent"
  case .throwOnDiscovery:
    "throw-on-discovery"
  case .percentEscape:
    "percent-escape"
  case .useDataRepresentation(.utf8):
    "utf8-data"
  case .useDataRepresentation(.utf16):
    "utf16-data"
  case .useDataRepresentation(.utf32):
    "utf32-data"
  }
}

private func xpcDigest(_ object: xpc_object_t) -> UInt64 {
  switch xpc_get_type(object) {
  case XPC_TYPE_ARRAY:
    UInt64(xpc_array_get_count(object))
  case XPC_TYPE_DICTIONARY:
    UInt64(xpc_dictionary_get_count(object))
  case XPC_TYPE_DATA:
    UInt64(xpc_data_get_length(object))
  default:
    UInt64(xpc_hash(object))
  }
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
