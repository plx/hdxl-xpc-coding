import Foundation

struct BenchmarkReport: Codable {
  let schemaVersion: Int
  let environment: BenchmarkEnvironment
  let configuration: BenchmarkRunConfiguration
  let results: [BenchmarkResult]
  let checksum: UInt64
}

struct BenchmarkEnvironment: Codable {
  let timestamp: String
  let operatingSystem: String
  let architecture: String
  let swiftVersion: String
  let xcodeVersion: String
  let hardwareModel: String
  let processorCount: Int
  let physicalMemoryBytes: UInt64
  let gitCommit: String
  let benchmarkHarnessGitCommit: String
  let gitWorkingTreeDirty: Bool
  let buildConfiguration: String
  let optimization: String

  static func capture() -> Self {
    let checkedOutCommit =
      commandOutput("/usr/bin/git", arguments: ["rev-parse", "HEAD"])
      ?? "unknown"
    let environment = ProcessInfo.processInfo.environment
    return Self(
      timestamp: ISO8601DateFormatter().string(from: Date()),
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      architecture: commandOutput("/usr/bin/uname", arguments: ["-m"]) ?? "unknown",
      swiftVersion: commandOutput("/usr/bin/xcrun", arguments: ["swift", "--version"]) ?? "unknown",
      xcodeVersion: commandOutput("/usr/bin/xcodebuild", arguments: ["-version"]) ?? "unknown",
      hardwareModel: commandOutput("/usr/sbin/sysctl", arguments: ["-n", "hw.model"]) ?? "unknown",
      processorCount: ProcessInfo.processInfo.processorCount,
      physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
      gitCommit: environment["XPCCODING_BENCHMARK_MEASURED_COMMIT"]
        ?? checkedOutCommit,
      benchmarkHarnessGitCommit:
        environment["XPCCODING_BENCHMARK_HARNESS_COMMIT"]
        ?? checkedOutCommit,
      gitWorkingTreeDirty: !(commandOutput("/usr/bin/git", arguments: ["status", "--porcelain"]) ?? "").isEmpty,
      buildConfiguration: "release",
      optimization: "-O"
    )
  }
}

struct BenchmarkRunConfiguration: Codable {
  let warmupCount: Int
  let sampleCount: Int
  let targetSampleMilliseconds: Double
  let filters: [String]
  let smoke: Bool
}

struct BenchmarkResult: Codable {
  let name: String
  let category: String
  let operation: String
  let logicalByteCount: Int?
  let encodedXPCObjectCount: Int?
  let iterationsPerSample: Int
  let warmupCount: Int
  let sampleCount: Int
  let nanosecondsPerOperation: [Double]
  let medianNanoseconds: Double
  let p90Nanoseconds: Double
  let p95Nanoseconds: Double
  let p99Nanoseconds: Double
  let meanNanoseconds: Double
  let standardDeviationNanoseconds: Double
  let operationsPerSecond: Double
  let bytesPerSecond: Double?
}

private func commandOutput(
  _ executable: String,
  arguments: [String]
) -> String? {
  let process = Process()
  let output = Pipe()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  process.standardOutput = output
  process.standardError = output

  do {
    try process.run()
    process.waitUntilExit()
  } catch {
    return nil
  }

  guard process.terminationStatus == 0 else {
    return nil
  }

  let data = output.fileHandleForReading.readDataToEndOfFile()
  return String(data: data, encoding: .utf8)?
    .trimmingCharacters(in: .whitespacesAndNewlines)
}
