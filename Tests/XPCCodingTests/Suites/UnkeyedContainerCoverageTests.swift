import Foundation
import Testing
@testable import XPCCoding

// MARK: - Unkeyed Container Coverage Tests

@Suite("Unkeyed Container Coverage", .tags(.unkeyed, .containers))
struct UnkeyedContainerCoverageTests {

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `manual unkeyed primitive overloads round trip`(
    configuration: XPCCodec.Configuration
  ) throws {
    // This hand-written probe calls each primitive unkeyed encode/decode
    // overload explicitly, including both the consuming and non-consuming
    // `decodeNil()` paths. Synthesized `Array` coding mostly exercises the
    // generic overload, so this keeps the protocol-specific implementations
    // from silently drifting.
    let probe = ExplicitUnkeyedPrimitiveProbe(
      bool: true,
      string: "manual string",
      double: 1234.5,
      float: -64.25,
      int: -123,
      int8: -8,
      int16: -1024,
      int32: -65_536,
      int64: -9_876_543_210,
      int128: -123_456_789,
      uint: 123,
      uint8: 8,
      uint16: 1024,
      uint32: 65_536,
      uint64: 9_876_543_210,
      uint128: 123_456_789
    )

    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `generated unkeyed primitive overloads round trip`(
    configuration: XPCCodec.Configuration
  ) throws {
    for probe in generatedPrimitiveProbes(count: 32) {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `manual unkeyed nested and super containers round trip`(
    configuration: XPCCodec.Configuration
  ) throws {
    // This fixture forces unkeyed nested keyed containers, nested unkeyed
    // containers, and all three array-referencing super encoders. It protects
    // the reference encoder paths that only exist to write back into an already
    // allocated XPC array slot.
    let probe = ExplicitUnkeyedNestedProbe(
      keyedValue: 42,
      nestedString: "nested",
      nestedInt: -99,
      keyedSuperValue: 17,
      unkeyedSuperValues: [1, 1, 2, 3, 5, 8],
      singleSuperValue: "super"
    )

    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `generated unkeyed nested and super containers round trip`(
    configuration: XPCCodec.Configuration
  ) throws {
    for probe in generatedNestedProbes(count: 32) {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }

  @Test
  func `manual unkeyed overread throws`() throws {
    // The container should report a decoding failure if a caller attempts to
    // read past the array end. This directly exercises the end-of-container
    // guard instead of relying on higher-level collection decoding to stop.
    let encoded = try XPCEncoder.standard.encode([17])

    #expect(throws: DecodingError.self) {
      try XPCDecoder.standard.decode(UnkeyedOverreadProbe.self, from: encoded)
    }
  }

  @Test
  func `generated unkeyed overread throws`() throws {
    for value in generatedOverreadValues(count: 32) {
      let encoded = try XPCEncoder.standard.encode([value])

      #expect(throws: DecodingError.self) {
        try XPCDecoder.standard.decode(UnkeyedOverreadProbe.self, from: encoded)
      }
    }
  }

}

// MARK: - Explicit Primitive Probe

private struct ExplicitUnkeyedPrimitiveProbe: Codable, Equatable {
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
    var container = encoder.unkeyedContainer()
    try container.encodeNil()
    try container.encode(bool)
    try container.encode(string)
    try container.encode(double)
    try container.encode(float)
    try container.encode(int)
    try container.encode(int8)
    try container.encode(int16)
    try container.encode(int32)
    try container.encode(int64)
    try container.encode(int128)
    try container.encode(uint)
    try container.encode(uint8)
    try container.encode(uint16)
    try container.encode(uint32)
    try container.encode(uint64)
    try container.encode(uint128)
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
    var container = try decoder.unkeyedContainer()
    guard try container.decodeNil() else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Expected leading nil sentinel."
        )
      )
    }
    guard try !container.decodeNil() else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Second element should not be nil."
        )
      )
    }

    self.bool = try container.decode(Bool.self)
    self.string = try container.decode(String.self)
    self.double = try container.decode(Double.self)
    self.float = try container.decode(Float.self)
    self.int = try container.decode(Int.self)
    self.int8 = try container.decode(Int8.self)
    self.int16 = try container.decode(Int16.self)
    self.int32 = try container.decode(Int32.self)
    self.int64 = try container.decode(Int64.self)
    self.int128 = try container.decode(Int128.self)
    self.uint = try container.decode(UInt.self)
    self.uint8 = try container.decode(UInt8.self)
    self.uint16 = try container.decode(UInt16.self)
    self.uint32 = try container.decode(UInt32.self)
    self.uint64 = try container.decode(UInt64.self)
    self.uint128 = try container.decode(UInt128.self)
  }
}

// MARK: - Nested Probe

private enum UnkeyedNestedCodingKeys: String, CodingKey {
  case value
}

private struct ExplicitUnkeyedNestedProbe: Codable, Equatable {
  let keyedValue: Int
  let nestedString: String
  let nestedInt: Int
  let keyedSuperValue: Int
  let unkeyedSuperValues: [Int]
  let singleSuperValue: String

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()

    var keyedContainer = container.nestedContainer(keyedBy: UnkeyedNestedCodingKeys.self)
    try keyedContainer.encode(keyedValue, forKey: .value)

    var nestedUnkeyedContainer = container.nestedUnkeyedContainer()
    try nestedUnkeyedContainer.encode(nestedString)
    try nestedUnkeyedContainer.encode(nestedInt)

