import Foundation
import Testing
import XPC
@testable import XPCCoding

@Suite("Same-Build Representation Fixtures")
struct RepresentationFixtureTests {

  @Test
  func `reviewed fixture names are unique`() {
    let fixtures = representationFixtures()

    #expect(
      Set(fixtures.map(\.name)).count == fixtures.count,
      "Every review-visible representation fixture must have a unique name."
    )
  }

  @Test
  func `encoder output matches reviewed complete XPC trees`() {
    let fixtures = representationFixtures()
    for fixture in fixtures {
      do {
        let encodedObject = try fixture.encode()
        let actualStructure = try XPCStructuralFixture(
          inspecting: encodedObject
        )
        #expect(
          actualStructure == fixture.expectedStructure,
          """
          Encoder structure drifted for fixture \(fixture.name).
          Expected:
          \(fixture.expectedStructure)
          Actual:
          \(actualStructure)
          """
        )
      } catch {
        Issue.record(
          """
          Encoding or inspecting fixture \(fixture.name) threw unexpectedly: \
          \(String(reflecting: error)).
          """
        )
      }
    }
  }

  @Test
  func `decoder accepts independently-constructed reviewed XPC trees`() {
    let fixtures = representationFixtures()
    for fixture in fixtures {
      do {
        let directlyConstructedObject =
          try fixture.expectedStructure.makeXPCObject()
        #expect(
          try fixture.decodedValueMatches(directlyConstructedObject),
          """
          Decoder did not accept the independently constructed XPC tree for \
          fixture \(fixture.name).
          """
        )
      } catch {
        Issue.record(
          """
          Constructing or decoding fixture \(fixture.name) threw unexpectedly: \
          \(String(reflecting: error)).
          """
        )
      }
    }
  }

  @Test
  func `dictionary inspection and rendering are deterministic`() throws {
    let fixture = try #require(
      representationFixtures().first {
        $0.name == "containers/nested"
      }
    )

    let firstStructure = try XPCStructuralFixture(
      inspecting: fixture.encode()
    )
    let firstRendering = firstStructure.description
    for _ in 0..<32 {
      let repeatedStructure = try XPCStructuralFixture(
        inspecting: fixture.encode()
      )
      #expect(repeatedStructure == firstStructure)
      #expect(repeatedStructure.description == firstRendering)
    }
  }

  @Test
  func `type and byte mutations are detected in both directions`() throws {
    let fixture = representationFixture(
      name: "mutation/data-control",
      value: Data([0x00, 0x01, 0xff]),
      expectedStructure: .data([0x00, 0x01, 0xff])
    )
    let actualStructure = try XPCStructuralFixture(
      inspecting: fixture.encode()
    )
    let byteMutation = XPCStructuralFixture.data([0x00, 0x02, 0xff])

    #expect(actualStructure != byteMutation)
    #expect(
      try !fixture.decodedValueMatches(
        byteMutation.makeXPCObject()
      )
    )

    let typeMutation = try XPCStructuralFixture.string("17")
      .makeXPCObject()
    let error = try #require(throws: DecodingError.self) {
      _ = try XPCDecoder.standard.decode(
        Int.self,
        from: typeMutation
      )
    }
    guard case .typeMismatch(let requestedType, let context) = error else {
      Issue.record(
        "Expected the mutated XPC kind to produce typeMismatch."
      )
      return
    }
    #expect(ObjectIdentifier(requestedType) == ObjectIdentifier(Int.self))
    #expect(context.codingPath.isEmpty)
  }

  @Test
  func `throw-on-discovery rejects the unrepresentable null string`() throws {
    let configuration = fixtureConfiguration(
      valueStrategy: .throwOnDiscovery
    )
    let error = try #require(throws: EncodingError.self) {
      _ = try XPCEncoder(configuration: configuration).encode("A\0B")
    }
    guard case .invalidValue = error else {
      Issue.record(
        "Expected throwOnDiscovery to report EncodingError.invalidValue."
      )
      return
    }
  }

}

// MARK: - Type-Erased Fixture

private struct RepresentationFixture {

