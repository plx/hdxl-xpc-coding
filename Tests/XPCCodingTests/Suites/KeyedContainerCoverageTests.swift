import Foundation
import Testing
@testable import XPCCoding

// MARK: - Keyed Container Coverage Tests

@Suite("Keyed Container Coverage", .tags(.keyed, .containers))
struct KeyedContainerCoverageTests {

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `manual keyed primitive overloads round trip`(
    configuration: XPCCodec.Configuration
  ) throws {
    // This fixture explicitly calls every primitive keyed encode/decode
    // overload and checks `allKeys`, `contains(_:)`, and nil decoding. The
    // synthesized `Codable` path does not reliably prove those overloads stay
    // wired to the XPC dictionary accessors.
    let probe = ExplicitKeyedPrimitiveProbe(
      bool: false,
      string: "manual keyed string",
      double: -2048.25,
      float: 512.5,
      int: -321,
      int8: -12,
      int16: -2048,
      int32: -131_072,
      int64: -1_234_567_890,
      int128: -987_654_321,
      uint: 321,
      uint8: 12,
      uint16: 2048,
      uint32: 131_072,
      uint64: 1_234_567_890,
      uint128: 987_654_321
    )

    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `generated keyed primitive overloads round trip`(
    configuration: XPCCodec.Configuration
  ) throws {
    for probe in generatedKeyedPrimitiveProbes(count: 32) {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `manual keyed nested and super containers round trip`(
    configuration: XPCCodec.Configuration
  ) throws {
    // The nested keyed fixture covers `nestedContainer(keyedBy:forKey:)`.
    // The super fixtures cover the dictionary-referencing encoder when it
    // writes keyed, unkeyed, and single-value payloads back under a dictionary
    // key.
    let probe = ExplicitKeyedNestedProbe(
      nestedKeyedValue: 11,
      nestedUnkeyedValues: [3, 1, 4, 1, 5],
      defaultSuperValue: "default-super",
      keyedSuperValue: 22,
      unkeyedSuperValues: [2, 7, 1, 8],
      singleSuperValue: "explicit-super"
    )

    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `generated keyed nested and super containers round trip`(
    configuration: XPCCodec.Configuration
  ) throws {
    for probe in generatedKeyedNestedProbes(count: 32) {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }

  @Test
  func `manual keyed missing value throws`() throws {
    // Required keyed lookups should throw `keyNotFound` rather than silently
    // manufacturing default values when the underlying XPC dictionary lacks a
    // requested key.
    let encoded = try XPCEncoder.standard.encode(["present": 1])

    #expect(throws: DecodingError.self) {
      try XPCDecoder.standard.decode(KeyedMissingValueProbe.self, from: encoded)
    }
  }

  @Test
  func `generated keyed missing value throws`() throws {
    for value in generatedMissingValueDictionaries(count: 32) {
      let encoded = try XPCEncoder.standard.encode(value)

      #expect(throws: DecodingError.self) {
        try XPCDecoder.standard.decode(KeyedMissingValueProbe.self, from: encoded)
      }
    }
  }

}

// MARK: - Primitive Probe

private enum ExplicitKeyedPrimitiveKeys: String, CodingKey {
  case nilSentinel
  case bool
  case string
  case double
  case float
  case int
  case int8
  case int16
  case int32
  case int64
  case int128
  case uint
  case uint8
  case uint16
  case uint32
  case uint64
  case uint128
  case missing
}

private struct ExplicitKeyedPrimitiveProbe: Codable, Equatable {
  let bool: Bool
  let string: String
  let double: Double
  let float: Float
  let int: Int
  let int8: Int8
  let int16: Int16
  let int32: Int32
  let int64: Int64
  let int128: Int128
  let uint: UInt
  let uint8: UInt8
  let uint16: UInt16
  let uint32: UInt32
  let uint64: UInt64
  let uint128: UInt128

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: ExplicitKeyedPrimitiveKeys.self)
    try container.encodeNil(forKey: .nilSentinel)
    try container.encode(bool, forKey: .bool)
    try container.encode(string, forKey: .string)
    try container.encode(double, forKey: .double)
    try container.encode(float, forKey: .float)
    try container.encode(int, forKey: .int)
    try container.encode(int8, forKey: .int8)
    try container.encode(int16, forKey: .int16)
    try container.encode(int32, forKey: .int32)
    try container.encode(int64, forKey: .int64)
    try container.encode(int128, forKey: .int128)
    try container.encode(uint, forKey: .uint)
    try container.encode(uint8, forKey: .uint8)
    try container.encode(uint16, forKey: .uint16)
    try container.encode(uint32, forKey: .uint32)
    try container.encode(uint64, forKey: .uint64)
    try container.encode(uint128, forKey: .uint128)
  }

  init(
    bool: Bool,
    string: String,
    double: Double,
    float: Float,
    int: Int,
    int8: Int8,
    int16: Int16,
    int32: Int32,
    int64: Int64,
    int128: Int128,
    uint: UInt,
    uint8: UInt8,
    uint16: UInt16,
    uint32: UInt32,
    uint64: UInt64,
    uint128: UInt128
  ) {
    self.bool = bool
    self.string = string
    self.double = double
    self.float = float
    self.int = int
    self.int8 = int8
    self.int16 = int16
    self.int32 = int32
    self.int64 = int64
    self.int128 = int128
    self.uint = uint
    self.uint8 = uint8
    self.uint16 = uint16
    self.uint32 = uint32
    self.uint64 = uint64
    self.uint128 = uint128
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: ExplicitKeyedPrimitiveKeys.self)
    let keys = Set(container.allKeys)

    guard keys.contains(.nilSentinel), container.contains(.nilSentinel) else {
      throw DecodingError.keyNotFound(
        ExplicitKeyedPrimitiveKeys.nilSentinel,
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Expected nil sentinel key."
        )
      )
    }
    guard !container.contains(.missing) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Unexpected missing-key fixture was present."
        )
      )
    }
    guard try container.decodeNil(forKey: .nilSentinel) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Expected nil sentinel value."
        )
      )
    }

    self.bool = try container.decode(Bool.self, forKey: .bool)
    self.string = try container.decode(String.self, forKey: .string)
    self.double = try container.decode(Double.self, forKey: .double)
    self.float = try container.decode(Float.self, forKey: .float)
    self.int = try container.decode(Int.self, forKey: .int)
    self.int8 = try container.decode(Int8.self, forKey: .int8)
    self.int16 = try container.decode(Int16.self, forKey: .int16)
    self.int32 = try container.decode(Int32.self, forKey: .int32)
    self.int64 = try container.decode(Int64.self, forKey: .int64)
    self.int128 = try container.decode(Int128.self, forKey: .int128)
    self.uint = try container.decode(UInt.self, forKey: .uint)
    self.uint8 = try container.decode(UInt8.self, forKey: .uint8)
    self.uint16 = try container.decode(UInt16.self, forKey: .uint16)
    self.uint32 = try container.decode(UInt32.self, forKey: .uint32)
    self.uint64 = try container.decode(UInt64.self, forKey: .uint64)
    self.uint128 = try container.decode(UInt128.self, forKey: .uint128)
  }
}

