import Darwin
import Foundation

enum BenchmarkCLI {
  static func run(arguments: [String]) throws {
    switch arguments.first {
    case nil, "help", "--help", "-h":
      print(usage)
    case "list":
      for scenario in try BenchmarkScenarios.all() {
        print(scenario.name)
      }
    case "run":
      try runBenchmarks(arguments: Array(arguments.dropFirst()))
    case "compare":
      try compare(arguments: Array(arguments.dropFirst()))
    case "self-test":
      try BenchmarkComparator.selfTest()
      print("Comparator self-test passed.")
    case .some(let command):
      throw CLIError("Unknown command: \(command)\n\n\(usage)")
    }
  }

  private static func runBenchmarks(arguments: [String]) throws {
    #if DEBUG
      throw CLIError("Benchmarks must be built and run with `swift run -c release`.")
    #else
      var parser = ArgumentParser(arguments)
      let outputPath = parser.value(for: "--output") ?? ".build/benchmarks/latest.json"
      let smoke = parser.flag("--smoke")
      let filters = parser.values(for: "--filter")
      let warmupCount = try parser.integer(
        for: "--warmup",
        default: smoke ? 1 : 2,
        minimum: 0
      )
      let sampleCount = try parser.integer(
        for: "--samples",
        default: smoke ? 3 : 9,
        minimum: 1
      )
      let targetSampleMilliseconds = try parser.double(
        for: "--target-sample-ms",
        default: smoke ? 1 : 50,
        minimumExclusive: 0
      )
      try parser.requireExhausted()

      var scenarios = try BenchmarkScenarios.all(smokeOnly: smoke)
      if !filters.isEmpty {
        scenarios = scenarios.filter { scenario in
          filters.contains { scenario.name.contains($0) }
        }
      }
      guard !scenarios.isEmpty else {
        throw CLIError("No scenarios matched the requested filters.")
      }

      let configuration = BenchmarkRunConfiguration(
        warmupCount: warmupCount,
        sampleCount: sampleCount,
        targetSampleMilliseconds: targetSampleMilliseconds,
        filters: filters,
        smoke: smoke
      )
      let report = try BenchmarkRunner.run(
        scenarios: scenarios,
        configuration: configuration
      )
      try write(report: report, to: outputPath)
      print("Checksum: \(report.checksum)")
      print("Wrote \(report.results.count) results to \(outputPath)")
    #endif
  }

  private static func compare(arguments: [String]) throws {
    var parser = ArgumentParser(arguments)
    let threshold = try parser.double(
      for: "--threshold-percent",
      default: 10,
      minimumExclusive: 0
    )
    guard let baselinePath = parser.positional(),
      let candidatePath = parser.positional()
    else {
      throw CLIError(
        "compare requires BASELINE.json and CANDIDATE.json paths."
      )
    }
    try parser.requireExhausted()

    let baseline = try loadReport(at: baselinePath)
    let candidate = try loadReport(at: candidatePath)
    let failures = BenchmarkComparator.failures(
      baseline: baseline,
      candidate: candidate,
      thresholdPercent: threshold
    )
    if failures.isEmpty {
      print(
        "Compared \(baseline.results.count) scenarios; "
          + "none regressed by more than \(threshold)%."
      )
    } else {
      for failure in failures {
        print("ERROR: \(failure)")
      }
      throw CLIError("Benchmark comparison failed with \(failures.count) finding(s).")
    }
  }

  private static func write(
    report: BenchmarkReport,
    to path: String
  ) throws {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(report).write(to: url, options: .atomic)
  }

  private static func loadReport(at path: String) throws -> BenchmarkReport {
    try JSONDecoder().decode(
      BenchmarkReport.self,
      from: Data(contentsOf: URL(fileURLWithPath: path))
    )
  }

  private static let usage = """
    XPCCodingBenchmarks

      list
      run [--output PATH] [--warmup N] [--samples N]
          [--target-sample-ms MS] [--filter TEXT ...] [--smoke]
      compare BASELINE.json CANDIDATE.json [--threshold-percent PERCENT]
      self-test
    """
}