  let name: String
  let expectedStructure: XPCStructuralFixture
  let encode: () throws -> xpc_object_t
  let decodedValueMatches: (xpc_object_t) throws -> Bool

  init<Value: Codable>(
    name: String,
    value: Value,
    configuration: XPCCodec.Configuration,
    expectedStructure: XPCStructuralFixture,
    valuesEquivalent: @escaping (Value, Value) -> Bool
  ) {
    self.name = name
    self.expectedStructure = expectedStructure
    self.encode = {
      try XPCEncoder(configuration: configuration).encode(value)
    }
    self.decodedValueMatches = { object in
      let decoded = try XPCDecoder(
        configuration: configuration
      ).decode(
        Value.self,
        from: object
      )
      return valuesEquivalent(decoded, value)
    }
  }

}

private func representationFixture<Value: Codable & Equatable>(
  name: String,
  value: Value,
  configuration: XPCCodec.Configuration = fixtureConfiguration(),
  expectedStructure: XPCStructuralFixture
) -> RepresentationFixture {
  RepresentationFixture(
    name: name,
    value: value,
    configuration: configuration,
    expectedStructure: expectedStructure,
    valuesEquivalent: ==
  )
}

private func representationFixtures() -> [RepresentationFixture] {
  primitiveRepresentationFixtures()
    + floatingPointRepresentationFixtures()
    + stringRepresentationFixtures()
    + containerRepresentationFixtures()
    + standardLibraryRepresentationFixtures()
    + enhancedHelperRepresentationFixtures()
}

// MARK: - Primitive Fixtures

private func primitiveRepresentationFixtures() -> [RepresentationFixture] {
  [
    representationFixture(
      name: "primitive/null",
      value: Optional<Int>.none,
      expectedStructure: .null
    ),
    representationFixture(
      name: "primitive/optional-some",
      value: Optional<Int>.some(7),
      expectedStructure: .int64(7)
    ),
    representationFixture(
      name: "primitive/bool-false",
      value: false,
      expectedStructure: .bool(false)
    ),
    representationFixture(
      name: "primitive/bool-true",
      value: true,
      expectedStructure: .bool(true)
    ),
    signedIntegerFixture("Int/min", Int.min),
    signedIntegerFixture("Int/max", Int.max),
    signedIntegerFixture("Int8/min", Int8.min),
    signedIntegerFixture("Int8/max", Int8.max),
    signedIntegerFixture("Int16/min", Int16.min),
    signedIntegerFixture("Int16/max", Int16.max),
    signedIntegerFixture("Int32/min", Int32.min),
    signedIntegerFixture("Int32/max", Int32.max),
    signedIntegerFixture("Int64/min", Int64.min),
    signedIntegerFixture("Int64/max", Int64.max),
    unsignedIntegerFixture("UInt/zero", UInt.zero),
    unsignedIntegerFixture("UInt/max", UInt.max),
    unsignedIntegerFixture("UInt8/zero", UInt8.zero),
    unsignedIntegerFixture("UInt8/max", UInt8.max),
    unsignedIntegerFixture("UInt16/zero", UInt16.zero),
    unsignedIntegerFixture("UInt16/max", UInt16.max),
    unsignedIntegerFixture("UInt32/zero", UInt32.zero),
    unsignedIntegerFixture("UInt32/max", UInt32.max),
    unsignedIntegerFixture("UInt64/zero", UInt64.zero),
    unsignedIntegerFixture("UInt64/max", UInt64.max),
    representationFixture(
      name: "primitive/Int128/min",
      value: Int128.min,
      expectedStructure: .data(targetNativeBytes(of: Int128.min))
    ),
    representationFixture(
      name: "primitive/Int128/max",
      value: Int128.max,
      expectedStructure: .data(targetNativeBytes(of: Int128.max))
    ),
    representationFixture(
      name: "primitive/UInt128/zero",
      value: UInt128.zero,
      expectedStructure: .data(targetNativeBytes(of: UInt128.zero))
    ),
    representationFixture(
      name: "primitive/UInt128/max",
      value: UInt128.max,
      expectedStructure: .data(targetNativeBytes(of: UInt128.max))
    ),
    representationFixture(
      name: "primitive/Data/empty",
      value: Data(),
      expectedStructure: .data([])
    ),
    representationFixture(
      name: "primitive/Data/nonempty",
      value: Data([0x00, 0x01, 0x7f, 0x80, 0xff]),
      expectedStructure: .data([0x00, 0x01, 0x7f, 0x80, 0xff])
    ),
  ]
}

