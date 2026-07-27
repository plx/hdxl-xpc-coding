import Darwin
import Foundation

// MARK: - Environment

struct FuzzingEnvironment: Codable, Sendable {
  var operatingSystem: String
  var architecture: String
  var activeProcessorCount: Int
  var executablePath: String

  static func capture(executableURL: URL) -> Self {
    Self(
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      architecture: machineArchitecture(),
      activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
      executablePath: executableURL.path
    )
  }

  private static func machineArchitecture() -> String {
    var info = utsname()
    guard uname(&info) == 0 else {
      return "unknown"
    }
    return withUnsafeBytes(of: &info.machine) { bytes in
      String(
        decoding: bytes.prefix { $0 != 0 }.map { UInt8($0) },
        as: UTF8.self
      )
    }
  }
}

// MARK: - Configuration

struct CampaignConfiguration: Codable, Sendable {
  var mode: String
  var seed: UInt64
  var seedHex: String
  var corpusCaseCount: Int
  var generatedCaseCount: Int
  var mutatedCaseCount: Int
  var jobs: Int
  var bounds: ProbeBounds
  var durationSecondsLimit: Double?
  var minimizationChildRunBudget: Int
}

// MARK: - Counts

struct CampaignCounts: Codable, Sendable {
  var executed: Int = 0
  var passed: Int = 0
  var failed: Int = 0
  var safetyViolations: Int = 0
}

// MARK: - Finding

struct CampaignFinding: Codable, Sendable {
  var id: String
  var origin: String
  var seed: UInt64
  var seedHex: String
  var probeKind: String
  var outcome: ChildOutcomeKind
  var diagnostic: String
  var replayCommand: String
  var originalCasePath: String?
  var minimizedCasePath: String?
  var minimizedReplayCommand: String?
  var minimizationChildRuns: Int?
  var acceptedReductions: Int?

  var consoleSummary: String {
    var lines = [
      "FINDING \(id) [\(probeKind)] outcome=\(outcome.rawValue)",
      "  seed: \(seedHex) (\(seed))",
      "  \(diagnostic)",
      "  replay: \(replayCommand)",
    ]
    if let minimizedReplayCommand {
      lines.append("  minimized replay: \(minimizedReplayCommand)")
    }
    if let minimizedCasePath {
      lines.append("  minimized case: \(minimizedCasePath)")
    }
    return lines.joined(separator: "\n")
  }
}

// MARK: - Report

/// One campaign's local run record.
///
/// This is a diagnostic artifact for the run that produced it, read by a human
/// or by the CI job that uploaded it. It is deliberately unversioned: XPCCoding
/// has no format version, and a version field here would invite reading this
/// file as a contract rather than as a record.
struct CampaignReport: Codable, Sendable {
  var startedAt: String
  var finishedAt: String
  var configuration: CampaignConfiguration
  var environment: FuzzingEnvironment
  var corpusDigest: String
  var caseDigest: String
  var counts: CampaignCounts
  var findings: [CampaignFinding]

  var succeeded: Bool {
    findings.isEmpty
  }

  var consoleSummary: String {
    """
    seed \(configuration.seedHex): executed \(counts.executed) cases \
    (\(configuration.corpusCaseCount) corpus, \
    \(configuration.generatedCaseCount) generated, \
    \(configuration.mutatedCaseCount) mutated) under \
    \(configuration.bounds.summary); \(counts.failed) failed, \
    \(counts.safetyViolations) safety violations.
    corpus digest \(corpusDigest), case digest \(caseDigest).
    """
  }
}

// MARK: - Determinism Report

/// Evidence that one seed produces one case list, run after run.
struct DeterminismReport: Codable, Sendable {
  var seed: UInt64
  var seedHex: String
  var caseCount: Int
  var repeatCount: Int
  var digests: [String]
  var executedOutcomes: [String]

  var isStable: Bool {
    Set(digests).count == 1 && Set(executedOutcomes).count <= 1
  }
}

// MARK: - Timestamps

enum FuzzingTimestamp {

  static func now() -> String {
    format(Date())
  }

  static func format(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
  }

}
