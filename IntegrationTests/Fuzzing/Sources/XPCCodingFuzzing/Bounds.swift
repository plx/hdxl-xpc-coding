import Darwin
import Foundation

// MARK: - Probe Bounds

/// The wall-clock, CPU, and memory ceilings applied to every hostile case.
///
/// The bounds are deliberately independent. A defect that spins without
/// allocating is caught by CPU time, one that blocks without spinning is caught
/// by the wall clock, and one that allocates without spinning is caught by the
/// footprint ceiling.
struct ProbeBounds: Codable, Equatable, Sendable {
  var wallClockSeconds: Double
  var cpuSeconds: Int
  var memoryMebibytes: Int

  static let standard = Self(
    wallClockSeconds: 20,
    cpuSeconds: 10,
    memoryMebibytes: 1_024
  )

  /// Tighter bounds for the bounded pull-request campaign.
  static let smoke = Self(
    wallClockSeconds: 10,
    cpuSeconds: 5,
    memoryMebibytes: 768
  )

  var memoryBytes: UInt64 {
    UInt64(max(1, memoryMebibytes)) * 1_024 * 1_024
  }

  func validated() throws -> Self {
    guard wallClockSeconds > 0 else {
      throw FuzzingError("--timeout-seconds must be greater than zero.")
    }
    guard cpuSeconds >= 1 else {
      throw FuzzingError("--cpu-seconds must be at least one.")
    }
    guard memoryMebibytes >= 64 else {
      throw FuzzingError("--memory-mib must be at least 64.")
    }
    return self
  }

  var summary: String {
    """
    wall \(String(format: "%.1f", wallClockSeconds))s, cpu \(cpuSeconds)s, \
    memory \(memoryMebibytes) MiB
    """
  }
}

// MARK: - Child-Side Enforcement

enum ProbeSandbox {

  /// Installs the kernel-enforced ceilings a child applies to itself.
  ///
  /// `RLIMIT_CPU` and `RLIMIT_CORE` are honored on the supported target.
  /// `RLIMIT_AS` and `RLIMIT_DATA` are not: Darwin rejects them with `EINVAL`,
  /// so the memory ceiling is enforced by the parent, which samples the child's
  /// physical footprint and kills it on breach.
  ///
  /// A failure here is fatal rather than ignored. A child that silently ran
  /// without the ceilings it reported would turn a CPU overrun into an
  /// indefinite hang and a trap into a core dump, which is precisely the
  /// failure mode these bounds exist to prevent.
  static func apply(_ bounds: ProbeBounds) throws {
    try install(
      RLIMIT_CORE,
      name: "RLIMIT_CORE",
      soft: 0,
      hard: 0
    )
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
      throw FuzzingError(
        """
        Unable to install \(name) (soft \(soft), hard \(hard)): \
        \(String(cString: strerror(code))) (errno \(code)).
        """
      )
    }
  }

}

// MARK: - Resource Measurement

enum ResourceUsage {

  /// The physical footprint of `processIdentifier`, or `nil` once it has exited.
  static func physicalFootprintBytes(of processIdentifier: pid_t) -> UInt64? {
    guard let info = rusage(of: processIdentifier) else {
      return nil
    }
    return info.ri_phys_footprint
  }

  /// The CPU seconds `processIdentifier` has consumed, or `nil` once it exited.
  static func cpuSeconds(of processIdentifier: pid_t) -> Double? {
    guard let info = rusage(of: processIdentifier) else {
      return nil
    }
    return Double(info.ri_user_time + info.ri_system_time) / 1_000_000_000
  }

  private static func rusage(
    of processIdentifier: pid_t
  ) -> rusage_info_current? {
    var info = rusage_info_current()
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
        proc_pid_rusage(processIdentifier, RUSAGE_INFO_CURRENT, rebound)
      }
    }
    guard result == 0 else {
      return nil
    }
    return info
  }

}