    try KeyedSuperPayload(value: keyedSuperValue).encode(to: container.superEncoder())
    try UnkeyedSuperPayload(values: unkeyedSuperValues).encode(to: container.superEncoder())
    try singleSuperValue.encode(to: container.superEncoder())
  }

  init(
    keyedValue: Int,
    nestedString: String,
    nestedInt: Int,
    keyedSuperValue: Int,
    unkeyedSuperValues: [Int],
    singleSuperValue: String
  ) {
    self.keyedValue = keyedValue
    self.nestedString = nestedString
    self.nestedInt = nestedInt
    self.keyedSuperValue = keyedSuperValue
    self.unkeyedSuperValues = unkeyedSuperValues
    self.singleSuperValue = singleSuperValue
  }

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()

    let keyedContainer = try container.nestedContainer(keyedBy: UnkeyedNestedCodingKeys.self)
    self.keyedValue = try keyedContainer.decode(Int.self, forKey: .value)

    var nestedUnkeyedContainer = try container.nestedUnkeyedContainer()
    self.nestedString = try nestedUnkeyedContainer.decode(String.self)
    self.nestedInt = try nestedUnkeyedContainer.decode(Int.self)

    self.keyedSuperValue = try KeyedSuperPayload(
      from: container.superDecoder()
    ).value
    self.unkeyedSuperValues = try UnkeyedSuperPayload(
      from: container.superDecoder()
    ).values
    self.singleSuperValue = try String(
      from: container.superDecoder()
    )
  }
}

private struct KeyedSuperPayload: Codable, Equatable {
  let value: Int
}

private struct UnkeyedSuperPayload: Codable, Equatable {
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

private struct UnkeyedOverreadProbe: Decodable {
  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    _ = try container.decode(Int.self)
    _ = try container.decode(Int.self)
  }
}

// MARK: - Generated Fixtures

private struct UnkeyedSeededGenerator: RandomNumberGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
    return state
  }
}

private func generatedPrimitiveProbes(count: Int) -> [ExplicitUnkeyedPrimitiveProbe] {
  var generator = UnkeyedSeededGenerator(state: 0x0ddc_0ffe_e15e_5eed)
  var result: [ExplicitUnkeyedPrimitiveProbe] = []
  result.reserveCapacity(count)

  for index in 0..<count {
    let int64 = Int64(truncatingIfNeeded: generator.next())
    let uint64 = generator.next()
    let positiveUInt64 = uint64 % 1_000_000_000_000
    result.append(
      ExplicitUnkeyedPrimitiveProbe(
        bool: index.isMultiple(of: 2),
        string: generatedASCIIString(using: &generator, maximumLength: 32),
        double: Double(Int32(truncatingIfNeeded: generator.next())) / 8.0,
        float: Float(Int16(truncatingIfNeeded: generator.next())) / 4.0,
        int: Int(truncatingIfNeeded: int64),
        int8: Int8(truncatingIfNeeded: generator.next()),
        int16: Int16(truncatingIfNeeded: generator.next()),
        int32: Int32(truncatingIfNeeded: generator.next()),
        int64: int64,
        int128: Int128(int64),
        uint: UInt(truncatingIfNeeded: positiveUInt64),
        uint8: UInt8(truncatingIfNeeded: generator.next()),
        uint16: UInt16(truncatingIfNeeded: generator.next()),
        uint32: UInt32(truncatingIfNeeded: generator.next()),
        uint64: positiveUInt64,
        uint128: UInt128(positiveUInt64)
      )
    )
  }

  return result
}

private func generatedNestedProbes(count: Int) -> [ExplicitUnkeyedNestedProbe] {
  var generator = UnkeyedSeededGenerator(state: 0x51a7_c0de_e15e_5eed)
  var result: [ExplicitUnkeyedNestedProbe] = []
  result.reserveCapacity(count)

  for _ in 0..<count {
    let superCount = Int(generator.next() % 12)
    let superValues = (0..<superCount).map { _ in
      Int(truncatingIfNeeded: generator.next()) % 100_000
    }
    result.append(
      ExplicitUnkeyedNestedProbe(
        keyedValue: Int(truncatingIfNeeded: generator.next()) % 100_000,
        nestedString: generatedASCIIString(using: &generator, maximumLength: 24),
        nestedInt: Int(truncatingIfNeeded: generator.next()) % 100_000,
        keyedSuperValue: Int(truncatingIfNeeded: generator.next()) % 100_000,
        unkeyedSuperValues: superValues,
        singleSuperValue: generatedASCIIString(using: &generator, maximumLength: 24)
      )
    )
  }

  return result
}

private func generatedOverreadValues(count: Int) -> [Int] {
  var generator = UnkeyedSeededGenerator(state: 0x0bad_f00d_e15e_5eed)
  return (0..<count).map { _ in
    Int(truncatingIfNeeded: generator.next())
  }
}

private func generatedASCIIString(
  using generator: inout UnkeyedSeededGenerator,
  maximumLength: Int
) -> String {
  let length = Int(generator.next() % UInt64(maximumLength + 1))
  let scalars = (0..<length).map { _ in
    let value = 32 + Int(generator.next() % 95)
    return UnicodeScalar(value == 37 ? 36 : value)!
  }
  return String(String.UnicodeScalarView(scalars))
}
