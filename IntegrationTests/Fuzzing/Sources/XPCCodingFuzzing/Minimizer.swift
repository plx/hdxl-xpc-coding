import Foundation

// MARK: - Minimizer

/// Shrinks a failing descriptor to a small case that still fails.
///
/// Reductions are enumerated deterministically, so minimizing the same
/// counterexample twice produces the same artifact. A candidate is accepted only
/// when it reproduces a failure at least as severe as the original, which keeps
/// minimization from wandering onto an unrelated defect.
struct Minimizer: Sendable {
  let runner: ChildRunner
  let childRunBudget: Int

  init(
    runner: ChildRunner,
    childRunBudget: Int = 160
  ) {
    self.runner = runner
    self.childRunBudget = childRunBudget
  }

  struct Result {
    var descriptor: ProbeDescriptor
    var outcome: ChildOutcome
    var childRuns: Int
    var acceptedReductions: Int
  }

  func minimize(
    _ descriptor: ProbeDescriptor,
    originalOutcome: ChildOutcome
  ) -> Result {
    var best = descriptor
    var bestOutcome = originalOutcome
    var childRuns = 0
    var acceptedReductions = 0

    var madeProgress = true
    while madeProgress, childRuns < childRunBudget {
      madeProgress = false
      for candidateProbe in Self.reductions(of: best.probe) {
        guard childRuns < childRunBudget else {
          break
        }
        let candidate = ProbeDescriptor(
          id: best.id,
          origin: best.origin,
          seed: best.seed,
          probe: candidateProbe.normalized
        )
        guard candidate.probe != best.probe else {
          continue
        }
        childRuns += 1
        guard
          let outcome = try? runner.run(candidate),
          reproduces(outcome, atLeastAsSevereAs: originalOutcome)
        else {
          continue
        }
        best = candidate
        bestOutcome = outcome
        acceptedReductions += 1
        madeProgress = true
        break
      }
    }

    return Result(
      descriptor: best,
      outcome: bestOutcome,
      childRuns: childRuns,
      acceptedReductions: acceptedReductions
    )
  }

  private func reproduces(
    _ candidate: ChildOutcome,
    atLeastAsSevereAs original: ChildOutcome
  ) -> Bool {
    guard candidate.kind.isFailure else {
      return false
    }
    if original.kind.isSafetyViolation {
      return candidate.kind.isSafetyViolation
    }
    return candidate.kind == original.kind || candidate.kind.isSafetyViolation
  }

  // MARK: Reductions

  /// Simpler probes to try, in order from most to least aggressive.
  static func reductions(of probe: Probe) -> [Probe] {
    switch probe {
    case .model(let value):
      return modelReductions(value)
    case .distinctStrings(let value):
      return stringListReductions(value.strings).map {
        .distinctStrings(
          DistinctStringsProbe(strategy: value.strategy, strings: $0)
        )
      }
    case .keyCollision(let value):
      return stringListReductions(value.keys).map {
        .keyCollision(KeyCollisionProbe(strategy: value.strategy, keys: $0))
      }
    case .graph(let value):
      return graphReductions(value).map { .graph($0) }
    case .binary128(let value):
      return binary128Reductions(value)
    case .resourceBoundary(let value):
      return resourceBoundaryReductions(value)
    case .rawText(let value):
      // Shrinking the bytes invalidates a reviewed decoded text, so a `.pass`
      // case weakens to `.tolerant`. A `.reject` or `.tolerant` verdict stays
      // faithful under shrinking and is preserved, which is what lets a
      // wrongly-accepted input shrink to its smallest accepted form.
      let expectation: Expectation =
        value.expectation == .pass
        ? .tolerant
        : value.expectation
      return byteReductions(value.bytes).map {
        .rawText(
          RawTextProbe(
            location: value.location,
            strategy: value.strategy,
            bytes: $0,
            expectation: expectation,
            expectedScalars: nil
          )
        )
      }
    case .representation(let value):
      return byteReductions(Array(value.bytes)).map {
        .representation(
          RepresentationProbe(
            kind: value.kind,
            bytes: Data($0),
            signed: value.signed,
            unsigned: value.unsigned,
            floatBits: value.floatBits,
            doubleBits: value.doubleBits
          )
        )
      }
    case .cycle, .pointerCount, .deliberateHang:
      // Already minimal: these carry no payload to shrink.
      return []
    }
  }

  private static func modelReductions(_ probe: ModelProbe) -> [Probe] {
    var models: [FuzzModel] = []
    var model = probe.value

    if !model.data.isEmpty {
      model.data = Data()
      models.append(model)
    }
    if !model.numbers.isEmpty {
      model.numbers = []
      models.append(model)
    }
    if model.child != nil {
      model.child = nil
      models.append(model)
    }
    if !model.dictionary.isEmpty {
      var reduced = model
      for key in model.dictionary.keys.sorted() {
        reduced.dictionary.removeValue(forKey: key)
        models.append(reduced)
      }
      model.dictionary = [:]
      models.append(model)
    }
    if !model.string.isEmpty {
      model.string = ""
      models.append(model)
    }

    return models.map {
      .model(ModelProbe(strategy: probe.strategy, value: $0))
    }
  }