private func signedIntegerFixture<Value>(
  _ name: String,
  _ value: Value
) -> RepresentationFixture
where Value: Codable & Equatable & BinaryInteger {
  representationFixture(
    name: "primitive/\(name)",
    value: value,
    expectedStructure: .int64(Int64(value))
  )
}

private func unsignedIntegerFixture<Value>(
  _ name: String,
  _ value: Value
) -> RepresentationFixture
where Value: Codable & Equatable & UnsignedInteger {
  representationFixture(
    name: "primitive/\(name)",
    value: value,
    expectedStructure: .uint64(UInt64(value))
  )
}

private func targetNativeBytes<Value>(
  of value: Value
) -> [UInt8] {
  withUnsafeBytes(of: value) {
    Array($0)
  }
}

// MARK: - Floating-Point Fixtures

private func floatingPointRepresentationFixtures() -> [RepresentationFixture] {
  let float16Values: [(String, Float16)] = [
    ("negative-greatest", -Float16.greatestFiniteMagnitude),
    ("negative-least-nonzero", -Float16.leastNonzeroMagnitude),
    ("negative-zero", -0.0),
    ("positive-zero", 0.0),
    ("least-nonzero", Float16.leastNonzeroMagnitude),
    ("greatest", Float16.greatestFiniteMagnitude),
    ("negative-infinity", -.infinity),
    ("positive-infinity", .infinity),
    ("nan", .nan),
  ]
  let floatValues: [(String, Float)] = [
    ("negative-greatest", -Float.greatestFiniteMagnitude),
    ("negative-least-nonzero", -Float.leastNonzeroMagnitude),
    ("negative-zero", -0.0),
    ("positive-zero", 0.0),
    ("least-nonzero", Float.leastNonzeroMagnitude),
    ("greatest", Float.greatestFiniteMagnitude),
    ("negative-infinity", -.infinity),
    ("positive-infinity", .infinity),
    ("nan", .nan),
  ]
  let doubleValues: [(String, Double)] = [
    ("negative-greatest", -Double.greatestFiniteMagnitude),
    ("negative-least-nonzero", -Double.leastNonzeroMagnitude),
    ("negative-zero", -0.0),
    ("positive-zero", 0.0),
    ("least-nonzero", Double.leastNonzeroMagnitude),
    ("greatest", Double.greatestFiniteMagnitude),
    ("negative-infinity", -.infinity),
    ("positive-infinity", .infinity),
    ("nan", .nan),
  ]

  return float16Values.map(float16Fixture)
    + floatValues.map(floatFixture)
    + doubleValues.map(doubleFixture)
}

private func float16Fixture(
  _ nameAndValue: (name: String, value: Float16)
) -> RepresentationFixture {
  RepresentationFixture(
    name: "primitive/Float16/\(nameAndValue.name)",
    value: nameAndValue.value,
    configuration: fixtureConfiguration(),
    expectedStructure: .double(Double(nameAndValue.value)),
    valuesEquivalent: sameFloat16
  )
}

private func floatFixture(
  _ nameAndValue: (name: String, value: Float)
) -> RepresentationFixture {
  RepresentationFixture(
    name: "primitive/Float/\(nameAndValue.name)",
    value: nameAndValue.value,
    configuration: fixtureConfiguration(),
    expectedStructure: .double(Double(nameAndValue.value)),
    valuesEquivalent: sameFloat
  )
}

private func doubleFixture(
  _ nameAndValue: (name: String, value: Double)
) -> RepresentationFixture {
  RepresentationFixture(
    name: "primitive/Double/\(nameAndValue.name)",
    value: nameAndValue.value,
    configuration: fixtureConfiguration(),
    expectedStructure: .double(nameAndValue.value),
    valuesEquivalent: sameDouble
  )
}

