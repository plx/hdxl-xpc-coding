import Darwin
import Dispatch
import Foundation

// MARK: - Campaign

/// Orchestrates one bounded fuzzing campaign.
///
/// The parent never executes a probe itself. It builds a reproducible case list,
/// runs each case in a bounded child, and turns every failure into a finding
/// with a replay command and a persisted, minimized counterexample.
struct Campaign {

  struct Options {
    var mode: String
    var seed: UInt64
    var generatedCaseCount: Int
    var mutatedCaseCount: Int
    var jobs: Int
    var bounds: ProbeBounds
    var durationSeconds: Double?
    var minimizationChildRunBudget: Int
    var corpusDirectory: URL
    var artifactsDirectory: URL
    var includeCorpus: Bool
  }

  let options: Options
  let runner: ChildRunner
  let executableURL: URL

  // MARK: Execution

  func run() throws -> CampaignReport {
    let start = Date()
    let verification = try Corpus.verify(directory: options.corpusDirectory)
    print(
      """
      Verified \(verification.caseCount) checked-in corpus cases \
      (digest \(verification.digest)).
      """
    )

    let corpusCases =
      options.includeCorpus
      ? try Corpus.loadRunnable(from: options.corpusDirectory)
      : []
    let generatedCases = DescriptorGenerator.descriptors(
      seed: options.seed,
      count: options.generatedCaseCount
    )
    let mutationSources = corpusCases + generatedCases
    let mutatedCases = DescriptorMutator.mutations(
      of: mutationSources,
      seed: options.seed,
      count: options.mutatedCaseCount
    )

    var allCases = corpusCases + generatedCases + mutatedCases
    var generatedCaseCount = generatedCases.count
    var mutatedCaseCount = mutatedCases.count
    print(
      """
      Prepared \(allCases.count) initial cases (digest \
      \(try FuzzingJSON.digest(allCases))) with \(options.jobs) parallel \
      bounded children at \(options.bounds.summary).
      """
    )

    var counts = CampaignCounts()
    var findings: [CampaignFinding] = []
    try executeBatch(
      allCases,
      counts: &counts,
      findings: &findings
    )

    // A duration-bounded campaign keeps extending the generated and mutated
    // population until its deadline, so a scheduled run explores far more than a
    // pull-request run without changing how any single case is reproduced.
    if let durationSeconds = options.durationSeconds {
      let deadline = start.addingTimeInterval(durationSeconds)
      var generatedOffset = options.generatedCaseCount
      var mutatedOffset = options.mutatedCaseCount
      let batchSize = max(options.jobs * 4, 16)
      while Date() < deadline {
        let extraGenerated = DescriptorGenerator.descriptors(
          seed: options.seed,
          count: batchSize,
          startingAt: generatedOffset
        )
        let extraMutated = DescriptorMutator.mutations(
          of: mutationSources + extraGenerated,
          seed: options.seed,
          count: batchSize,
          startingAt: mutatedOffset
        )
        generatedOffset += batchSize
        mutatedOffset += batchSize
        generatedCaseCount += extraGenerated.count
        mutatedCaseCount += extraMutated.count
        let batch = extraGenerated + extraMutated
        allCases.append(contentsOf: batch)
        try executeBatch(batch, counts: &counts, findings: &findings)
        print(
          """
          Progress: \(counts.executed) cases executed, \(counts.failed) failed, \
          \(String(format: "%.0f", deadline.timeIntervalSinceNow))s remaining.
          """
        )
      }
    }

    // Both the digest and the per-origin counts describe every case that
    // actually ran. Computing them before the duration-extension batches would
    // describe only the first batch while appearing to describe the whole run.
    let caseDigest = try FuzzingJSON.digest(allCases)
    let report = CampaignReport(
      startedAt: FuzzingTimestamp.format(start),
      finishedAt: FuzzingTimestamp.now(),
      configuration: CampaignConfiguration(
        mode: options.mode,
        seed: options.seed,
        seedHex: String(format: "0x%016llx", options.seed),
        corpusCaseCount: corpusCases.count,
        generatedCaseCount: generatedCaseCount,
        mutatedCaseCount: mutatedCaseCount,
        jobs: options.jobs,
        bounds: options.bounds,
        durationSecondsLimit: options.durationSeconds,
        minimizationChildRunBudget: options.minimizationChildRunBudget
      ),
      environment: FuzzingEnvironment.capture(executableURL: executableURL),
      corpusDigest: verification.digest,
      caseDigest: caseDigest,
      counts: counts,
      findings: findings
    )

    try write(report: report, to: options.artifactsDirectory)
    return report
  }

  // MARK: Batches