// MARK: - Nested Probe

private enum ExplicitKeyedNestedKeys: String, CodingKey {
  case value
  case nestedKeyed
  case nestedUnkeyed
  case keyedSuper
  case unkeyedSuper
  case singleSuper
}

private struct ExplicitKeyedNestedProbe: Codable, Equatable {
  let nestedKeyedValue: Int
  let nestedUnkeyedValues: [Int]
  let defaultSuperValue: String
  let keyedSuperValue: Int
  let unkeyedSuperValues: [Int]
  let singleSuperValue: String

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: ExplicitKeyedNestedKeys.self)

    var nestedKeyedContainer = container.nestedContainer(
      keyedBy: ExplicitKeyedNestedKeys.self,
      forKey: .nestedKeyed
    )
    try nestedKeyedContainer.encode(nestedKeyedValue, forKey: .value)

    var nestedUnkeyedContainer = container.nestedUnkeyedContainer(forKey: .nestedUnkeyed)
    for value in nestedUnkeyedValues {
      try nestedUnkeyedContainer.encode(value)
    }

    try defaultSuperValue.encode(to: container.superEncoder())
    try KeyedContainerSuperPayload(value: keyedSuperValue).encode(
      to: container.superEncoder(forKey: .keyedSuper)
    )
    try KeyedContainerUnkeyedSuperPayload(values: unkeyedSuperValues).encode(
      to: container.superEncoder(forKey: .unkeyedSuper)
    )
    try singleSuperValue.encode(to: container.superEncoder(forKey: .singleSuper))
  }

  init(
    nestedKeyedValue: Int,
    nestedUnkeyedValues: [Int],
    defaultSuperValue: String,
    keyedSuperValue: Int,
    unkeyedSuperValues: [Int],
    singleSuperValue: String
  ) {
    self.nestedKeyedValue = nestedKeyedValue
    self.nestedUnkeyedValues = nestedUnkeyedValues
    self.defaultSuperValue = defaultSuperValue
    self.keyedSuperValue = keyedSuperValue
    self.unkeyedSuperValues = unkeyedSuperValues
    self.singleSuperValue = singleSuperValue
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: ExplicitKeyedNestedKeys.self)

    let nestedKeyedContainer = try container.nestedContainer(
      keyedBy: ExplicitKeyedNestedKeys.self,
      forKey: .nestedKeyed
    )
    self.nestedKeyedValue = try nestedKeyedContainer.decode(Int.self, forKey: .value)

    var nestedUnkeyedContainer = try container.nestedUnkeyedContainer(forKey: .nestedUnkeyed)
    var nestedUnkeyedValues: [Int] = []
    while !nestedUnkeyedContainer.isAtEnd {
      nestedUnkeyedValues.append(try nestedUnkeyedContainer.decode(Int.self))
    }
    self.nestedUnkeyedValues = nestedUnkeyedValues

    self.defaultSuperValue = try String(from: container.superDecoder())
    self.keyedSuperValue = try KeyedContainerSuperPayload(
      from: container.superDecoder(forKey: .keyedSuper)
    ).value
    self.unkeyedSuperValues = try KeyedContainerUnkeyedSuperPayload(
      from: container.superDecoder(forKey: .unkeyedSuper)
    ).values
    self.singleSuperValue = try String(from: container.superDecoder(forKey: .singleSuper))
  }
}

