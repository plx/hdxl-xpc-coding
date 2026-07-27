import Foundation

// MARK: - Revision Under Test

/// Which revision of XPCCoding this probe binary is linked against.
///
/// The probe cannot detect this for itself, and that is deliberate: it compiles
/// against only the public API that existed at the baseline revision, so one set
/// of sources links against either revision unchanged. The caller states which
/// build it produced, and ``BaselineCheck/expectations(at:)`` supplies the
/// outcomes that revision must produce.
enum RevisionUnderTest: String, CaseIterable, Sendable {
  /// The audit revision, `813c52e`, before the remediation program.
  case baseline

  /// The current working tree.
  case current
}

// MARK: - Outcome

/// What one check produced, end to end.
///
/// The first three are reported by the child itself. The rest are observed by
/// the supervising parent, because a process that trapped or was killed reports
/// nothing at all.
enum CheckOutcome: String, Codable, Hashable, CaseIterable, Sendable {
  /// The operation completed and matched the corrected contract.
  case matchedContract

  /// The operation completed and produced something the corrected contract
  /// forbids: a corrupted value, an aliased key, or the wrong XPC kind.
  case violatedContract

  /// The operation refused the input with a public `DecodingError` or
  /// `EncodingError`.
  case typedRejection

  /// The process trapped, aborted, or died on a signal.
  case crashed

  /// The process exceeded its wall-clock ceiling and was killed.
  case timedOut

  /// The process exceeded its CPU ceiling and the kernel killed it.
  case cpuExceeded

  /// The process exceeded its physical-footprint ceiling and was killed.
  case memoryExceeded

  /// The process exited in a way the supervisor could not classify.
  case unexpectedExit

  /// Whether this outcome means the process did not finish on its own terms.
  var isProcessFailure: Bool {
    switch self {
    case .crashed, .timedOut, .cpuExceeded, .memoryExceeded, .unexpectedExit:
      true
    case .matchedContract, .violatedContract, .typedRejection:
      false
    }
  }

  /// Every way the kernel or the supervisor can end a check's process.
  ///
  /// This is the expectation for a defect whose whole nature is that nothing
  /// bounds it: which resource gives out first — the stack, the footprint
  /// ceiling, the CPU ceiling, the wall clock — is a property of the host, not
  /// of the defect. `unexpectedExit` is deliberately excluded, because that is
  /// how a broken probe reports itself and must never satisfy an expectation.
  static let terminated: Set<Self> = [
    .crashed, .memoryExceeded, .cpuExceeded, .timedOut,
  ]
}

/// One check's completed observation, as reported by the child.
struct CheckObservation: Sendable {
  var outcome: CheckOutcome
  var detail: String

  init(_ outcome: CheckOutcome, _ detail: String) {
    self.outcome = outcome
    self.detail = detail
  }
}

// MARK: - Check

/// One historical defect, expressed as an experiment with a different required
/// answer at each revision.
///
/// A check is only evidence when its two expectation sets are disjoint: if an
/// outcome could satisfy both revisions, the check proves nothing about the
/// remediation. ``BaselineChecks/validateInventory()`` enforces that for every
/// defect check, and enforces the opposite for a control.
struct BaselineCheck: Sendable {
  /// A stable identifier, also the `run` argument.
  let id: String

  /// What the experiment does.
  let summary: String

  /// The remediation issue this check pins down, or `nil` for a control.
  let defect: String?

  /// Every outcome that counts as "the historical defect is present".
  let atBaseline: Set<CheckOutcome>

  /// Every outcome that counts as "the historical defect is fixed".
  let atCurrent: Set<CheckOutcome>

  /// The experiment.
  ///
  /// Public coding errors are classified by the caller, so a body only returns
  /// when the operation completed.
  let body: @Sendable () throws -> CheckObservation

  /// Whether this check exists to prove the probe itself is not vacuous.
  var isControl: Bool {
    defect == nil
  }

  func expectations(at revision: RevisionUnderTest) -> Set<CheckOutcome> {
    switch revision {
    case .baseline: atBaseline
    case .current: atCurrent
    }
  }
}

// MARK: - Error

struct BaselineError: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}

// MARK: - Exit Codes

enum BaselineExitCode {
  /// Every check produced the outcome its revision requires.
  static let passed: Int32 = 0
  /// At least one check did not.
  static let evidenceFailed: Int32 = 1
  /// The command line was malformed.
  static let usage: Int32 = 64
  /// The probe itself could not run the check.
  static let harnessFailed: Int32 = 70
}