  private static func stringListReductions(
    _ strings: [String]
  ) -> [[String]] {
    var reductions: [[String]] = []
    if strings.count > 1 {
      for index in strings.indices {
        var reduced = strings
        reduced.remove(at: index)
        reductions.append(reduced)
      }
    }
    for index in strings.indices where strings[index].unicodeScalars.count > 1 {
      var reduced = strings
      reduced[index] = String(
        String.UnicodeScalarView(
          strings[index].unicodeScalars.prefix(
            strings[index].unicodeScalars.count / 2
          )
        )
      )
      reductions.append(reduced)
    }
    return reductions
  }

  private static func graphReductions(_ graph: GraphProbe) -> [GraphProbe] {
    var reductions: [GraphProbe] = []
    if graph.nodes.count > 1 {
      for index in graph.nodes.indices {
        var nodes = graph.nodes
        nodes.remove(at: index)
        reductions.append(
          DescriptorMutator.sanitized(
            GraphProbe(nodes: nodes, root: graph.root)
          )
        )
      }
    }
    for index in graph.nodes.indices {
      switch graph.nodes[index] {
      case .array(let children) where !children.isEmpty:
        var nodes = graph.nodes
        nodes[index] = .array(Array(children.dropLast()))
        reductions.append(
          DescriptorMutator.sanitized(GraphProbe(nodes: nodes, root: graph.root))
        )
      case .dictionary(let entries) where !entries.isEmpty:
        var nodes = graph.nodes
        nodes[index] = .dictionary(Array(entries.dropLast()))
        reductions.append(
          DescriptorMutator.sanitized(GraphProbe(nodes: nodes, root: graph.root))
        )
      case .data(let bytes) where !bytes.isEmpty:
        var nodes = graph.nodes
        nodes[index] = .data(Data())
        reductions.append(
          DescriptorMutator.sanitized(GraphProbe(nodes: nodes, root: graph.root))
        )
      case .string(let bytes) where !bytes.isEmpty:
        var nodes = graph.nodes
        nodes[index] = .string(Array(bytes.prefix(bytes.count / 2)))
        reductions.append(
          DescriptorMutator.sanitized(GraphProbe(nodes: nodes, root: graph.root))
        )
      case .null, .bool, .signed, .unsigned, .double, .array, .dictionary, .data,
        .string:
        break
      }
    }
    return reductions
  }

  private static func binary128Reductions(
    _ probe: Binary128Probe
  ) -> [Probe] {
    var reductions: [Probe] = []
    if probe.unaligned {
      reductions.append(
        .binary128(
          Binary128Probe(
            type: probe.type,
            bytes: probe.bytes,
            unaligned: false,
            expectation: probe.expectation
          )
        )
      )
    }
    for byteCount in shrinkTargets(for: probe.bytes.count) {
      reductions.append(
        .binary128(
          Binary128Probe(
            type: probe.type,
            bytes: probe.bytes.prefix(byteCount),
            unaligned: probe.unaligned,
            expectation: probe.expectation
          )
        )
      )
    }
    return reductions
  }

  private static func resourceBoundaryReductions(
    _ probe: ResourceBoundaryProbe
  ) -> [Probe] {
    // Halving both sides preserves the over/under relation that makes the case
    // interesting while making the graph the child builds much smaller.
    var reductions: [Probe] = []
    let overBy = probe.observed - probe.effectiveLimit
    for limit in shrinkTargets(for: probe.limit) {
      reductions.append(
        .resourceBoundary(
          ResourceBoundaryProbe(
            resource: probe.resource,
            limit: limit,
            observed: max(0, limit + overBy),
            expectation: probe.expectation
          )
        )
      )
    }
    return reductions
  }

  private static func byteReductions(_ bytes: [UInt8]) -> [[UInt8]] {
    var reductions: [[UInt8]] = []
    for count in shrinkTargets(for: bytes.count) {
      reductions.append(Array(bytes.prefix(count)))
    }
    if bytes.count > 1 {
      reductions.append(Array(bytes.dropFirst()))
    }
    return reductions
  }

  /// Halving targets down to zero, largest reduction first.
  private static func shrinkTargets(for count: Int) -> [Int] {
    guard count > 0 else {
      return []
    }
    var targets: [Int] = []
    var candidate = count / 2
    while candidate > 0 {
      targets.append(candidate)
      candidate /= 2
    }
    targets.append(0)
    return targets
  }

}
