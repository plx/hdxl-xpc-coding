import Darwin
import Foundation

// MARK: - CLI

enum FuzzingCLI {

  static func run(arguments: [String]) throws -> Int32 {
    switch arguments.first {
    case nil, "help", "--help", "-h":
      print(usage)
      return FuzzingExitCode.passed
    case "run-case":
      return try runCase(arguments: Array(arguments.dropFirst()))
    case "corpus":
      return try corpus(arguments: Array(arguments.dropFirst()))
    case "campaign":
      return try campaign(arguments: Array(arguments.dropFirst()))
    case "replay":
      return try replay(arguments: Array(arguments.dropFirst()))
    case "determinism":
      return try determinism(arguments: Array(arguments.dropFirst()))
    case "verify-timeout":
      return try verifyTimeout(arguments: Array(arguments.dropFirst()))
    case "verify-memory":
      return try verifyMemory(arguments: Array(arguments.dropFirst()))
    case "verify-minimizer":
      return try verifyMinimizer(arguments: Array(arguments.dropFirst()))
    case "self-test":
      return try selfTest(arguments: Array(arguments.dropFirst()))
    case .some(let command):
      throw FuzzingError("Unknown command: \(command)\n\n\(usage)")
    }
  }

  // MARK: Child Entry Point

  /// Executes exactly one descriptor, and nothing else.
  ///
  /// This is the bounded child process. It installs the kernel-enforced
  /// ceilings on itself before it reads the descriptor, so even a hostile or
  /// corrupt descriptor file is parsed under the CPU ceiling and with core
  /// dumps already disabled.
  private static func runCase(arguments: [String]) throws -> Int32 {
    var parser = FuzzingArguments(arguments)
    guard let descriptorPath = parser.value(for: "--descriptor") else {
      throw FuzzingError("run-case requires --descriptor PATH.")
    }
    let cpuSeconds = try parser.integer(
      for: "--cpu-seconds",
      default: ProbeBounds.standard.cpuSeconds,
      minimum: 1
    )
    try parser.requireExhausted()

    do {
      try ProbeSandbox.apply(
        ProbeBounds(
          wallClockSeconds: ProbeBounds.standard.wallClockSeconds,
          cpuSeconds: cpuSeconds,
          memoryMebibytes: ProbeBounds.standard.memoryMebibytes
        )
      )
    } catch {
      write("\(error)", to: FileHandle.standardError)
      return FuzzingExitCode.harnessFailed
    }

    let descriptor = try Corpus.loadDescriptor(
      at: URL(fileURLWithPath: descriptorPath)
    )
    let observations = ObservationLog()
    do {
      try runProbe(descriptor, observations: observations)
    } catch {
      // The seed travels with every diagnostic so a failure found in CI is
      // replayable from the log alone.
      let message =
        """
        FAIL \(descriptor.id) seed=\(descriptor.seedHex) \
        kind=\(descriptor.probe.kindName)
        \(error)
        """
      write(message, to: FileHandle.standardError)
      for observation in observations.entries {
        write("observation: \(observation)", to: FileHandle.standardError)
      }
      return FuzzingExitCode.probeFailed
    }

    for observation in observations.entries {
      print("observation: \(observation)")
    }
    print(
      "PASS \(descriptor.id) seed=\(descriptor.seedHex) kind=\(descriptor.probe.kindName)"
    )
    return FuzzingExitCode.passed
  }

  // MARK: Corpus

