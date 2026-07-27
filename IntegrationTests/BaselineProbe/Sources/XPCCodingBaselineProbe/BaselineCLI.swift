import Darwin
import Foundation

// MARK: - CLI

enum BaselineCLI {

  static func run(arguments: [String]) throws -> Int32 {
    switch arguments.first {
    case nil, "help", "--help", "-h":
      print(usage)
      return BaselineExitCode.passed
    case "list":
      return try list()
    case "run":
      return try runOneCheck(arguments: Array(arguments.dropFirst()))
    case "evidence":
      return try evidence(arguments: Array(arguments.dropFirst()))
    case .some(let command):
      throw BaselineError("Unknown command: \(command)\n\n\(usage)")
    }
  }

  // MARK: List

  private static func list() throws -> Int32 {
    try BaselineChecks.validateInventory()
    for check in BaselineChecks.all {
      print(
        """
        \(check.id)\t\(check.defect ?? "control")\t\
        baseline=\(describe(check.atBaseline))\t\
        current=\(describe(check.atCurrent))
        """
      )
    }
    return BaselineExitCode.passed
  }

  // MARK: Child Entry Point

  /// Executes exactly one check, and nothing else.
  ///
  /// This is the bounded child. It installs the ceilings it can install on
  /// itself before it touches XPCCoding, because three of these checks are
  /// expected to end this process.
  private static func runOneCheck(arguments: [String]) throws -> Int32 {
    var parser = ProbeArguments(arguments)
    guard let identifier = parser.positional() else {
      throw BaselineError("run requires a check identifier.")
    }
    let cpuSeconds = try parser.integer(
      for: "--cpu-seconds",
      default: ProbeBounds().cpuSeconds,
      minimum: 1
    )
    try parser.requireExhausted()

    do {
      try ProbeSandbox.apply(ProbeBounds(cpuSeconds: cpuSeconds))
    } catch {
      write("\(error)", to: FileHandle.standardError)
      return BaselineExitCode.harnessFailed
    }

    let check = try BaselineChecks.check(id: identifier)
    let observation: CheckObservation
    do {
      observation = try check.body()
    } catch is DecodingError {
      observation = CheckObservation(.typedRejection, "threw a DecodingError")
    } catch is EncodingError {
      observation = CheckObservation(.typedRejection, "threw an EncodingError")
    } catch {
      // Anything else is the probe failing, not XPCCoding answering.
      write("\(error)", to: FileHandle.standardError)
      return BaselineExitCode.harnessFailed
    }

    let detail = observation.detail
      .replacingOccurrences(of: "\n", with: "; ")
    print("\(BaselineSupervisor.observationPrefix)\(observation.outcome.rawValue) \(detail)")
    return BaselineExitCode.passed
  }

  // MARK: Evidence

  /// Runs every check in a bounded child and requires the outcome the named
  /// revision must produce.
  private static func evidence(arguments: [String]) throws -> Int32 {
    var parser = ProbeArguments(arguments)
    guard let expected = parser.value(for: "--expect") else {
      throw BaselineError(
        """
        evidence requires --expect \
        (\(RevisionUnderTest.allCases.map(\.rawValue).joined(separator: "|"))).
        """
      )
    }
    guard let revision = RevisionUnderTest(rawValue: expected) else {
      throw BaselineError("Unknown revision `\(expected)`.")
    }
    let label = parser.value(for: "--revision-label") ?? revision.rawValue
    let bounds = ProbeBounds(
      wallClockSeconds: try parser.double(
        for: "--timeout-seconds",
        default: ProbeBounds().wallClockSeconds,
        minimumExclusive: 0
      ),
      cpuSeconds: try parser.integer(
        for: "--cpu-seconds",
        default: ProbeBounds().cpuSeconds,
        minimum: 1
      ),
      memoryMebibytes: try parser.integer(
        for: "--memory-mib",
        default: ProbeBounds().memoryMebibytes,
        minimum: 64
      )
    )
    try parser.requireExhausted()

    try BaselineChecks.validateInventory()
    let supervisor = try makeSupervisor(bounds: bounds)
    defer {
      removeScratchDirectory()
    }

    print(
      """
      Baseline evidence for \(label), expecting the `\(revision.rawValue)` \
      outcomes, with \(BaselineChecks.all.count) checks in bounded children at \
      \(bounds.summary).
      """
    )

    var failures: [String] = []
    for check in BaselineChecks.all {
      let execution = try supervisor.run(check)
      let expectations = check.expectations(at: revision)
      let satisfied = expectations.contains(execution.outcome)
      var line =
        "\(satisfied ? "ok  " : "FAIL") \(check.id) \(execution.outcome.rawValue)"
      if let signalDescription = execution.signalDescription,
        execution.outcome.isProcessFailure
      {
        line += " (\(signalDescription))"
      }
      print(line)
      print("       \(check.defect ?? "control"): \(check.summary)")
      if !execution.detail.isEmpty {
        print("       observed: \(execution.detail)")
      }
      guard !satisfied else {
        continue
      }
      failures.append(
        """
        \(check.id): expected \(describe(expectations)) at \(revision.rawValue), \
        observed \(execution.outcome.rawValue) — \(execution.detail)
        """
      )
    }

    guard failures.isEmpty else {
      write(
        """
        \(failures.count) of \(BaselineChecks.all.count) checks did not produce \
        the outcome `\(revision.rawValue)` requires:
          - \(failures.joined(separator: "\n  - "))
        """,
        to: FileHandle.standardError
      )
      return BaselineExitCode.evidenceFailed
    }

    let defects = BaselineChecks.all.filter { !$0.isControl }.count
    let controls = BaselineChecks.all.count - defects
    print(
      """
      All \(BaselineChecks.all.count) checks matched the `\(revision.rawValue)` \
      expectations for \(label): \(defects) historical defects and \(controls) \
      controls.
      """
    )
    return BaselineExitCode.passed
  }

