import Foundation

// MARK: - Deterministic Source

/// A small, fully specified generator so a seed means the same thing forever.
///
/// The standard library's `RandomNumberGenerator` implementations are not a
/// stability contract, and `SystemRandomNumberGenerator` cannot be seeded at
/// all. SplitMix64 is written out here so a recorded seed replays identically
/// across processes, machines, and toolchain updates.
struct SplitMix64: Sendable {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9e37_79b9_7f4a_7c15
    var value = state
    value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
    value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
    return value ^ (value >> 31)
  }

  mutating func integer(upperBound: Int) -> Int {
    precondition(upperBound > 0, "upperBound must be positive.")
    return Int(next() % UInt64(upperBound))
  }

  mutating func integer(in range: ClosedRange<Int>) -> Int {
    range.lowerBound + integer(upperBound: range.count)
  }

  mutating func bool() -> Bool {
    next() & 1 == 0
  }

  mutating func byte() -> UInt8 {
    UInt8(truncatingIfNeeded: next())
  }

  mutating func bytes(count: Int) -> [UInt8] {
    (0..<max(0, count)).map { _ in byte() }
  }

  mutating func element<Element>(from values: [Element]) -> Element {
    precondition(!values.isEmpty, "Cannot choose from an empty collection.")
    return values[integer(upperBound: values.count)]
  }

  mutating func caseValue<Value: CaseIterable>(
    of type: Value.Type
  ) -> Value {
    element(from: Array(Value.allCases))
  }
}

/// Derives a per-case seed from a root seed and a case index.
///
/// Cases are independent, so replaying case 812 never requires generating the
/// 811 before it.
func derivedSeed(root: UInt64, index: Int) -> UInt64 {
  var random = SplitMix64(
    seed: root ^ (UInt64(bitPattern: Int64(index)) &* 0xd6e8_feb8_6659_fd93)
  )
  return random.next()
}

// MARK: - Generator

enum DescriptorGenerator {

  /// The generated case kinds, in a fixed order so a seed and index always
  /// select the same kind.
  private static let kindCount = 10

  static func descriptors(
    seed: UInt64,
    count: Int,
    startingAt offset: Int = 0
  ) -> [ProbeDescriptor] {
    (offset..<(offset + max(0, count))).map { index in
      descriptor(seed: seed, index: index)
    }
  }

  static func descriptor(
    seed: UInt64,
    index: Int
  ) -> ProbeDescriptor {
    let caseSeed = derivedSeed(root: seed, index: index)
    var random = SplitMix64(seed: caseSeed)
    let probe = makeProbe(
      selector: index % kindCount,
      random: &random
    )
    return ProbeDescriptor(
      id: "generated-\(index)",
      origin: "seeded-property-generator",
      seed: caseSeed,
      probe: probe
    )
  }

  private static func makeProbe(
    selector: Int,
    random: inout SplitMix64
  ) -> Probe {
    switch selector {
    case 0:
      return .model(
        ModelProbe(
          strategy: random.caseValue(of: StringStrategy.self),
          value: model(random: &random)
        )
      )
    case 1:
      return .distinctStrings(
        DistinctStringsProbe(
          strategy: random.caseValue(of: StringStrategy.self),
          strings: strings(random: &random)
        )
      )
    case 2:
      return .keyCollision(
        KeyCollisionProbe(
          strategy: random.caseValue(of: KeyStrategy.self),
          keys: strings(random: &random)
        )
      )
    case 3:
      return .graph(graph(random: &random))
    case 4:
      let shape = random.caseValue(of: CycleShape.self)
      return .cycle(
        CycleProbe(
          shape: shape,
          expectation: shape.isCyclic ? .reject : .pass
        )
      )
    case 5:
      let probe = Binary128Probe(
        type: random.caseValue(of: Binary128Type.self),
        bytes: Data(random.bytes(count: binary128ByteCount(random: &random))),
        unaligned: random.bool(),
        expectation: .pass
      )
      return .binary128(
        Binary128Probe(
          type: probe.type,
          bytes: probe.bytes,
          unaligned: probe.unaligned,
          expectation: probe.derivedExpectation
        )
      )
    case 6:
      return .resourceBoundary(resourceBoundary(random: &random))
    case 7:
      return .rawText(
        RawTextProbe(
          location: random.caseValue(of: RawTextLocation.self),
          strategy: random.caseValue(of: RawTextStrategy.self),
          bytes: rawTextBytes(random: &random),
          expectation: .tolerant,
          expectedScalars: nil
        )
      )
    case 8:
      return .pointerCount(pointerCount(random: &random))
    default:
      return .representation(representation(random: &random))
    }
  }