private func sameFloat16(
  _ lhs: Float16,
  _ rhs: Float16
) -> Bool {
  lhs.isNaN && rhs.isNaN
    || lhs.bitPattern == rhs.bitPattern
}

private func sameFloat(
  _ lhs: Float,
  _ rhs: Float
) -> Bool {
  lhs.isNaN && rhs.isNaN
    || lhs.bitPattern == rhs.bitPattern
}

private func sameDouble(
  _ lhs: Double,
  _ rhs: Double
) -> Bool {
  lhs.isNaN && rhs.isNaN
    || lhs.bitPattern == rhs.bitPattern
}

// MARK: - String Fixtures

private func stringRepresentationFixtures() -> [RepresentationFixture] {
  let nullAndPercent = "A%\0B"
  return [
    representationFixture(
      name: "string/value/assume-absent",
      value: "A%B",
      configuration: fixtureConfiguration(
        valueStrategy: .assumeAbsent
      ),
      expectedStructure: .string("A%B")
    ),
    representationFixture(
      name: "string/value/throw-on-discovery-success",
      value: "A%B",
      configuration: fixtureConfiguration(
        valueStrategy: .throwOnDiscovery
      ),
      expectedStructure: .string("A%B")
    ),
    representationFixture(
      name: "string/value/percent-escape",
      value: nullAndPercent,
      configuration: fixtureConfiguration(
        valueStrategy: .percentEscape
      ),
      expectedStructure: .string("A%25%00B")
    ),
    representationFixture(
      name: "string/value/percent-escape-literal-sequences",
      value: "literal-%00-%25",
      configuration: fixtureConfiguration(
        valueStrategy: .percentEscape
      ),
      expectedStructure: .string("literal-%2500-%2525")
    ),
    representationFixture(
      name: "string/value/data-utf8",
      value: nullAndPercent,
      configuration: fixtureConfiguration(
        valueStrategy: .useDataRepresentation(.utf8)
      ),
      expectedStructure: .data([
        0x41, 0x25, 0x00, 0x42,
      ])
    ),
    representationFixture(
      name: "string/value/data-utf16",
      value: nullAndPercent,
      configuration: fixtureConfiguration(
        valueStrategy: .useDataRepresentation(.utf16)
      ),
      expectedStructure: .data([
        0xff, 0xfe,
        0x41, 0x00,
        0x25, 0x00,
        0x00, 0x00,
        0x42, 0x00,
      ])
    ),
    representationFixture(
      name: "string/value/data-utf32",
      value: nullAndPercent,
      configuration: fixtureConfiguration(
        valueStrategy: .useDataRepresentation(.utf32)
      ),
      expectedStructure: .data([
        0xff, 0xfe, 0x00, 0x00,
        0x41, 0x00, 0x00, 0x00,
        0x25, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x42, 0x00, 0x00, 0x00,
      ])
    ),
    representationFixture(
      name: "string/key/assume-absent",
      value: ["A%B": 7],
      configuration: fixtureConfiguration(
        keyStrategy: .assumeAbsent
      ),
      expectedStructure: .dictionary([
        "A%B": .int64(7)
      ])
    ),
    representationFixture(
      name: "string/key/percent-escape",
      value: [nullAndPercent: 7],
      configuration: fixtureConfiguration(
        keyStrategy: .percentEscape
      ),
      expectedStructure: .dictionary([
        "A%25%00B": .int64(7)
      ])
    ),
    representationFixture(
      name: "string/key/percent-escape-literal-sequences",
      value: ["literal-%00-%25": 7],
      configuration: fixtureConfiguration(
        keyStrategy: .percentEscape
      ),
      expectedStructure: .dictionary([
        "literal-%2500-%2525": .int64(7)
      ])
    ),
  ]
}

// MARK: - Container Fixtures

