import Foundation

/// Validates an optional unsafe pointer and count before library code uses either value.
///
/// A zero count is valid for both nil and non-nil pointers. A positive count requires a non-nil
/// pointer, and all counts must be nonnegative.
internal func validateUnsafePointerCount<Pointer>(
  _ unsafePointer: Pointer?,
  count: Int,
  codingPath: [any CodingKey]
) throws {
  guard count >= 0 else {
    throw EncodingError.invalidValue(
      count,
      EncodingError.Context(
        codingPath: codingPath,
        debugDescription:
          "Invalid unsafe pointer/count pair: count must be nonnegative, but was \(count)."
      )
    )
  }

  guard count == 0 || unsafePointer != nil else {
    throw EncodingError.invalidValue(
      unsafePointer as Any,
      EncodingError.Context(
        codingPath: codingPath,
        debugDescription:
          """
          Invalid unsafe pointer/count pair: a non-nil pointer is required when count is positive \
          (count: \(count)).
          """
      )
    )
  }
}