  private static func corpus(arguments: [String]) throws -> Int32 {
    var remaining = arguments
    let subcommand = remaining.first.flatMap { candidate -> String? in
      candidate.hasPrefix("--") ? nil : candidate
    }
    if subcommand != nil {
      remaining = Array(remaining.dropFirst())
    }

    switch subcommand {
    case nil, "run":
      return try runCorpus(arguments: remaining)
    case "verify":
      var parser = FuzzingArguments(remaining)
      let directory = try parser.corpusDirectory()
      try parser.requireExhausted()
      let verification = try Corpus.verify(directory: directory)
      print(
        """
        Verified \(verification.caseCount) checked-in corpus cases in \
        \(directory.path) (digest \(verification.digest)).
        """
      )
      return FuzzingExitCode.passed
    case "regenerate":
      var parser = FuzzingArguments(remaining)
      let directory = try parser.corpusDirectory()
      try parser.requireExhausted()
      try Corpus.write(themes: HistoricalCorpus.themes(), to: directory)
      let verification = try Corpus.verify(directory: directory)
      print(
        """
        Wrote \(verification.caseCount) reviewed corpus cases to \
        \(directory.path) (digest \(verification.digest)). Review the diff.
        """
      )
      return FuzzingExitCode.passed
    case "list":
      var parser = FuzzingArguments(remaining)
      let directory = try parser.corpusDirectory()
      try parser.requireExhausted()
      for descriptor in try Corpus.load(from: directory) {
        print("\(descriptor.id)\t\(descriptor.seedHex)\t\(descriptor.probe.kindName)")
      }
      return FuzzingExitCode.passed
    case .some(let other):
      throw FuzzingError("Unknown corpus subcommand: \(other)\n\n\(usage)")
    }
  }

  private static func runCorpus(arguments: [String]) throws -> Int32 {
    var parser = FuzzingArguments(arguments)
    let directory = try parser.corpusDirectory()
    let bounds = try parser.bounds(default: .smoke)
    let jobs = try parser.jobs()
    let artifacts = try parser.artifactsDirectory(defaultName: "corpus")
    try parser.requireExhausted()

    let report = try Campaign(
      options: Campaign.Options(
        mode: "corpus",
        seed: 0,
        generatedCaseCount: 0,
        mutatedCaseCount: 0,
        jobs: jobs,
        bounds: bounds,
        durationSeconds: nil,
        minimizationChildRunBudget: 160,
        corpusDirectory: directory,
        artifactsDirectory: artifacts,
        includeCorpus: true
      ),
      runner: try makeRunner(bounds: bounds),
      executableURL: try ChildRunner.currentExecutableURL()
    ).run()
    print(report.consoleSummary)
    return report.succeeded ? FuzzingExitCode.passed : 1
  }

  // MARK: Campaign

  private static func campaign(arguments: [String]) throws -> Int32 {
    var parser = FuzzingArguments(arguments)
    let smoke = parser.flag("--smoke")
    let skipCorpus = parser.flag("--skip-corpus")
    let directory = try parser.corpusDirectory()
    let seed = try parser.seed(default: smoke ? 0x5eed_0000_0000_0001 : nil)
    let bounds = try parser.bounds(default: smoke ? .smoke : .standard)
    let jobs = try parser.jobs()
    let generatedCaseCount = try parser.integer(
      for: "--cases",
      default: smoke ? 96 : 512,
      minimum: 0
    )
    let mutatedCaseCount = try parser.integer(
      for: "--mutations",
      default: smoke ? 96 : 512,
      minimum: 0
    )
    let minimizationChildRunBudget = try parser.integer(
      for: "--minimization-budget",
      default: smoke ? 80 : 240,
      minimum: 0
    )
    let durationSeconds = try parser.optionalDouble(
      for: "--duration-seconds",
      minimumExclusive: 0
    )
    let artifacts = try parser.artifactsDirectory(
      defaultName: smoke ? "smoke" : "campaign"
    )
    try parser.requireExhausted()

    let report = try Campaign(
      options: Campaign.Options(
        mode: smoke ? "smoke" : "long",
        seed: seed,
        generatedCaseCount: generatedCaseCount,
        mutatedCaseCount: mutatedCaseCount,
        jobs: jobs,
        bounds: bounds,
        durationSeconds: durationSeconds,
        minimizationChildRunBudget: minimizationChildRunBudget,
        corpusDirectory: directory,
        artifactsDirectory: artifacts,
        includeCorpus: !skipCorpus
      ),
      runner: try makeRunner(bounds: bounds),
      executableURL: try ChildRunner.currentExecutableURL()
    ).run()
    print(report.consoleSummary)
    return report.succeeded ? FuzzingExitCode.passed : 1
  }

