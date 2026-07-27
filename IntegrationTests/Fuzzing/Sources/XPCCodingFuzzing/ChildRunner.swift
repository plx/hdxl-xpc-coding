import Darwin
import Foundation

// MARK: - Exit Codes

enum FuzzingExitCode {
  /// The probe satisfied its expectation.
  static let passed: Int32 = 0
  /// The command line was malformed.
  static let usage: Int32 = 64
  /// The probe ran to completion and violated its expectation.
  static let probeFailed: Int32 = 65
  /// The harness itself could not run the case.
  static let harnessFailed: Int32 = 70
}

// MARK: - Outcome

enum ChildOutcomeKind: String, Codable, Sendable {
  case passed
  case probeFailed
  case timedOut
  case memoryExceeded
  case cpuExceeded
  case crashed
  case unexpectedExit

  var isFailure: Bool {
    self != .passed
  }

  /// Whether this outcome is a category the package must never produce.
  ///
  /// These are never "tolerated findings": a crash, hang, or breached bound is a
  /// harness failure even if the probe's own assertions never ran.
  var isSafetyViolation: Bool {
    switch self {
    case .timedOut, .memoryExceeded, .cpuExceeded, .crashed:
      true
    case .passed, .probeFailed, .unexpectedExit:
      false
    }
  }
}

struct ChildOutcome: Codable, Sendable {
  var kind: ChildOutcomeKind
  var exitStatus: Int32?
  var signal: Int32?
  var standardOutput: String
  var standardError: String
  var wallClockSeconds: Double
  var peakFootprintBytes: UInt64
  var cpuSeconds: Double

  var diagnostic: String {
    var lines: [String] = []
    lines.append("outcome: \(kind.rawValue)")
    if let exitStatus {
      lines.append("exit status: \(exitStatus)")
    }
    if let signal {
      lines.append("signal: \(signal) (\(signalName(signal)))")
    }
    lines.append(
      """
      measured: wall \(String(format: "%.3f", wallClockSeconds))s, \
      cpu \(String(format: "%.3f", cpuSeconds))s, \
      peak footprint \(peakFootprintBytes / 1_024) KiB
      """
    )
    let trimmedError = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedError.isEmpty {
      lines.append("stderr: \(trimmedError)")
    }
    let trimmedOutput = standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedOutput.isEmpty {
      lines.append("stdout: \(trimmedOutput)")
    }
    return lines.joined(separator: "\n  ")
  }
}

private func signalName(_ signal: Int32) -> String {
  guard let name = strsignal(signal) else {
    return "unknown"
  }
  return String(cString: name)
}

// MARK: - Child Runner

/// Runs one descriptor in a fresh child process under strict bounds.
///
/// Every hostile case crosses a process boundary. A trap, stack exhaustion, or
/// runaway allocation therefore becomes a reported failure with a replayable
/// seed instead of terminating the campaign.
struct ChildRunner: Sendable {
  let executableURL: URL
  let bounds: ProbeBounds
  let scratchDirectory: URL

  /// How often the parent samples the child's footprint and elapsed time.
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
      throw FuzzingError(
        "Unable to locate this executable in order to spawn child processes."
      )
    }
    return url
  }

  func run(_ descriptor: ProbeDescriptor) throws -> ChildOutcome {
    let caseDirectory = scratchDirectory.appendingPathComponent(
      "case-\(descriptor.seedHex)-\(UUID().uuidString)"
    )
    try FileManager.default.createDirectory(
      at: caseDirectory,
      withIntermediateDirectories: true
    )
    defer {
      try? FileManager.default.removeItem(at: caseDirectory)
    }

    let descriptorURL = caseDirectory.appendingPathComponent("descriptor.json")
    try FuzzingJSON.encode(descriptor).write(to: descriptorURL, options: .atomic)
    let outputURL = caseDirectory.appendingPathComponent("stdout.txt")
    let errorURL = caseDirectory.appendingPathComponent("stderr.txt")
    FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    FileManager.default.createFile(atPath: errorURL.path, contents: nil)

    // Writing to files rather than pipes keeps a chatty or killed child from
    // ever deadlocking the parent on a full pipe buffer. The parent's own
    // descriptors are closed as soon as the child exits, so a campaign that
    // runs thousands of cases never accumulates open files.
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
      "run-case",
      "--descriptor", descriptorURL.path,
      "--cpu-seconds", String(bounds.cpuSeconds),
    ]
    process.standardOutput = outputHandle
    process.standardError = errorHandle
    process.standardInput = FileHandle.nullDevice

    let start = Date()
    try process.run()
    let supervision = supervise(process, start: start)
    process.waitUntilExit()
    let wallClockSeconds = Date().timeIntervalSince(start)

    return ChildOutcome(
      kind: classify(process, supervision: supervision),
      exitStatus: process.terminationReason == .exit
        ? process.terminationStatus
        : nil,
      signal: process.terminationReason == .uncaughtSignal
        ? process.terminationStatus
        : nil,
      standardOutput: text(at: outputURL),
      standardError: text(at: errorURL),
      wallClockSeconds: wallClockSeconds,
      peakFootprintBytes: supervision.peakFootprintBytes,
      cpuSeconds: supervision.cpuSeconds
    )
  }

  // MARK: Supervision

  private struct Supervision {
    var peakFootprintBytes: UInt64 = 0
    var cpuSeconds: Double = 0
    var killedFor: ChildOutcomeKind?
  }

  private func supervise(
    _ process: Process,
    start: Date
  ) -> Supervision {
    var supervision = Supervision()
    let processIdentifier = process.processIdentifier
    let memoryLimit = bounds.memoryBytes

    while process.isRunning {
      if let footprint = ResourceUsage.physicalFootprintBytes(of: processIdentifier) {
        supervision.peakFootprintBytes = max(
          supervision.peakFootprintBytes,
          footprint
        )
      }
      if let cpu = ResourceUsage.cpuSeconds(of: processIdentifier) {
        supervision.cpuSeconds = max(supervision.cpuSeconds, cpu)
      }

      if supervision.peakFootprintBytes > memoryLimit {
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
    supervision: Supervision
  ) -> ChildOutcomeKind {
    if let killedFor = supervision.killedFor {
      return killedFor
    }
    switch process.terminationReason {
    case .uncaughtSignal:
      return process.terminationStatus == SIGXCPU ? .cpuExceeded : .crashed
    case .exit:
      switch process.terminationStatus {
      case FuzzingExitCode.passed:
        return .passed
      case FuzzingExitCode.probeFailed:
        return .probeFailed
      default:
        return .unexpectedExit
      }
    @unknown default:
      return .unexpectedExit
    }
  }

  private func text(at url: URL) -> String {
    guard let data = try? Data(contentsOf: url) else {
      return ""
    }
    return String(decoding: data, as: UTF8.self)
  }

}

extension FileManager {

  fileprivate func createFile(atPath path: String, contents: Data?) {
    createFile(atPath: path, contents: contents, attributes: nil)
  }

}
