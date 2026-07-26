import Dispatch
import Foundation

struct BenchmarkScenario {
  let name: String
  let category: String
  let operation: String
  let logicalByteCount: Int?
  let encodedXPCObjectCount: Int?
  let maximumIterationsPerSample: Int
  let includedInSmokeRun: Bool
  let body: () throws -> UInt64
}

enum BenchmarkRunner {
  static func run(
    scenarios: [BenchmarkScenario],
    configuration: BenchmarkRunConfiguration
  ) throws -> BenchmarkReport {
    var checksum: UInt64 = 0
    var results: [BenchmarkResult] = []

    for scenario in scenarios {
      print("Running \(scenario.name)...")
      let calibration = try measure(iterations: 1, body: scenario.body)
      checksum &+= calibration.checksum

      let targetNanoseconds = configuration.targetSampleMilliseconds * 1_000_000
      let calibratedIterations = max(
        1,
        min(
          scenario.maximumIterationsPerSample,
          Int(targetNanoseconds / max(calibration.nanoseconds, 1))
        )
      )

      for _ in 0..<configuration.warmupCount {
        checksum &+= try measure(
          iterations: calibratedIterations,
          body: scenario.body
        ).checksum
      }

      var samples: [Double] = []
      samples.reserveCapacity(configuration.sampleCount)
      for _ in 0..<configuration.sampleCount {
        let measurement = try measure(
          iterations: calibratedIterations,
          body: scenario.body
        )
        checksum &+= measurement.checksum
        samples.append(measurement.nanoseconds / Double(calibratedIterations))
      }

      results.append(
        result(
          for: scenario,
          iterationsPerSample: calibratedIterations,
          configuration: configuration,
          samples: samples
        )
      )
    }

    return BenchmarkReport(
      schemaVersion: 1,
      environment: .capture(),
      configuration: configuration,
      results: results,
      checksum: checksum
    )
  }

  private static func measure(
    iterations: Int,
    body: () throws -> UInt64
  ) throws -> (nanoseconds: Double, checksum: UInt64) {
    var checksum: UInt64 = 0
    let start = DispatchTime.now().uptimeNanoseconds
    for _ in 0..<iterations {
      checksum &+= try body()
    }
    let end = DispatchTime.now().uptimeNanoseconds
    return (Double(end - start), checksum)
  }

  private static func result(
    for scenario: BenchmarkScenario,
    iterationsPerSample: Int,
    configuration: BenchmarkRunConfiguration,
    samples: [Double]
  ) -> BenchmarkResult {
    let sortedSamples = samples.sorted()
    let median = percentile(0.5, in: sortedSamples)
    let mean = samples.reduce(0, +) / Double(samples.count)
    let variance =
      samples.reduce(0) {
        $0 + ($1 - mean) * ($1 - mean)
      } / Double(samples.count)
    let operationsPerSecond = 1_000_000_000 / median

    return BenchmarkResult(
      name: scenario.name,
      category: scenario.category,
      operation: scenario.operation,
      logicalByteCount: scenario.logicalByteCount,
      encodedXPCObjectCount: scenario.encodedXPCObjectCount,
      iterationsPerSample: iterationsPerSample,
      warmupCount: configuration.warmupCount,
      sampleCount: configuration.sampleCount,
      nanosecondsPerOperation: samples,
      medianNanoseconds: median,
      p90Nanoseconds: percentile(0.90, in: sortedSamples),
      p95Nanoseconds: percentile(0.95, in: sortedSamples),
      p99Nanoseconds: percentile(0.99, in: sortedSamples),
      meanNanoseconds: mean,
      standardDeviationNanoseconds: variance.squareRoot(),
      operationsPerSecond: operationsPerSecond,
      bytesPerSecond: scenario.logicalByteCount.map {
        Double($0) * operationsPerSecond
      }
    )
  }

  private static func percentile(
    _ percentile: Double,
    in sortedValues: [Double]
  ) -> Double {
    guard sortedValues.count > 1 else {
      return sortedValues[0]
    }

    let position = percentile * Double(sortedValues.count - 1)
    let lowerIndex = Int(position.rounded(.down))
    let upperIndex = Int(position.rounded(.up))
    let fraction = position - Double(lowerIndex)
    return sortedValues[lowerIndex]
      + ((sortedValues[upperIndex] - sortedValues[lowerIndex]) * fraction)
  }
}
