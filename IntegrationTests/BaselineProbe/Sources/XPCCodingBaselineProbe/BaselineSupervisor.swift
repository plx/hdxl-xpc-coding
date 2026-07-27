import Darwin
import Foundation

// MARK: - Bounds

/// The ceilings applied to every check.
///
/// Three of the historical defects kill the process at the baseline revision.
/// Bounding them is not a precaution here; it is the only way the baseline half
/// of this evidence can run to completion at all.
struct ProbeBounds: Sendable {
  var wallClockSeconds: Double = 30
  var cpuSeconds: Int = 15
  var memoryMebibytes: Int = 1_024

  var memoryBytes: UInt64 {
    UInt64(max(1, memoryMebibytes)) * 1_024 * 1_024
  }

  var summary: String {
    """
    wall \(String(format: "%.0f", wallClockSeconds))s, cpu \(cpuSeconds)s, \
    memory \(memoryMebibytes) MiB
    """
  }
}

// MARK: - Child-Side Enforcement

enum ProbeSandbox {

  /// Installs the kernel-enforced ceilings a child applies to itself.
  ///
  /// `RLIMIT_AS` and `RLIMIT_DATA` are deliberately unused: Darwin rejects both
  /// with `EINVAL`, so a probe that "set" them would report a memory bound it
  /// does not have. The parent's footprint sampling is the real ceiling.
  ///
  /// A failure is fatal rather than ignored. Three of these checks are expected
  /// to trap, and a child running without `RLIMIT_CORE` would write a core dump
  /// for each one.
  static func apply(_ bounds: ProbeBounds) throws {
    try install(RLIMIT_CORE, name: "RLIMIT_CORE", soft: 0, hard: 0)
    let cpuSeconds = rlim_t(max(1, bounds.cpuSeconds))
    try install(
      RLIMIT_CPU,
      name: "RLIMIT_CPU",
      soft: cpuSeconds,
      hard: cpuSeconds + 1
    )
  }

  private static func install(
    _ resource: Int32,
    name: String,
    soft: rlim_t,
    hard: rlim_t
  ) throws {
    var limit = rlimit(rlim_cur: soft, rlim_max: hard)
    guard setrlimit(resource, &limit) == 0 else {
      let code = errno
      throw BaselineError(
        """
        Unable to install \(name) (soft \(soft), hard \(hard)): \
        \(String(cString: strerror(code))) (errno \(code)).
        """
      )
    }
  }

}

// MARK: - Result

struct CheckExecution: Sendable {
  var outcome: CheckOutcome
  var detail: String
  var signal: Int32?
  var wallClockSeconds: Double

  var signalDescription: String? {
    guard let signal, let name = strsignal(signal) else {
      return nil
    }
    return "signal \(signal) (\(String(cString: name)))"
  }
}

// MARK: - Supervisor

/// Runs one check in a fresh child process under strict bounds.
///
/// The parent never executes a check itself, so a trap or a runaway recursion
/// becomes a classified outcome rather than the end of the evidence run.
struct BaselineSupervisor {
  let executableURL: URL
  let bounds: ProbeBounds
  let scratchDirectory: URL

  private static let pollInterval: TimeInterval = 0.01

  static func currentExecutableURL() throws -> URL {
    if let url = Bundle.main.executableURL,
      FileManager.default.isExecutableFile(atPath: url.path)
    {
      return url.resolvingSymlinksInPath()
    }
    let argumentZero = CommandLine.arguments.first ?? ""
    let url = URL(fileURLWithPath: argumentZero).resolvingSymlinksInPath()
    guard FileManager.default.isExecutableFile(atPath: url.path) else {
      throw BaselineError(
        "Unable to locate this executable in order to spawn child processes."
      )
    }
    return url
  }

  func run(_ check: BaselineCheck) throws -> CheckExecution {
    let caseDirectory = scratchDirectory.appendingPathComponent(
      "check-\(fileSafeName(check.id))"
    )
    try FileManager.default.createDirectory(
      at: caseDirectory,
      withIntermediateDirectories: true
    )
    defer {
      try? FileManager.default.removeItem(at: caseDirectory)
    }

    let outputURL = caseDirectory.appendingPathComponent("stdout.txt")
    let errorURL = caseDirectory.appendingPathComponent("stderr.txt")
    FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    FileManager.default.createFile(atPath: errorURL.path, contents: nil)

    // Files rather than pipes: a child that dies mid-write can never leave the
    // parent blocked on a full pipe buffer.
    let outputHandle = try FileHandle(forWritingTo: outputURL)
    defer {
      try? outputHandle.close()
    }
    let errorHandle = try FileHandle(forWritingTo: errorURL)
    defer {
      try? errorHandle.close()
    }

    let process = Process()
    process.executableURL = executableURL
    process.arguments = [
      "run", check.id,
      "--cpu-seconds", String(bounds.cpuSeconds),
    ]
    process.standardOutput = outputHandle
    process.standardError = errorHandle
    process.standardInput = FileHandle.nullDevice

    let start = Date()
    try process.run()
    let supervision = supervise(process, start: start)
    process.waitUntilExit()
    let elapsed = Date().timeIntervalSince(start)

    return classify(
      process,
      supervision: supervision,
      standardOutput: text(at: outputURL),
      standardError: text(at: errorURL),
      wallClockSeconds: elapsed
    )
  }

