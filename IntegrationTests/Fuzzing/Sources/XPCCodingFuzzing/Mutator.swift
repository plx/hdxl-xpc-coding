import Foundation

// MARK: - Normalization

extension Probe {

  /// The same probe with its stored expectation replaced by the one its content
  /// implies.
  ///
  /// Mutation must never inherit an ancestor's verdict: a case that changed its
  /// own byte count or budget has a different correct answer. Normalizing keeps
  /// every reported failure a real contract violation.
  var normalized: Probe {
    switch self {
    case .binary128(let probe):
      .binary128(
        Binary128Probe(
          type: probe.type,
          bytes: probe.bytes,
          unaligned: probe.unaligned,
          expectation: probe.derivedExpectation
        )
      )
    case .resourceBoundary(let probe):
      .resourceBoundary(
        ResourceBoundaryProbe(
          resource: probe.resource,
          limit: probe.limit,
          observed: probe.observed,
          expectation: probe.derivedExpectation
        )
      )
    case .pointerCount(let probe):
      .pointerCount(
        PointerCountProbe(
          shape: probe.shape,
          suppliesPointer: probe.suppliesPointer,
          mutable: probe.mutable,
          count: probe.count,
          expectation: probe.derivedExpectation
        )
      )
    case .cycle(let probe):
      .cycle(
        CycleProbe(
          shape: probe.shape,
          expectation: probe.derivedExpectation
        )
      )
    case .model, .distinctStrings, .keyCollision, .graph, .representation,
      .rawText, .deliberateHang:
      // These carry no expectation their own content determines, so there is
      // nothing to recompute. A raw-text verdict in particular depends on the
      // UTF-8 and escape grammar rather than on any countable property, so the
      // caller that changed the bytes is responsible for weakening it.
      self
    }
  }

}

// MARK: - Mutator

/// Derives new hostile cases by structurally mutating existing ones.
///
/// Mutation works on the typed descriptor rather than its JSON bytes, so every
/// derived case remains a well-formed instruction the child can execute. The
/// hostility comes from the values, not from a corrupt descriptor.
enum DescriptorMutator {

  static func mutations(
    of sources: [ProbeDescriptor],
    seed: UInt64,
    count: Int,
    startingAt offset: Int = 0
  ) -> [ProbeDescriptor] {
    guard !sources.isEmpty else {
      return []
    }
    return (offset..<(offset + max(0, count))).map { index in
      mutation(
        of: sources[index % sources.count],
        seed: seed,
        index: index
      )
    }
  }

  static func mutation(
    of source: ProbeDescriptor,
    seed: UInt64,
    index: Int
  ) -> ProbeDescriptor {
    let caseSeed = derivedSeed(root: seed ^ 0x5bf0_3635_ca6d_1d1d, index: index)
    var random = SplitMix64(seed: caseSeed)
    var probe = source.probe
    let roundCount = 1 + random.integer(upperBound: 3)
    for _ in 0..<roundCount {
      probe = mutate(probe, random: &random)
    }
    return ProbeDescriptor(
      id: "mutated-\(index)",
      origin: "seeded-mutation of \(source.id)",
      seed: caseSeed,
      probe: probe.normalized
    )
  }

  // MARK: Dispatch

  private static func mutate(
    _ probe: Probe,
    random: inout SplitMix64
  ) -> Probe {
    switch probe {
    case .model(let value):
      return .model(
        ModelProbe(
          strategy: random.bool()
            ? random.caseValue(of: StringStrategy.self)
            : value.strategy,
          value: mutate(value.value, random: &random)
        )
      )

    case .distinctStrings(let value):
      return .distinctStrings(
        DistinctStringsProbe(
          strategy: random.bool()
            ? random.caseValue(of: StringStrategy.self)
            : value.strategy,
          strings: mutate(value.strings, random: &random)
        )
      )

    case .keyCollision(let value):
      return .keyCollision(
        KeyCollisionProbe(
          strategy: random.bool()
            ? random.caseValue(of: KeyStrategy.self)
            : value.strategy,
          keys: mutate(value.keys, random: &random)
        )
      )

    case .graph(let value):
      return .graph(mutate(value, random: &random))

    case .cycle:
      return .cycle(
        CycleProbe(
          shape: random.caseValue(of: CycleShape.self),
          expectation: .tolerant
        )
      )

    case .binary128(let value):
      return .binary128(
        Binary128Probe(
          type: random.bool() ? random.caseValue(of: Binary128Type.self) : value.type,
          bytes: Data(mutate(Array(value.bytes), limit: 64, random: &random)),
          unaligned: random.bool() ? !value.unaligned : value.unaligned,
          expectation: value.expectation
        )
      )

    case .resourceBoundary(let value):
      return .resourceBoundary(mutate(value, random: &random))

    case .rawText(let value):
      let bytes = mutate(value.bytes, limit: 64, random: &random)
        .filter { $0 != 0 }
      return .rawText(
        RawTextProbe(
          location: random.bool()
            ? random.caseValue(of: RawTextLocation.self)
            : value.location,
          strategy: random.bool()
            ? random.caseValue(of: RawTextStrategy.self)
            : value.strategy,
          bytes: bytes,
          // The reviewed decoded text no longer describes these bytes.
          expectation: .tolerant,
          expectedScalars: nil
        )
      )

    case .pointerCount(let value):
      return .pointerCount(
        PointerCountProbe(
          shape: random.bool()
            ? random.caseValue(of: PointerContainerShape.self)
            : value.shape,
          suppliesPointer: random.bool() ? !value.suppliesPointer : value.suppliesPointer,
          mutable: random.bool() ? !value.mutable : value.mutable,
          count: random.bool()
            ? random.element(from: pointerProbeCountAlphabet)
            : value.count,
          expectation: value.expectation
        )
      )

    case .representation(let value):
      return .representation(
        RepresentationProbe(
          kind: random.bool() ? random.caseValue(of: RepresentationKind.self) : value.kind,
          bytes: Data(mutate(Array(value.bytes), limit: 64, random: &random)),
          signed: random.bool() ? Int64(bitPattern: random.next()) : value.signed,
          unsigned: random.bool() ? random.next() : value.unsigned,
          floatBits: random.bool()
            ? UInt32(truncatingIfNeeded: random.next())
            : value.floatBits,
          doubleBits: random.bool() ? random.next() : value.doubleBits
        )
      )

    case .deliberateHang:
      // Mutating the hanger into the ordinary population would make every
      // campaign time out. Replace it with an arbitrary hostile graph instead.
      return .rawText(
        RawTextProbe(
          location: random.caseValue(of: RawTextLocation.self),
          strategy: random.caseValue(of: RawTextStrategy.self),
          bytes: random.bytes(count: 8).filter { $0 != 0 },
          expectation: .tolerant,
          expectedScalars: nil
        )
      )
    }
  }