private func containerRepresentationFixtures() -> [RepresentationFixture] {
  [
    representationFixture(
      name: "containers/array",
      value: [1, 2, 3],
      expectedStructure: .array([
        .int64(1),
        .int64(2),
        .int64(3),
      ])
    ),
    representationFixture(
      name: "containers/unkeyed-optionals",
      value: [Optional<Int>.none, .some(1)],
      expectedStructure: .array([
        .null,
        .int64(1),
      ])
    ),
    representationFixture(
      name: "containers/string-keyed-dictionary",
      value: ["b": 2, "a": 1],
      expectedStructure: .dictionary([
        "a": .int64(1),
        "b": .int64(2),
      ])
    ),
    representationFixture(
      name: "containers/integer-keyed-dictionary",
      value: [7: "seven"],
      expectedStructure: .dictionary([
        "7": .string("seven")
      ])
    ),
    representationFixture(
      name: "containers/non-keyed-dictionary",
      value: [true: 9],
      expectedStructure: .array([
        .bool(true),
        .int64(9),
      ])
    ),
    representationFixture(
      name: "containers/set-single-element",
      value: Set([7]),
      expectedStructure: .array([
        .int64(7)
      ])
    ),
    representationFixture(
      name: "containers/synthesized-optional-omission",
      value: SynthesizedOptionalFixture(value: nil),
      expectedStructure: .dictionary([:])
    ),
    representationFixture(
      name: "containers/explicit-keyed-null",
      value: ExplicitOptionalFixture(),
      expectedStructure: .dictionary([
        "explicit": .null
      ])
    ),
    representationFixture(
      name: "containers/nested",
      value: NestedRepresentationFixture(
        label: "root",
        child: NestedRepresentationChild(
          count: 2,
          values: [3, 5]
        )
      ),
      expectedStructure: .dictionary([
        "child": .dictionary([
          "count": .int64(2),
          "values": .array([
            .int64(3),
            .int64(5),
          ]),
        ]),
        "label": .string("root"),
      ])
    ),
    RepresentationFixture(
      name: "containers/inheritance-super",
      value: RepresentationChild(
        base: 7,
        child: "leaf"
      ),
      configuration: fixtureConfiguration(),
      expectedStructure: .dictionary([
        "child": .string("leaf"),
        "super": .dictionary([
          "base": .int64(7)
        ]),
      ]),
      valuesEquivalent: ==
    ),
  ]
}

// MARK: - Standard-Library Fixtures

private func standardLibraryRepresentationFixtures() -> [RepresentationFixture] {
  let zeroUUID = UUID(
    uuid: (
      0, 0, 0, 0,
      0, 0, 0, 0,
      0, 0, 0, 0,
      0, 0, 0, 0
    )
  )
  guard let absoluteURL = URL(string: "https://example.com/a") else {
    preconditionFailure("The fixture URL literal must remain valid.")
  }
  return [
    representationFixture(
      name: "standard-library/Date",
      value: Date(timeIntervalSinceReferenceDate: 0),
      expectedStructure: .double(0)
    ),
    representationFixture(
      name: "standard-library/UUID",
      value: zeroUUID,
      expectedStructure: .string(
        "00000000-0000-0000-0000-000000000000"
      )
    ),
    representationFixture(
      name: "standard-library/URL",
      value: absoluteURL,
      expectedStructure: .dictionary([
        "relative": .string("https://example.com/a")
      ])
    ),
    representationFixture(
      name: "standard-library/Decimal",
      value: Decimal(1),
      expectedStructure: .dictionary([
        "exponent": .int64(0),
        "isCompact": .bool(true),
        "isNegative": .bool(false),
        "length": .uint64(1),
        "mantissa": .array([
          .uint64(1),
          .uint64(0),
          .uint64(0),
          .uint64(0),
          .uint64(0),
          .uint64(0),
          .uint64(0),
          .uint64(0),
        ]),
      ])
    ),
  ]
}

// MARK: - Enhanced-Helper Fixtures

private func enhancedHelperRepresentationFixtures() -> [RepresentationFixture] {
  [
    representationFixture(
      name: "enhanced/binary-data",
      value: BinaryHelperRepresentationFixture(
        bytes: [0x00, 0x01, 0xfe, 0xff]
      ),
      expectedStructure: .data([0x00, 0x01, 0xfe, 0xff])
    ),
    representationFixture(
      name: "enhanced/elements",
      value: ElementHelperRepresentationFixture(
        values: [-1, 0, 1]
      ),
      expectedStructure: .dictionary([
        "values": .array([
          .int64(-1),
          .int64(0),
          .int64(1),
        ])
      ])
    ),
  ]
}