  // MARK: Supervision

  private struct Supervision {
    var killedFor: CheckOutcome?
  }

  private func supervise(_ process: Process, start: Date) -> Supervision {
    var supervision = Supervision()
    let processIdentifier = process.processIdentifier
    let memoryLimit = bounds.memoryBytes

    while process.isRunning {
      if let footprint = physicalFootprintBytes(of: processIdentifier),
        footprint > memoryLimit
      {
        supervision.killedFor = .memoryExceeded
        kill(processIdentifier, SIGKILL)
        break
      }
      if Date().timeIntervalSince(start) > bounds.wallClockSeconds {
        supervision.killedFor = .timedOut
        kill(processIdentifier, SIGKILL)
        break
      }
      usleep(useconds_t(Self.pollInterval * 1_000_000))
    }
    return supervision
  }

  private func classify(
    _ process: Process,
    supervision: Supervision,
    standardOutput: String,
    standardError: String,
    wallClockSeconds: Double
  ) -> CheckExecution {
    if let killedFor = supervision.killedFor {
      return CheckExecution(
        outcome: killedFor,
        detail: diagnostic(standardOutput, standardError),
        signal: SIGKILL,
        wallClockSeconds: wallClockSeconds
      )
    }

    switch process.terminationReason {
    case .uncaughtSignal:
      let signal = process.terminationStatus
      return CheckExecution(
        outcome: signal == SIGXCPU ? .cpuExceeded : .crashed,
        detail: diagnostic(standardOutput, standardError),
        signal: signal,
        wallClockSeconds: wallClockSeconds
      )
    case .exit where process.terminationStatus == BaselineExitCode.passed:
      guard let reported = Self.parseObservation(standardOutput) else {
        return CheckExecution(
          outcome: .unexpectedExit,
          detail: """
            the child exited cleanly without reporting an observation: \
            \(diagnostic(standardOutput, standardError))
            """,
          signal: nil,
          wallClockSeconds: wallClockSeconds
        )
      }
      return CheckExecution(
        outcome: reported.outcome,
        detail: reported.detail,
        signal: nil,
        wallClockSeconds: wallClockSeconds
      )
    default:
      return CheckExecution(
        outcome: .unexpectedExit,
        detail: """
          exit status \(process.terminationStatus): \
          \(diagnostic(standardOutput, standardError))
          """,
        signal: nil,
        wallClockSeconds: wallClockSeconds
      )
    }
  }

  /// The single line a completed child uses to report what it saw.
  static let observationPrefix = "OBSERVATION "

  static func parseObservation(_ standardOutput: String) -> CheckObservation? {
    for line in standardOutput.split(separator: "\n", omittingEmptySubsequences: true)
    where line.hasPrefix(observationPrefix) {
      let payload = line.dropFirst(observationPrefix.count)
      guard let separator = payload.firstIndex(of: " ") else {
        guard let outcome = CheckOutcome(rawValue: String(payload)) else {
          return nil
        }
        return CheckObservation(outcome, "")
      }
      guard let outcome = CheckOutcome(rawValue: String(payload[..<separator]))
      else {
        return nil
      }
      return CheckObservation(
        outcome,
        String(payload[payload.index(after: separator)...])
      )
    }
    return nil
  }

  private func diagnostic(
    _ standardOutput: String,
    _ standardError: String
  ) -> String {
    let parts = [standardError, standardOutput]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .map { $0.replacingOccurrences(of: "\n", with: "; ") }
    return parts.isEmpty ? "no output" : parts.joined(separator: " | ")
  }

  private func text(at url: URL) -> String {
    guard let data = try? Data(contentsOf: url) else {
      return ""
    }
    return String(decoding: data, as: UTF8.self)
  }

  private func fileSafeName(_ id: String) -> String {
    String(
      id.map { character in
        character.isLetter || character.isNumber || character == "-"
          ? character
          : "-"
      }
    )
  }

}

// MARK: - Resource Measurement

/// The physical footprint of `processIdentifier`, or `nil` once it has exited.
private func physicalFootprintBytes(of processIdentifier: pid_t) -> UInt64? {
  var info = rusage_info_current()
  let result = withUnsafeMutablePointer(to: &info) { pointer in
    pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
      proc_pid_rusage(processIdentifier, RUSAGE_INFO_CURRENT, rebound)
    }
  }
  guard result == 0 else {
    return nil
  }
  return info.ri_phys_footprint
}

extension FileManager {

  fileprivate func createFile(atPath path: String, contents: Data?) {
    createFile(atPath: path, contents: contents, attributes: nil)
  }

}