enum BenchmarkComparator {
  static func failures(
    baseline: BenchmarkReport,
    candidate: BenchmarkReport,
    thresholdPercent: Double
  ) -> [String] {
    var failures: [String] = []
    if baseline.schemaVersion != candidate.schemaVersion {
      failures.append(
        "schema versions differ (baseline \(baseline.schemaVersion), "
          + "candidate \(candidate.schemaVersion))"
      )
    }

    let duplicateBaselineNames = duplicateNames(in: baseline.results)
    let duplicateCandidateNames = duplicateNames(in: candidate.results)
    failures.append(
      contentsOf: duplicateBaselineNames.map {
        "baseline repeats scenario `\($0)`"
      }
    )
    failures.append(
      contentsOf: duplicateCandidateNames.map {
        "candidate repeats scenario `\($0)`"
      }
    )

    let baselineResults = Dictionary(
      baseline.results.map { ($0.name, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    let candidateResults = Dictionary(
      candidate.results.map { ($0.name, $0) },
      uniquingKeysWith: { first, _ in first }
    )

    for name in baselineResults.keys.sorted() where candidateResults[name] == nil {
      failures.append("candidate is missing scenario `\(name)`")
    }
    for name in candidateResults.keys.sorted() where baselineResults[name] == nil {
      failures.append("baseline is missing scenario `\(name)`")
    }

    for name in baselineResults.keys.sorted() {
      guard let baselineResult = baselineResults[name],
        let candidateResult = candidateResults[name]
      else {
        continue
      }
      let allowed =
        baselineResult.medianNanoseconds
        * (1 + thresholdPercent / 100)
      if candidateResult.medianNanoseconds > allowed {
        let change =
          (candidateResult.medianNanoseconds
            / baselineResult.medianNanoseconds - 1) * 100
        failures.append(
          "`\(name)` median regressed by "
            + String(format: "%.2f", change)
            + "%"
        )
      }
    }
    return failures
  }

  private static func duplicateNames(
    in results: [BenchmarkResult]
  ) -> [String] {
    var seen: Set<String> = []
    var duplicates: Set<String> = []
    for result in results where !seen.insert(result.name).inserted {
      duplicates.insert(result.name)
    }
    return duplicates.sorted()
  }

  static func selfTest() throws {
    let baseline = syntheticReport(
      results: [
        syntheticResult(name: "stable", median: 100),
        syntheticResult(name: "regressed", median: 100),
        syntheticResult(name: "missing", median: 100),
      ]
    )
    let candidate = syntheticReport(
      results: [
        syntheticResult(name: "stable", median: 105),
        syntheticResult(name: "regressed", median: 111),
        syntheticResult(name: "extra", median: 100),
      ]
    )
    let findings = failures(
      baseline: baseline,
      candidate: candidate,
      thresholdPercent: 10
    )
    guard findings.count == 3,
      findings.contains(where: { $0.contains("regressed") }),
      findings.contains(where: { $0.contains("missing") }),
      findings.contains(where: { $0.contains("extra") })
    else {
      throw CLIError("Comparator self-test failed: \(findings)")
    }
  }

  private static func syntheticReport(
    results: [BenchmarkResult]
  ) -> BenchmarkReport {
    BenchmarkReport(
      schemaVersion: 1,
      environment: BenchmarkEnvironment.capture(),
      configuration: BenchmarkRunConfiguration(
        warmupCount: 0,
        sampleCount: 1,
        targetSampleMilliseconds: 1,
        filters: [],
        smoke: true
      ),
      results: results,
      checksum: 0
    )
  }

  private static func syntheticResult(
    name: String,
    median: Double
  ) -> BenchmarkResult {
    BenchmarkResult(
      name: name,
      category: "synthetic",
      operation: "test",
      logicalByteCount: nil,
      encodedXPCObjectCount: nil,
      iterationsPerSample: 1,
      warmupCount: 0,
      sampleCount: 1,
      nanosecondsPerOperation: [median],
      medianNanoseconds: median,
      p90Nanoseconds: median,
      p95Nanoseconds: median,
      p99Nanoseconds: median,
      meanNanoseconds: median,
      standardDeviationNanoseconds: 0,
      operationsPerSecond: 1_000_000_000 / median,
      bytesPerSecond: nil
    )
  }
}

struct ArgumentParser {
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

  mutating func values(for name: String) -> [String] {
    var result: [String] = []
    while let value = value(for: name) {
      result.append(value)
    }
    return result
  }

  mutating func positional() -> String? {
    guard let index = arguments.firstIndex(where: { !$0.hasPrefix("--") }) else {
      return nil
    }
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
    guard let value = Int(text), value >= minimum else {
      throw CLIError("\(name) must be an integer greater than or equal to \(minimum).")
    }
    return value
  }

  mutating func double(
    for name: String,
    default defaultValue: Double,
    minimumExclusive: Double
  ) throws -> Double {
    guard let text = value(for: name) else {
      return defaultValue
    }
    guard let value = Double(text), value > minimumExclusive else {
      throw CLIError("\(name) must be greater than \(minimumExclusive).")
    }
    return value
  }

  func requireExhausted() throws {
    guard arguments.isEmpty else {
      throw CLIError("Unexpected arguments: \(arguments.joined(separator: " "))")
    }
  }
}

struct CLIError: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}
