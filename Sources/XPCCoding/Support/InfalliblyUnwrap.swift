import Foundation

/// Force-unwraps `value`, carrying a static rationale for why the nil case is believed unreachable.
///
/// In release builds, this is equivalent to `value!`. In debug builds, a nil value triggers a
/// `fatalError` whose message names the call site and includes the supplied `explanation` as the
/// rationale that turned out to be wrong — making it easier to diagnose violated invariants than a
/// bare `try!` or `!` would. The `explanation` itself is asserted non-empty so that callers cannot
/// silently degenerate into a bare `!`.
///
/// - Parameters:
///   - value: The optional to unwrap.
///   - explanation: A non-empty rationale describing why this call site believes `value` cannot be nil.
@inlinable @inline(__always)
internal func infalliblyUnwrap<T>(
  _ value: T?,
  explanation: StaticString,
  function: StaticString = #function,
  file: StaticString = #file,
  line: UInt = #line
) -> T {
  #if DEBUG
  assert(
    !"\(explanation)".isEmpty,
    "infalliblyUnwrap requires a non-empty explanation",
    file: file,
    line: line
  )
  guard let value else {
    fatalError(
      """
      infalliblyUnwrap received an unexpected nil at \(function); the force-unwrap was deemed safe because: \(explanation)
      """,
      file: file,
      line: line
    )
  }
  return value
  #else
  // This helper is the documented, centralized release fast path.
  // swiftlint:disable:next force_unwrapping
  return value!
  #endif
}