  // MARK: Component Mutation

  private static func mutate(
    _ model: FuzzModel,
    random: inout SplitMix64
  ) -> FuzzModel {
    var dictionary = model.dictionary
    switch random.integer(upperBound: 3) {
    case 0:
      dictionary[mutate(model.string, random: &random)] =
        Int64(bitPattern: random.next())
    case 1:
      if let key = dictionary.keys.sorted().first {
        dictionary.removeValue(forKey: key)
      }
    default:
      break
    }

    return FuzzModel(
      string: mutate(model.string, random: &random),
      dictionary: dictionary,
      signed: random.bool() ? Int64(bitPattern: random.next()) : model.signed,
      unsigned: random.bool() ? random.next() : model.unsigned,
      floatingPoint: random.bool()
        ? Double(Int64(bitPattern: random.next()) % 1_000_000) / 16
        : model.floatingPoint,
      data: Data(mutate(Array(model.data), limit: 128, random: &random)),
      numbers: mutate(model.numbers, random: &random),
      child: random.bool()
        ? (model.child == nil
          ? FuzzChild(label: mutate("", random: &random), enabled: random.bool())
          : nil)
        : model.child
    )
  }

  private static func mutate(
    _ strings: [String],
    random: inout SplitMix64
  ) -> [String] {
    var result = strings
    switch random.integer(upperBound: 3) {
    case 0 where result.count < 24:
      result.append(
        random.bool()
          ? random.element(from: HistoricalStrings.generatorAtoms)
          : mutate(result.isEmpty ? "" : random.element(from: result), random: &random)
      )
    case 1 where result.count > 1:
      result.remove(at: random.integer(upperBound: result.count))
    default:
      guard !result.isEmpty else {
        break
      }
      let index = random.integer(upperBound: result.count)
      result[index] = mutate(result[index], random: &random)
    }
    return result
  }

  private static func mutate(
    _ string: String,
    random: inout SplitMix64
  ) -> String {
    var scalars = Array(string.unicodeScalars)
    switch random.integer(upperBound: 4) {
    case 0 where scalars.count < 32:
      scalars.insert(
        random.element(from: HistoricalStrings.scalarAlphabet),
        at: random.integer(upperBound: scalars.count + 1)
      )
    case 1 where !scalars.isEmpty:
      scalars.remove(at: random.integer(upperBound: scalars.count))
    case 2 where !scalars.isEmpty:
      scalars[random.integer(upperBound: scalars.count)] = random.element(
        from: HistoricalStrings.scalarAlphabet
      )
    default:
      scalars.append(contentsOf: scalars.prefix(4))
    }
    var view = String.UnicodeScalarView()
    for scalar in scalars.prefix(32) {
      view.append(scalar)
    }
    return String(view)
  }

  private static func mutate(
    _ bytes: [UInt8],
    limit: Int,
    random: inout SplitMix64
  ) -> [UInt8] {
    var result = bytes
    switch random.integer(upperBound: 5) {
    case 0 where result.count < limit:
      result.append(random.byte())
    case 1 where !result.isEmpty:
      result.remove(at: random.integer(upperBound: result.count))
    case 2 where !result.isEmpty:
      result[random.integer(upperBound: result.count)] ^= 1 << random.integer(upperBound: 8)
    case 3 where result.count < limit:
      result.append(
        contentsOf: random.element(from: HistoricalStrings.invalidUTF8Sequences)
      )
    default:
      result = Array(result.prefix(random.integer(upperBound: result.count + 1)))
    }
    return Array(result.prefix(limit))
  }