  // MARK: Replay

  private static func replay(arguments: [String]) throws -> Int32 {
    var parser = FuzzingArguments(arguments)
    let casePath = parser.value(for: "--case")
    let caseID = parser.value(for: "--case-id")
    let index = try parser.optionalInteger(for: "--index", minimum: 0)
    let seedText = parser.value(for: "--seed")
    let directory = try parser.corpusDirectory()
    let bounds = try parser.bounds(default: .standard)
    try parser.requireExhausted()

    let descriptor: ProbeDescriptor
    if let casePath {
      descriptor = try Corpus.loadDescriptor(at: URL(fileURLWithPath: casePath))
    } else if let caseID {
      let corpusCases = try Corpus.load(from: directory)
      guard let match = corpusCases.first(where: { $0.id == caseID }) else {
        throw FuzzingError("No checked-in corpus case has the identifier \(caseID).")
      }
      descriptor = match
    } else if let index {
      guard let seedText else {
        throw FuzzingError("replay --index requires --seed.")
      }
      descriptor = DescriptorGenerator.descriptor(
        seed: try FuzzingArguments.parseSeed(seedText),
        index: index
      )
    } else {
      throw FuzzingError(
        "replay requires --case PATH, --case-id ID, or --seed SEED --index N."
      )
    }

    print(
      """
      Replaying \(descriptor.id) seed=\(descriptor.seedHex) \
      kind=\(descriptor.probe.kindName) origin=\(descriptor.origin)
      """
    )
    print(String(decoding: try FuzzingJSON.encode(descriptor), as: UTF8.self))

    // Replay always crosses the process boundary. There is no in-process
    // escape: a case that is safe today can become a trap or a hang after any
    // change, and an unbounded debug path would quietly undo the guarantee that
    // every hostile case runs supervised. Attach a debugger to the child
    // instead, using the `run-case` invocation the descriptor above replays.
    let outcome = try makeRunner(bounds: bounds).run(descriptor)
    print("outcome for seed \(descriptor.seedHex):")
    print("  \(outcome.diagnostic)")
    return outcome.kind.isFailure ? 1 : FuzzingExitCode.passed
  }

  // MARK: Determinism

  private static func determinism(arguments: [String]) throws -> Int32 {
    var parser = FuzzingArguments(arguments)
    let seed = try parser.seed(default: 0x5eed_0000_0000_0001)
    let caseCount = try parser.integer(for: "--cases", default: 64, minimum: 1)
    let repeatCount = try parser.integer(for: "--repeats", default: 3, minimum: 2)
    let executeCount = try parser.integer(
      for: "--execute",
      default: 8,
      minimum: 0
    )
    let bounds = try parser.bounds(default: .smoke)
    let jobs = try parser.jobs()
    // Accepted for uniformity with the other commands; determinism is a property
    // of the generator, not of the checked-in corpus.
    _ = parser.value(for: "--corpus")
    try parser.requireExhausted()

    var digests: [String] = []
    var executedOutcomes: [String] = []
    let runner = try makeRunner(bounds: bounds)

    for iteration in 1...repeatCount {
      let generated = DescriptorGenerator.descriptors(seed: seed, count: caseCount)
      let mutated = DescriptorMutator.mutations(
        of: generated,
        seed: seed,
        count: caseCount
      )
      let digest = try FuzzingJSON.digest(generated + mutated)
      digests.append(digest)
      print("repeat \(iteration): case digest \(digest)")

      guard executeCount > 0 else {
        continue
      }
      let subset = Array((generated + mutated).prefix(executeCount))
      let outcomes = concurrentResults(for: subset, jobs: jobs) { descriptor in
        (try? runner.run(descriptor))?.kind ?? .unexpectedExit
      }
      let transcript = zip(subset, outcomes)
        .map { "\($0.id)=\($1.rawValue)" }
        .joined(separator: ",")
      executedOutcomes.append(transcript)
      print("repeat \(iteration): executed \(subset.count) cases")
    }

    let report = DeterminismReport(
      seed: seed,
      seedHex: String(format: "0x%016llx", seed),
      caseCount: caseCount,
      repeatCount: repeatCount,
      digests: digests,
      executedOutcomes: executedOutcomes
    )
    guard report.isStable else {
      write(
        """
        Seed \(report.seedHex) is not deterministic.
          digests: \(Set(report.digests).sorted())
          outcome transcripts: \(Set(report.executedOutcomes).count) distinct
        """,
        to: FileHandle.standardError
      )
      return 1
    }
    print(
      """
      Seed \(report.seedHex) is stable: \(repeatCount) repeats produced one case \
      digest (\(digests[0])) for \(caseCount) generated plus \(caseCount) mutated \
      cases, and identical outcomes for the executed subset.
      """
    )
    return FuzzingExitCode.passed
  }