  // MARK: Support

  private static func makeSupervisor(
    bounds: ProbeBounds
  ) throws -> BaselineSupervisor {
    let scratch = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("hdxl-xpc-baseline-\(getpid())")
    try FileManager.default.createDirectory(
      at: scratch,
      withIntermediateDirectories: true
    )
    createdScratchDirectory = scratch
    return BaselineSupervisor(
      executableURL: try BaselineSupervisor.currentExecutableURL(),
      bounds: bounds,
      scratchDirectory: scratch
    )
  }

  private static func removeScratchDirectory() {
    guard let scratch = createdScratchDirectory else {
      return
    }
    createdScratchDirectory = nil
    try? FileManager.default.removeItem(at: scratch)
  }

  /// Only ever touched from the single-threaded command-line entry point.
  nonisolated(unsafe) private static var createdScratchDirectory: URL?

  private static func describe(_ outcomes: Set<CheckOutcome>) -> String {
    outcomes.map(\.rawValue).sorted().joined(separator: "|")
  }

  static func write(_ message: String, to handle: FileHandle) {
    handle.write(Data("\(message)\n".utf8))
  }

  private static let usage = """
    XPCCodingBaselineProbe — regression-first evidence for the XPCCoding audit

      list
          Print every check, the defect it pins down, and the outcome each
          revision must produce.

      evidence --expect (baseline|current) [--revision-label TEXT]
               [--timeout-seconds S] [--cpu-seconds N] [--memory-mib N]
          Run every check in a bounded child and require the named revision's
          outcomes. This is the command Scripts/run-baseline-evidence.sh runs
          twice: once against the pinned audit revision, once against the
          working tree.

      run CHECK-ID [--cpu-seconds N]
          The bounded child entry point. Runs exactly one check in this process,
          under ceilings it installs on itself.

    This package is built by Scripts/run-baseline-evidence.sh. Built in place it
    links against the working tree; the script also builds an identical copy
    inside an extracted checkout of the audit revision.
    """
}

// MARK: - Argument Parsing

struct ProbeArguments {
  private var arguments: [String]

  init(_ arguments: [String]) {
    self.arguments = arguments
  }

  mutating func positional() -> String? {
    guard let index = arguments.firstIndex(where: { !$0.hasPrefix("--") }) else {
      return nil
    }
    return arguments.remove(at: index)
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
    guard let text = value(for: name) else {
      return defaultValue
    }
    guard let parsed = Int(text), parsed >= minimum else {
      throw BaselineError("\(name) must be an integer of at least \(minimum).")
    }
    return parsed
  }

  mutating func double(
    for name: String,
    default defaultValue: Double,
    minimumExclusive: Double
  ) throws -> Double {
    guard let text = value(for: name) else {
      return defaultValue
    }
    guard let parsed = Double(text), parsed > minimumExclusive else {
      throw BaselineError("\(name) must be greater than \(minimumExclusive).")
    }
    return parsed
  }

  func requireExhausted() throws {
    guard arguments.isEmpty else {
      throw BaselineError(
        "Unexpected arguments: \(arguments.joined(separator: " "))"
      )
    }
  }
}