private struct KeyedContainerSuperPayload: Codable, Equatable {
  let value: Int
}

private struct KeyedContainerUnkeyedSuperPayload: Codable, Equatable {
  let values: [Int]

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    for value in values {
      try container.encode(value)
    }
  }

  init(values: [Int]) {
    self.values = values
  }

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    var values: [Int] = []
    while !container.isAtEnd {
      values.append(try container.decode(Int.self))
    }
    self.values = values
  }
}

private struct KeyedMissingValueProbe: Decodable {
  enum CodingKeys: String, CodingKey {
    case missing
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    _ = try container.decode(Int.self, forKey: .missing)
  }
}

// MARK: - Generated Fixtures

private struct KeyedSeededGenerator: RandomNumberGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state = state &* 3_202_034_522_624_059_733 &+ 7_044_899
    return state
  }
}

private func generatedKeyedPrimitiveProbes(count: Int) -> [ExplicitKeyedPrimitiveProbe] {
  var generator = KeyedSeededGenerator(state: 0x0ced_ed00_5eed)
  var result: [ExplicitKeyedPrimitiveProbe] = []
  result.reserveCapacity(count)

  for index in 0..<count {
    let int64 = Int64(truncatingIfNeeded: generator.next())
    let uint64 = generator.next() % 1_000_000_000_000
    result.append(
      ExplicitKeyedPrimitiveProbe(
        bool: index.isMultiple(of: 2),
        string: generatedKeyedASCIIString(using: &generator, maximumLength: 32),
        double: Double(Int32(truncatingIfNeeded: generator.next())) / 16.0,
        float: Float(Int16(truncatingIfNeeded: generator.next())) / 8.0,
        int: Int(truncatingIfNeeded: int64),
        int8: Int8(truncatingIfNeeded: generator.next()),
        int16: Int16(truncatingIfNeeded: generator.next()),
        int32: Int32(truncatingIfNeeded: generator.next()),
        int64: int64,
        int128: Int128(int64),
        uint: UInt(truncatingIfNeeded: uint64),
        uint8: UInt8(truncatingIfNeeded: generator.next()),
        uint16: UInt16(truncatingIfNeeded: generator.next()),
        uint32: UInt32(truncatingIfNeeded: generator.next()),
        uint64: uint64,
        uint128: UInt128(uint64)
      )
    )
  }

  return result
}

private func generatedKeyedNestedProbes(count: Int) -> [ExplicitKeyedNestedProbe] {
  var generator = KeyedSeededGenerator(state: 0x051a_7ed0_5eed)
  var result: [ExplicitKeyedNestedProbe] = []
  result.reserveCapacity(count)

  for _ in 0..<count {
    let nestedCount = Int(generator.next() % 10)
    let superCount = Int(generator.next() % 10)
    result.append(
      ExplicitKeyedNestedProbe(
        nestedKeyedValue: Int(truncatingIfNeeded: generator.next()) % 100_000,
        nestedUnkeyedValues: (0..<nestedCount).map { _ in
          Int(truncatingIfNeeded: generator.next()) % 100_000
        },
        defaultSuperValue: generatedKeyedASCIIString(using: &generator, maximumLength: 24),
        keyedSuperValue: Int(truncatingIfNeeded: generator.next()) % 100_000,
        unkeyedSuperValues: (0..<superCount).map { _ in
          Int(truncatingIfNeeded: generator.next()) % 100_000
        },
        singleSuperValue: generatedKeyedASCIIString(using: &generator, maximumLength: 24)
      )
    )
  }

  return result
}

private func generatedMissingValueDictionaries(count: Int) -> [[String: Int]] {
  var generator = KeyedSeededGenerator(state: 0x0bad_d1c7_5eed)
  return (0..<count).map { index in
    ["present-\(index)": Int(truncatingIfNeeded: generator.next())]
  }
}

private func generatedKeyedASCIIString(
  using generator: inout KeyedSeededGenerator,
  maximumLength: Int
) -> String {
  let length = Int(generator.next() % UInt64(maximumLength + 1))
  let scalars = (0..<length).map { _ in
    let value = 32 + Int(generator.next() % 95)
    return UnicodeScalar(value == 37 ? 36 : value)!
  }
  return String(String.UnicodeScalarView(scalars))
}