  // MARK: Timeout Control

  /// Proves the wall-clock control kills a deliberately hanging child and that
  /// its diagnostic names the seed.
  ///
  /// A fuzzing harness whose timeout does not work reports success forever. This
  /// is the negative control for that failure mode.
  private static func verifyTimeout(arguments: [String]) throws -> Int32 {
    var parser = FuzzingArguments(arguments)
    let directory = try parser.corpusDirectory()
    let wallClockSeconds = try parser.double(
      for: "--timeout-seconds",
      default: 2,
      minimumExclusive: 0
    )
    try parser.requireExhausted()

    let descriptor = try hangingDescriptor(in: directory)
    let bounds = ProbeBounds(
      wallClockSeconds: wallClockSeconds,
      // Above the wall clock, so the wall-clock control is what fires.
      cpuSeconds: max(2, Int(wallClockSeconds) + 30),
      memoryMebibytes: ProbeBounds.smoke.memoryMebibytes
    )
    let start = Date()
    let outcome = try makeRunner(bounds: bounds).run(descriptor)
    let elapsed = Date().timeIntervalSince(start)

    let finding = CampaignFinding(
      id: descriptor.id,
      origin: descriptor.origin,
      seed: descriptor.seed,
      seedHex: descriptor.seedHex,
      probeKind: descriptor.probe.kindName,
      outcome: outcome.kind,
      diagnostic: outcome.diagnostic,
      replayCommand: "XPCCodingFuzzing replay --case-id \(descriptor.id)"
    )
    let summary = finding.consoleSummary
    print(summary)

    guard outcome.kind == .timedOut else {
      write(
        """
        The deliberate hanger was not stopped by the wall-clock control: \
        observed \(outcome.kind.rawValue) after \
        \(String(format: "%.2f", elapsed))s.
        """,
        to: FileHandle.standardError
      )
      return 1
    }
    guard summary.contains(descriptor.seedHex) else {
      write(
        "The timeout diagnostic did not report the seed \(descriptor.seedHex).",
        to: FileHandle.standardError
      )
      return 1
    }
    guard elapsed < wallClockSeconds * 10 else {
      write(
        """
        The wall-clock control took \(String(format: "%.2f", elapsed))s to stop a \
        \(wallClockSeconds)s budget.
        """,
        to: FileHandle.standardError
      )
      return 1
    }
    print(
      """
      The wall-clock control killed the deliberate hanger after \
      \(String(format: "%.2f", elapsed))s and reported seed \
      \(descriptor.seedHex).
      """
    )
    return FuzzingExitCode.passed
  }

  // MARK: Memory Control