  // MARK: Model

  private static func model(
    random: inout SplitMix64
  ) -> FuzzModel {
    let keys = strings(random: &random)
    var dictionary: [String: Int64] = [:]
    for (index, key) in keys.prefix(8).enumerated() {
      dictionary[key] = Int64(index) ^ Int64(bitPattern: random.next())
    }

    let dataCount = random.integer(upperBound: 65)
    let numberCount = random.integer(upperBound: 17)
    return FuzzModel(
      string: generatedString(random: &random),
      dictionary: dictionary,
      signed: Int64(bitPattern: random.next()),
      unsigned: random.next(),
      // A dyadic rational keeps the descriptor's JSON form exact, so a model
      // case round-trips through its own replay file without drift.
      floatingPoint: Double(Int64(bitPattern: random.next()) % 1_000_000) / 16,
      data: Data(random.bytes(count: dataCount)),
      numbers: (0..<numberCount).map { _ in
        Int32(truncatingIfNeeded: random.next())
      },
      child: random.bool()
        ? FuzzChild(
          label: generatedString(random: &random),
          enabled: random.bool()
        )
        : nil
    )
  }

  // MARK: Strings

  /// Always mixes the historically dangerous atoms into generated string sets so
  /// a random draw cannot lose the cases that actually found defects.
  private static func strings(
    random: inout SplitMix64
  ) -> [String] {
    var strings = HistoricalStrings.generatorAtoms
    let generatedCount = 2 + random.integer(upperBound: 8)
    for _ in 0..<generatedCount {
      strings.append(generatedString(random: &random))
    }
    return Array(Set(strings)).sorted {
      Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8))
    }
  }

  private static func generatedString(
    random: inout SplitMix64
  ) -> String {
    let count = random.integer(upperBound: 17)
    var view = String.UnicodeScalarView()
    for _ in 0..<count {
      view.append(random.element(from: HistoricalStrings.scalarAlphabet))
    }
    return String(view)
  }

  // MARK: Graphs

  private static func graph(
    random: inout SplitMix64
  ) -> GraphProbe {
    let count = 1 + random.integer(upperBound: 16)
    var nodes: [GraphNode] = []
    nodes.reserveCapacity(count)

    for _ in 0..<count {
      switch random.integer(upperBound: 9) {
      case 0:
        nodes.append(.null)
      case 1:
        nodes.append(.bool(random.bool()))
      case 2:
        nodes.append(.signed(Int64(bitPattern: random.next())))
      case 3:
        nodes.append(.unsigned(random.next()))
      case 4:
        nodes.append(
          .double(Double(Int64(bitPattern: random.next()) % 1_000_000) / 32)
        )
      case 5:
        nodes.append(.data(Data(random.bytes(count: random.integer(upperBound: 33)))))
      case 6:
        nodes.append(.string(graphStringBytes(random: &random)))
      case 7:
        let childCount = random.integer(upperBound: 6)
        nodes.append(
          .array((0..<childCount).map { _ in random.integer(upperBound: count) })
        )
      default:
        let childCount = random.integer(upperBound: 6)
        nodes.append(
          .dictionary(
            (0..<childCount).map { childIndex in
              GraphEntry(
                key: graphKeyBytes(index: childIndex, random: &random),
                target: random.integer(upperBound: count)
              )
            }
          )
        )
      }
    }

    return GraphProbe(
      nodes: nodes,
      root: random.integer(upperBound: count)
    )
  }

  private static func graphStringBytes(
    random: inout SplitMix64
  ) -> [UInt8] {
    if random.integer(upperBound: 8) == 0 {
      return random.element(from: HistoricalStrings.invalidUTF8Sequences)
    }
    return Array(generatedString(random: &random).utf8).filter { $0 != 0 }
  }

  private static func graphKeyBytes(
    index: Int,
    random: inout SplitMix64
  ) -> [UInt8] {
    if random.integer(upperBound: 12) == 0 {
      var bytes = random.element(from: HistoricalStrings.invalidUTF8Sequences)
      bytes.append(UInt8(ascii: "0") + UInt8(index % 10))
      return bytes
    }
    return Array("key-\(index)-\(random.integer(upperBound: 4))".utf8)
  }

  // MARK: Boundaries

  /// Concentrates 128-bit lengths on the boundary that matters while still
  /// sampling arbitrary lengths.
  private static func binary128ByteCount(
    random: inout SplitMix64
  ) -> Int {
    random.bool()
      ? random.element(from: [0, 1, 8, 15, 16, 17, 24, 32])
      : random.integer(upperBound: 33)
  }

  private static func resourceBoundary(
    random: inout SplitMix64
  ) -> ResourceBoundaryProbe {
    let resource = random.caseValue(of: ResourceKind.self)
    let limit = random.integer(in: 0...48)
    let delta = random.element(from: [-2, -1, 0, 1, 2])
    let probe = ResourceBoundaryProbe(
      resource: resource,
      limit: limit,
      observed: max(0, limit + delta),
      expectation: .pass
    )
    return ResourceBoundaryProbe(
      resource: probe.resource,
      limit: probe.limit,
      observed: probe.observed,
      expectation: probe.derivedExpectation
    )
  }

  private static func rawTextBytes(
    random: inout SplitMix64
  ) -> [UInt8] {
    var bytes: [UInt8] = []
    let fragmentCount = 1 + random.integer(upperBound: 4)
    for _ in 0..<fragmentCount {
      switch random.integer(upperBound: 4) {
      case 0:
        bytes.append(contentsOf: random.element(from: HistoricalStrings.invalidUTF8Sequences))
      case 1:
        bytes.append(contentsOf: random.element(from: HistoricalStrings.escapeFragments))
      case 2:
        bytes.append(contentsOf: random.bytes(count: random.integer(upperBound: 5)))
      default:
        bytes.append(
          contentsOf: Array(generatedString(random: &random).utf8)
        )
      }
    }
    // Raw XPC text can never carry a null byte; libxpc would truncate it and
    // make the case vacuous instead of hostile.
    return bytes.filter { $0 != 0 }
  }

  private static func pointerCount(
    random: inout SplitMix64
  ) -> PointerCountProbe {
    let probe = PointerCountProbe(
      shape: random.caseValue(of: PointerContainerShape.self),
      suppliesPointer: random.bool(),
      mutable: random.bool(),
      // Never exceeds the probe's initialized extent: a raw pointer carries no
      // extent metadata, so a larger count would be undefined behavior rather
      // than a test.
      count: random.element(from: pointerProbeCountAlphabet),
      expectation: .pass
    )
    return PointerCountProbe(
      shape: probe.shape,
      suppliesPointer: probe.suppliesPointer,
      mutable: probe.mutable,
      count: probe.count,
      expectation: probe.derivedExpectation
    )
  }

  private static func representation(
    random: inout SplitMix64
  ) -> RepresentationProbe {
    RepresentationProbe(
      kind: random.caseValue(of: RepresentationKind.self),
      bytes: Data(random.bytes(count: random.integer(upperBound: 33))),
      signed: Int64(bitPattern: random.next()),
      unsigned: random.next(),
      floatBits: UInt32(truncatingIfNeeded: random.next()),
      doubleBits: random.next()
    )
  }

}