  private func executeBatch(
    _ cases: [ProbeDescriptor],
    counts: inout CampaignCounts,
    findings: inout [CampaignFinding]
  ) throws {
    guard !cases.isEmpty else {
      return
    }
    let outcomes = concurrentResults(
      for: cases,
      jobs: options.jobs
    ) { descriptor in
      do {
        return try runner.run(descriptor)
      } catch {
        return ChildOutcome(
          kind: .unexpectedExit,
          exitStatus: nil,
          signal: nil,
          standardOutput: "",
          standardError: "the harness could not launch a child: \(error)",
          wallClockSeconds: 0,
          peakFootprintBytes: 0,
          cpuSeconds: 0
        )
      }
    }

    for (descriptor, outcome) in zip(cases, outcomes) {
      counts.executed += 1
      guard outcome.kind.isFailure else {
        counts.passed += 1
        continue
      }
      counts.failed += 1
      if outcome.kind.isSafetyViolation {
        counts.safetyViolations += 1
      }
      let finding = try record(descriptor: descriptor, outcome: outcome)
      findings.append(finding)
      print(finding.consoleSummary)
    }
  }

  // MARK: Findings

  private func record(
    descriptor: ProbeDescriptor,
    outcome: ChildOutcome
  ) throws -> CampaignFinding {
    var finding = CampaignFinding(
      id: descriptor.id,
      origin: descriptor.origin,
      seed: descriptor.seed,
      seedHex: descriptor.seedHex,
      probeKind: descriptor.probe.kindName,
      outcome: outcome.kind,
      diagnostic: outcome.diagnostic,
      replayCommand: replayCommand(for: descriptor)
    )

    let counterexamples = options.artifactsDirectory
      .appendingPathComponent("counterexamples")
    try FileManager.default.createDirectory(
      at: counterexamples,
      withIntermediateDirectories: true
    )
    let baseName = fileSafeName(descriptor.id)

    let originalURL = counterexamples.appendingPathComponent(
      "\(baseName)-original.json"
    )
    try FuzzingJSON.encode(descriptor).write(to: originalURL, options: .atomic)
    finding.originalCasePath = originalURL.path
    if descriptor.origin.hasPrefix("seeded-mutation") {
      // A mutated case depends on its whole ancestry, so the persisted file is
      // its reproducible identity.
      finding.replayCommand = "XPCCodingFuzzing replay --case \(originalURL.path)"
    }

    let minimization = Minimizer(
      runner: runner,
      childRunBudget: options.minimizationChildRunBudget
    ).minimize(descriptor, originalOutcome: outcome)
    let minimizedURL = counterexamples.appendingPathComponent(
      "\(baseName)-minimized.json"
    )
    try FuzzingJSON.encode(minimization.descriptor)
      .write(to: minimizedURL, options: .atomic)
    finding.minimizedCasePath = minimizedURL.path
    finding.minimizedReplayCommand =
      "XPCCodingFuzzing replay --case \(minimizedURL.path)"
    finding.minimizationChildRuns = minimization.childRuns
    finding.acceptedReductions = minimization.acceptedReductions
    return finding
  }

  private func replayCommand(for descriptor: ProbeDescriptor) -> String {
    guard descriptor.origin == "seeded-property-generator",
      let index = Int(descriptor.id.dropFirst("generated-".count))
    else {
      return
        "XPCCodingFuzzing replay --seed \(descriptor.seedHex) --case-id \(descriptor.id)"
    }
    return
      "XPCCodingFuzzing replay --seed \(String(format: "0x%016llx", options.seed)) --index \(index)"
  }

  private func fileSafeName(_ id: String) -> String {
    String(
      id.map { character in
        character.isLetter || character.isNumber || character == "-" ? character : "-"
      }
    )
  }

  // MARK: Artifacts

  private func write(
    report: CampaignReport,
    to directory: URL
  ) throws {
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    let reportURL = directory.appendingPathComponent("campaign.json")
    try FuzzingJSON.encode(report).write(to: reportURL, options: .atomic)
    print("Wrote the campaign report to \(reportURL.path).")
  }

}

// MARK: - Bounded Parallelism

/// Runs `body` over `inputs` with at most `jobs` concurrent children and returns
/// the results in input order.
///
/// Output order is independent of completion order, so a campaign's report and
/// its console transcript stay reproducible even though execution is parallel.
func concurrentResults<Input: Sendable, Output: Sendable>(
  for inputs: [Input],
  jobs: Int,
  _ body: @Sendable @escaping (Input) -> Output
) -> [Output] {
  guard jobs > 1, inputs.count > 1 else {
    return inputs.map(body)
  }

  let collector = ResultCollector<Output>()
  let group = DispatchGroup()
  let available = DispatchSemaphore(value: jobs)
  let queue = DispatchQueue.global(qos: .userInitiated)

  for (index, input) in inputs.enumerated() {
    available.wait()
    queue.async(group: group) {
      collector.store(body(input), at: index)
      available.signal()
    }
  }
  group.wait()
  return collector.ordered(count: inputs.count)
}

private final class ResultCollector<Output>: @unchecked Sendable {

  private let lock = NSLock()
  private var results: [Int: Output] = [:]

  func store(_ output: Output, at index: Int) {
    lock.lock()
    results[index] = output
    lock.unlock()
  }

  func ordered(count: Int) -> [Output] {
    lock.lock()
    defer {
      lock.unlock()
    }
    // Every index is stored before the dispatch group completes, so a missing
    // one is a harness defect. Dropping it silently would shift every later
    // outcome onto the wrong descriptor and misreport which case failed.
    return (0..<count).map { index in
      guard let result = results[index] else {
        preconditionFailure("No result was stored for input \(index).")
      }
      return result
    }
  }

}