  /// Proves the footprint ceiling fires, and fires *before* the wall clock.
  ///
  /// The wall clock and the CPU ceiling announce themselves the first time they
  /// stop something. The footprint ceiling does not: no case in this corpus
  /// allocates near it, so a sampler that had silently stopped working would
  /// look exactly like a sampler with nothing to catch.
  ///
  /// The control runs the deliberate hanger — which allocates nothing — under a
  /// ceiling below any Swift process's resident footprint, and requires the
  /// memory outcome rather than the timeout. If the sampler were broken, the
  /// hanger would run until the wall clock stopped it, and this would fail.
  private static func verifyMemory(arguments: [String]) throws -> Int32 {
    var parser = FuzzingArguments(arguments)
    let directory = try parser.corpusDirectory()
    try parser.requireExhausted()

    let descriptor = try hangingDescriptor(in: directory)
    // Constructed directly rather than through `bounds(default:)`, whose
    // floor of 64 MiB is right for a real campaign and useless as a control.
    let bounds = ProbeBounds(
      wallClockSeconds: 20,
      cpuSeconds: 30,
      memoryMebibytes: 1
    )
    let start = Date()
    let outcome = try makeRunner(bounds: bounds).run(descriptor)
    let elapsed = Date().timeIntervalSince(start)

    guard outcome.kind == .memoryExceeded else {
      write(
        """
        The footprint ceiling did not stop a child above \
        \(bounds.memoryMebibytes) MiB: observed \(outcome.kind.rawValue) after \
        \(String(format: "%.2f", elapsed))s.
          \(outcome.diagnostic)
        """,
        to: FileHandle.standardError
      )
      return 1
    }
    print(
      """
      The footprint control killed \(descriptor.id) (seed \
      \(descriptor.seedHex)) after \(String(format: "%.2f", elapsed))s at a \
      \(bounds.memoryMebibytes) MiB ceiling, measured \
      \(outcome.peakFootprintBytes / 1_024) KiB.
      """
    )
    return FuzzingExitCode.passed
  }

  /// The checked-in case that never returns.
  private static func hangingDescriptor(
    in directory: URL
  ) throws -> ProbeDescriptor {
    let descriptor =
      try Corpus.loadTheme(
        named: "deliberate-hang",
        from: directory
      ).first ?? HistoricalCorpus.deliberateHangDescriptor
    guard descriptor.probe == .deliberateHang else {
      throw FuzzingError(
        "The deliberate-hang corpus theme no longer contains a hanging case."
      )
    }
    return descriptor
  }

  // MARK: Minimizer Control