// MARK: - Configurations

private func fixtureConfiguration(
  keyStrategy: XPCCodec.StringKeyStrategy = .percentEscape,
  valueStrategy: XPCCodec.StringValueStrategy = .percentEscape
) -> XPCCodec.Configuration {
  XPCCodec.Configuration(
    stringKeyStrategy: keyStrategy,
    stringValueStrategy: valueStrategy
  )
}

// MARK: - Container Models

private struct SynthesizedOptionalFixture: Codable, Equatable {
  let value: Int?
}

private struct ExplicitOptionalFixture: Codable, Equatable {

  let omitted: Int?
  let explicit: Int?

  init() {
    self.omitted = nil
    self.explicit = nil
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(
      keyedBy: CodingKeys.self
    )
    self.omitted = try container.decodeIfPresent(
      Int.self,
      forKey: .omitted
    )
    self.explicit = try container.decodeIfPresent(
      Int.self,
      forKey: .explicit
    )
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(
      keyedBy: CodingKeys.self
    )
    try container.encodeNil(forKey: .explicit)
  }

  private enum CodingKeys: String, CodingKey {
    case omitted
    case explicit
  }

}

private struct NestedRepresentationFixture: Codable, Equatable {
  let label: String
  let child: NestedRepresentationChild
}

private struct NestedRepresentationChild: Codable, Equatable {
  let count: Int
  let values: [Int]
}

private class RepresentationBase: Codable {

  let base: Int

  init(base: Int) {
    self.base = base
  }

  required init(from decoder: any Decoder) throws {
    let container = try decoder.container(
      keyedBy: CodingKeys.self
    )
    self.base = try container.decode(
      Int.self,
      forKey: .base
    )
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(
      keyedBy: CodingKeys.self
    )
    try container.encode(
      base,
      forKey: .base
    )
  }

  private enum CodingKeys: String, CodingKey {
    case base
  }

}

private final class RepresentationChild: RepresentationBase {

  let child: String

  init(
    base: Int,
    child: String
  ) {
    self.child = child
    super.init(base: base)
  }

  required init(from decoder: any Decoder) throws {
    let container = try decoder.container(
      keyedBy: CodingKeys.self
    )
    self.child = try container.decode(
      String.self,
      forKey: .child
    )
    try super.init(
      from: container.superDecoder()
    )
  }

  override func encode(to encoder: any Encoder) throws {
    var container = encoder.container(
      keyedBy: CodingKeys.self
    )
    try container.encode(
      child,
      forKey: .child
    )
    try super.encode(
      to: container.superEncoder()
    )
  }

  static func == (
    lhs: RepresentationChild,
    rhs: RepresentationChild
  ) -> Bool {
    lhs.base == rhs.base
      && lhs.child == rhs.child
  }

  private enum CodingKeys: String, CodingKey {
    case child
  }

}

// MARK: - Enhanced-Helper Models

private struct BinaryHelperRepresentationFixture: Codable, Equatable {

  let bytes: [UInt8]

  init(bytes: [UInt8]) {
    self.bytes = bytes
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.bytes = Array(
      try container.decode(Data.self)
    )
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try bytes.withUnsafeBytes { buffer in
      try container.efficientlyEncodeBinaryData(buffer)
    }
  }

}

private struct ElementHelperRepresentationFixture: Codable, Equatable {

  let values: [Int]

  init(values: [Int]) {
    self.values = values
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(
      keyedBy: CodingKeys.self
    )
    self.values = try container.decode(
      [Int].self,
      forKey: .values
    )
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(
      keyedBy: CodingKeys.self
    )
    try values.withUnsafeBufferPointer { buffer in
      try container.efficientlyEncodeElements(
        buffer,
        forKey: .values
      )
    }
  }

  private enum CodingKeys: String, CodingKey {
    case values
  }

}