  private static func mutate(
    _ numbers: [Int32],
    random: inout SplitMix64
  ) -> [Int32] {
    var result = numbers
    switch random.integer(upperBound: 3) {
    case 0 where result.count < 32:
      result.append(Int32(truncatingIfNeeded: random.next()))
    case 1 where !result.isEmpty:
      result.remove(at: random.integer(upperBound: result.count))
    default:
      guard !result.isEmpty else {
        break
      }
      result[random.integer(upperBound: result.count)] = Int32(
        truncatingIfNeeded: random.next()
      )
    }
    return result
  }

  private static func mutate(
    _ graph: GraphProbe,
    random: inout SplitMix64
  ) -> GraphProbe {
    var nodes = graph.nodes
    switch random.integer(upperBound: 4) {
    case 0 where nodes.count < 24:
      nodes.append(randomNode(nodeCount: nodes.count + 1, random: &random))
    case 1 where nodes.count > 1:
      nodes.remove(at: random.integer(upperBound: nodes.count))
    case 2 where !nodes.isEmpty:
      nodes[random.integer(upperBound: nodes.count)] = randomNode(
        nodeCount: nodes.count,
        random: &random
      )
    default:
      break
    }
    if nodes.isEmpty {
      nodes.append(.null)
    }
    return sanitized(
      GraphProbe(
        nodes: nodes,
        root: random.integer(upperBound: nodes.count)
      )
    )
  }

  private static func randomNode(
    nodeCount: Int,
    random: inout SplitMix64
  ) -> GraphNode {
    switch random.integer(upperBound: 9) {
    case 0:
      return .null
    case 1:
      return .bool(random.bool())
    case 2:
      return .signed(Int64(bitPattern: random.next()))
    case 3:
      return .unsigned(random.next())
    case 4:
      return .double(Double(Int64(bitPattern: random.next()) % 1_000_000) / 32)
    case 5:
      return .data(Data(random.bytes(count: random.integer(upperBound: 33))))
    case 6:
      return .string(
        random.bool()
          ? random.element(from: HistoricalStrings.invalidUTF8Sequences)
          : random.bytes(count: random.integer(upperBound: 9)).filter { $0 != 0 }
      )
    case 7:
      let childCount = random.integer(upperBound: 6)
      return .array(
        (0..<childCount).map { _ in random.integer(upperBound: max(1, nodeCount)) }
      )
    default:
      let childCount = random.integer(upperBound: 6)
      return .dictionary(
        (0..<childCount).map { index in
          GraphEntry(
            key: Array("key-\(index)".utf8),
            target: random.integer(upperBound: max(1, nodeCount))
          )
        }
      )
    }
  }

  /// Clamps every node index into range so a mutated graph is always buildable.
  static func sanitized(_ graph: GraphProbe) -> GraphProbe {
    let count = max(1, graph.nodes.count)
    let nodes = graph.nodes.map { node -> GraphNode in
      switch node {
      case .array(let children):
        return .array(children.map { index($0, modulo: count) })
      case .dictionary(let entries):
        return .dictionary(
          entries.map { entry in
            GraphEntry(
              key: entry.key.filter { $0 != 0 },
              target: index(entry.target, modulo: count)
            )
          }
        )
      case .null, .bool, .signed, .unsigned, .double, .data:
        return node
      case .string(let bytes):
        return .string(bytes.filter { $0 != 0 })
      }
    }
    return GraphProbe(nodes: nodes, root: index(graph.root, modulo: count))
  }

  /// A nonnegative index below `count`, defined for every `Int`.
  ///
  /// `abs(_:)` traps on `Int.min`, so a replayed hostile descriptor carrying
  /// that edge would crash the sanitizer rather than be clamped by it.
  /// Remaindering first keeps every input in range without an intermediate
  /// magnitude.
  ///
  /// - Precondition: `count` is positive.
  private static func index(_ value: Int, modulo count: Int) -> Int {
    precondition(count > 0, "A graph always has at least one node.")
    let remainder = value % count
    return remainder < 0 ? remainder + count : remainder
  }

  private static func mutate(
    _ probe: ResourceBoundaryProbe,
    random: inout SplitMix64
  ) -> ResourceBoundaryProbe {
    // Budgets stay small so a bounded child can actually reach them; the
    // interesting behavior is at the boundary, not at scale.
    let limit =
      random.bool()
      ? min(64, max(0, probe.limit + random.element(from: [-2, -1, 1, 2])))
      : probe.limit
    let observed =
      random.bool()
      ? min(96, max(0, limit + random.element(from: [-2, -1, 0, 1, 2])))
      : min(96, probe.observed)
    return ResourceBoundaryProbe(
      resource: random.bool()
        ? random.caseValue(of: ResourceKind.self)
        : probe.resource,
      limit: limit,
      observed: observed,
      expectation: probe.expectation
    )
  }

}