  /// Proves that a failing case is detected, shrunk, and persisted.
  ///
  /// A harness that silently fails to notice failures, or that reports an
  /// unshrunk 4 KiB counterexample, is worse than no harness. The control case
  /// below is synthetic on purpose: it demands rejection of plain ASCII that
  /// `.passthrough` must obviously accept, so the failure is a property of the
  /// descriptor rather than a claim about XPCCoding.
  private static func verifyMinimizer(arguments: [String]) throws -> Int32 {
    var parser = FuzzingArguments(arguments)
    let bounds = try parser.bounds(default: .smoke)
    let artifacts = try parser.artifactsDirectory(defaultName: "minimizer-control")
    _ = parser.value(for: "--corpus")
    try parser.requireExhausted()

    let runner = try makeRunner(bounds: bounds)
    let originalByteCount = 32
    let failing = ProbeDescriptor(
      id: "control/minimizer",
      origin: "harness-negative-control",
      seed: HistoricalCorpus.stableSeed(for: "control/minimizer"),
      probe: .rawText(
        RawTextProbe(
          location: .stringValue,
          strategy: .passthrough,
          bytes: Array(repeating: UInt8(ascii: "a"), count: originalByteCount),
          expectation: .reject,
          expectedScalars: nil
        )
      )
    )

    // The same case with a truthful expectation must pass, or the control proves
    // nothing about detection.
    let truthful = ProbeDescriptor(
      id: "control/minimizer-truthful",
      origin: "harness-negative-control",
      seed: failing.seed,
      probe: .rawText(
        RawTextProbe(
          location: .stringValue,
          strategy: .passthrough,
          bytes: Array(repeating: UInt8(ascii: "a"), count: originalByteCount),
          expectation: .pass,
          expectedScalars: Array(
            String(repeating: "a", count: originalByteCount).unicodeScalars.map(\.value)
          )
        )
      )
    )
    let truthfulOutcome = try runner.run(truthful)
    guard truthfulOutcome.kind == .passed else {
      write(
        """
        The minimizer control is vacuous: its truthful twin also failed \
        (\(truthfulOutcome.kind.rawValue)).
          \(truthfulOutcome.diagnostic)
        """,
        to: FileHandle.standardError
      )
      return 1
    }

    let outcome = try runner.run(failing)
    guard outcome.kind == .probeFailed else {
      write(
        """
        The harness did not detect a deliberately failing case: observed \
        \(outcome.kind.rawValue).
          \(outcome.diagnostic)
        """,
        to: FileHandle.standardError
      )
      return 1
    }

    let minimization = Minimizer(runner: runner, childRunBudget: 80)
      .minimize(failing, originalOutcome: outcome)
    guard case .rawText(let minimizedProbe) = minimization.descriptor.probe else {
      write("Minimization changed the probe kind.", to: FileHandle.standardError)
      return 1
    }
    guard minimization.acceptedReductions > 0,
      minimizedProbe.bytes.count < originalByteCount
    else {
      write(
        """
        Minimization did not shrink the control case: \
        \(minimizedProbe.bytes.count) bytes after \
        \(minimization.acceptedReductions) accepted reductions and \
        \(minimization.childRuns) child runs.
        """,
        to: FileHandle.standardError
      )
      return 1
    }

    try FileManager.default.createDirectory(
      at: artifacts,
      withIntermediateDirectories: true
    )
    let persistedURL = artifacts.appendingPathComponent("minimizer-control.json")
    try FuzzingJSON.encode(minimization.descriptor)
      .write(to: persistedURL, options: .atomic)
    let reloaded = try Corpus.loadDescriptor(at: persistedURL)
    let reloadedOutcome = try runner.run(reloaded)
    guard reloadedOutcome.kind == .probeFailed else {
      write(
        """
        The persisted counterexample did not reproduce: observed \
        \(reloadedOutcome.kind.rawValue).
        """,
        to: FileHandle.standardError
      )
      return 1
    }

    print(
      """
      Minimizer control passed: detected the failure, shrank \
      \(originalByteCount) bytes to \(minimizedProbe.bytes.count) in \
      \(minimization.acceptedReductions) accepted reductions \
      (\(minimization.childRuns) child runs), and the persisted case at \
      \(persistedURL.path) reproduces.
      """
    )
    return FuzzingExitCode.passed
  }

  // MARK: Self Test

  /// A fast end-to-end check of the harness's own machinery.
  private static func selfTest(arguments: [String]) throws -> Int32 {
    var parser = FuzzingArguments(arguments)
    let directory = try parser.corpusDirectory()
    try parser.requireExhausted()

    let corpusPath = directory.path
    let steps: [(String, [String])] = [
      ("corpus verify", ["corpus", "verify", "--corpus", corpusPath]),
      (
        "determinism", ["determinism", "--cases", "8", "--repeats", "2", "--execute", "4", "--corpus", corpusPath]
      ),
      ("verify-timeout", ["verify-timeout", "--timeout-seconds", "2", "--corpus", corpusPath]),
      ("verify-memory", ["verify-memory", "--corpus", corpusPath]),
      ("verify-minimizer", ["verify-minimizer", "--corpus", corpusPath]),
      (
        "bounded campaign",
        [
          "campaign", "--smoke", "--skip-corpus", "--cases", "8", "--mutations", "8",
          "--corpus", corpusPath,
        ]
      ),
    ]

    for (name, stepArguments) in steps {
      print("=== self-test: \(name) ===")
      let status = try run(arguments: stepArguments)
      guard status == FuzzingExitCode.passed else {
        write("self-test step `\(name)` failed with status \(status).", to: FileHandle.standardError)
        return status
      }
    }
    print("Harness self-test passed.")
    return FuzzingExitCode.passed
  }

  // MARK: Support

  private static func makeRunner(bounds: ProbeBounds) throws -> ChildRunner {
    let scratch = try scratchDirectory()
    return ChildRunner(
      executableURL: try ChildRunner.currentExecutableURL(),
      bounds: bounds,
      scratchDirectory: scratch
    )
  }

  /// This process's scratch directory, created once and removed at exit.
  ///
  /// Each case removes its own subdirectory as it finishes; this removes the
  /// container itself so a long campaign leaves nothing behind in `TMPDIR`.
  private static func scratchDirectory() throws -> URL {
    if let existing = createdScratchDirectory {
      return existing
    }
    let scratch = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("hdxl-xpc-fuzzing-\(getpid())")
    try FileManager.default.createDirectory(
      at: scratch,
      withIntermediateDirectories: true
    )
    createdScratchDirectory = scratch
    return scratch
  }

  /// Removes this process's scratch directory, if it created one.
  static func removeScratchDirectory() {
    guard let scratch = createdScratchDirectory else {
      return
    }
    createdScratchDirectory = nil
    try? FileManager.default.removeItem(at: scratch)
  }

  /// Only ever touched from the single-threaded command-line entry point.
  nonisolated(unsafe) private static var createdScratchDirectory: URL?

  static func write(_ message: String, to handle: FileHandle) {
    handle.write(Data("\(message)\n".utf8))
  }

  private static let usage = """
    XPCCodingFuzzing — deterministic property and hostile-input fuzzing for XPCCoding

      corpus [run] [--corpus PATH] [--jobs N] [bounds]
          Verify and execute every checked-in case in a bounded child.
      corpus verify [--corpus PATH]
          Confirm the checked-in JSON matches the reviewed Swift inventory.
      corpus regenerate [--corpus PATH]
          Rewrite the JSON from the reviewed inventory, for review.
      corpus list [--corpus PATH]
          Print every checked-in case identifier, seed, and kind.

      campaign [--smoke] [--seed SEED] [--cases N] [--mutations N]
               [--duration-seconds S] [--jobs N] [--skip-corpus]
               [--artifacts PATH] [--minimization-budget N] [bounds]
          Run corpus, generated, and mutated cases; minimize and persist every
          counterexample.

      replay (--case PATH | --case-id ID | --seed SEED --index N) [bounds]
          Re-run exactly one case, always in a bounded child process.

      run-case --descriptor PATH [--cpu-seconds N]
          The bounded child entry point. Runs exactly one descriptor in this
          process, under ceilings it installs on itself.

      determinism [--seed SEED] [--cases N] [--repeats N] [--execute N]
          Prove a fixed seed generates identical cases across repeated runs.

      verify-timeout [--timeout-seconds S]
          Prove the wall-clock control kills a hanging child and reports its seed.

      verify-memory
          Prove the footprint ceiling kills a child, ahead of the wall clock.

      verify-minimizer [--artifacts PATH]
          Prove a failing case is detected, shrunk, and persisted.

      self-test
          Run the harness's own bounded end-to-end check.

    bounds:
      --timeout-seconds S   wall-clock ceiling per case
      --cpu-seconds N       CPU-time ceiling per case (kernel enforced)
      --memory-mib N        physical-footprint ceiling per case

    SEED accepts decimal or 0x-prefixed hexadecimal.
    """
}

// MARK: - Argument Parsing

struct FuzzingArguments {
  private var arguments: [String]

  init(_ arguments: [String]) {
    self.arguments = arguments
  }

  mutating func flag(_ name: String) -> Bool {
    guard let index = arguments.firstIndex(of: name) else {
      return false
    }
    arguments.remove(at: index)
    return true
  }

  mutating func value(for name: String) -> String? {
    guard let index = arguments.firstIndex(of: name),
      arguments.indices.contains(index + 1)
    else {
      return nil
    }
    arguments.remove(at: index)
    return arguments.remove(at: index)
  }

  mutating func integer(
    for name: String,
    default defaultValue: Int,
    minimum: Int
  ) throws -> Int {
    try optionalInteger(for: name, minimum: minimum) ?? defaultValue
  }

  mutating func optionalInteger(
    for name: String,
    minimum: Int
  ) throws -> Int? {
    guard let text = value(for: name) else {
      return nil
    }
    guard let value = Int(text), value >= minimum else {
      throw FuzzingError("\(name) must be an integer of at least \(minimum).")
    }
    return value
  }

  mutating func double(
    for name: String,
    default defaultValue: Double,
    minimumExclusive: Double
  ) throws -> Double {
    try optionalDouble(for: name, minimumExclusive: minimumExclusive) ?? defaultValue
  }

  mutating func optionalDouble(
    for name: String,
    minimumExclusive: Double
  ) throws -> Double? {
    guard let text = value(for: name) else {
      return nil
    }
    guard let value = Double(text), value > minimumExclusive else {
      throw FuzzingError("\(name) must be greater than \(minimumExclusive).")
    }
    return value
  }

  mutating func seed(default defaultValue: UInt64?) throws -> UInt64 {
    guard let text = value(for: "--seed") else {
      guard let defaultValue else {
        // An unseeded long campaign should explore new ground each time, and the
        // chosen seed is always printed so any finding stays replayable.
        var random = SystemRandomNumberGenerator()
        return random.next()
      }
      return defaultValue
    }
    return try Self.parseSeed(text)
  }

  static func parseSeed(_ text: String) throws -> UInt64 {
    let normalized = text.lowercased()
    if normalized.hasPrefix("0x") {
      guard let value = UInt64(normalized.dropFirst(2), radix: 16) else {
        throw FuzzingError("Unable to parse the hexadecimal seed \(text).")
      }
      return value
    }
    guard let value = UInt64(normalized) else {
      throw FuzzingError("Unable to parse the seed \(text).")
    }
    return value
  }

  mutating func bounds(default defaultBounds: ProbeBounds) throws -> ProbeBounds {
    try ProbeBounds(
      wallClockSeconds: try double(
        for: "--timeout-seconds",
        default: defaultBounds.wallClockSeconds,
        minimumExclusive: 0
      ),
      cpuSeconds: try integer(
        for: "--cpu-seconds",
        default: defaultBounds.cpuSeconds,
        minimum: 1
      ),
      memoryMebibytes: try integer(
        for: "--memory-mib",
        default: defaultBounds.memoryMebibytes,
        minimum: 64
      )
    ).validated()
  }

  mutating func jobs() throws -> Int {
    let suggested = max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 1))
    return try integer(for: "--jobs", default: suggested, minimum: 1)
  }

  mutating func corpusDirectory() throws -> URL {
    guard let path = value(for: "--corpus") else {
      return try Corpus.defaultDirectory()
    }
    return URL(fileURLWithPath: path)
  }

  mutating func artifactsDirectory(defaultName: String) throws -> URL {
    guard let path = value(for: "--artifacts") else {
      // Counterexamples are always persisted somewhere, even when the caller
      // did not ask for an artifact directory.
      return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".build/fuzzing/\(defaultName)")
    }
    return URL(fileURLWithPath: path)
  }

  func requireExhausted() throws {
    guard arguments.isEmpty else {
      throw FuzzingError(
        "Unexpected arguments: \(arguments.joined(separator: " "))"
      )
    }
  }
}
