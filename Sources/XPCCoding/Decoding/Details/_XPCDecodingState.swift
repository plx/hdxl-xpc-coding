import Darwin
import XPC

/// Shared, operation-local accounting for one top-level decode.
@usableFromInline
internal final class _XPCDecodingState {

  /// The immutable resource-limit snapshot for this operation.
  @usableFromInline
  internal let limits: XPCDecoder.ResourceLimits

  /// The number of XPC-object traversal attempts consumed so far.
  ///
  /// Repeated traversal of one object consumes another visit.
  @usableFromInline
  internal var visitedNodeCount: Int

  /// The cumulative string/data/key byte count consumed so far.
  @usableFromInline
  internal var cumulativeByteCount: Int

  @usableFromInline
  internal init(limits: XPCDecoder.ResourceLimits) {
    self.limits = limits
    self.visitedNodeCount = 0
    self.cumulativeByteCount = 0
  }

  /// Validates a traversal depth and consumes one XPC-object visit.
  @usableFromInline
  internal func prepareToVisit(
    atDepth depth: Int,
    codingPath: [any CodingKey]
  ) throws(DecodingError) {
    guard depth <= limits.maximumNestingDepth else {
      throw resourceLimitError(
        named: "maximumNestingDepth",
        maximum: limits.maximumNestingDepth,
        codingPath: codingPath
      )
    }
    guard visitedNodeCount < limits.maximumTotalNodeCount else {
      throw resourceLimitError(
        named: "maximumTotalNodeCount",
        maximum: limits.maximumTotalNodeCount,
        codingPath: codingPath
      )
    }

    visitedNodeCount += 1
  }

  /// Checks a container's count before XPCCoding enumerates or decodes its entries.
  @usableFromInline
  internal func validateContainerElementCount(
    _ elementCount: Int,
    codingPath: [any CodingKey]
  ) throws(DecodingError) {
    guard elementCount <= limits.maximumContainerElementCount else {
      throw resourceLimitError(
        named: "maximumContainerElementCount",
        maximum: limits.maximumContainerElementCount,
        codingPath: codingPath
      )
    }
  }

  /// Checks every dictionary key before `allKeys` can allocate Swift strings for them.
  @usableFromInline
  internal func validateDictionary(
    _ dictionary: xpc_object_t,
    codingPath: [any CodingKey]
  ) throws(DecodingError) {
    let elementCount = xpc_dictionary_get_count(dictionary)
    try validateContainerElementCount(
      elementCount,
      codingPath: codingPath
    )

    var validationError: DecodingError?
    xpc_dictionary_apply(dictionary) { keyCString, _ in
      guard validationError == nil else {
        return false
      }

      do {
        try consumeStringByteCount(
          Int(Darwin.strlen(keyCString)),
          codingPath: codingPath
        )
        return true
      } catch let error as DecodingError {
        validationError = error
        return false
      } catch {
        preconditionFailure("String-byte accounting only throws DecodingError.")
      }
    }

    if let validationError {
      throw validationError
    }
  }

  /// Checks an XPC string or data-backed string before its bytes are copied.
  @usableFromInline
  internal func validateStringValue(
    _ object: xpc_object_t,
    strategy: XPCDecoder.StringValueStrategy,
    codingPath: [any CodingKey]
  ) throws(DecodingError) {
    switch strategy {
    case .passthrough, .percentEscape:
      guard object.hasType(XPC_TYPE_STRING) else {
        return
      }
      try consumeStringByteCount(
        xpc_string_get_length(object),
        codingPath: codingPath
      )
    case .useDataRepresentation:
      guard object.hasType(XPC_TYPE_DATA) else {
        return
      }
      try consumeStringByteCount(
        xpc_data_get_length(object),
        codingPath: codingPath
      )
    }
  }

  /// Checks an XPC data value before its bytes are copied or read.
  @usableFromInline
  internal func validateDataValue(
    _ object: xpc_object_t,
    codingPath: [any CodingKey]
  ) throws(DecodingError) {
    guard object.hasType(XPC_TYPE_DATA) else {
      return
    }

    let byteCount = xpc_data_get_length(object)
    guard byteCount <= limits.maximumDataByteCount else {
      throw resourceLimitError(
        named: "maximumDataByteCount",
        maximum: limits.maximumDataByteCount,
        codingPath: codingPath
      )
    }
    try consumeCumulativeByteCount(
      byteCount,
      codingPath: codingPath
    )
  }

  /// Consumes bytes belonging to an XPC string, data-backed string, or dictionary key.
  @usableFromInline
  internal func consumeStringByteCount(
    _ byteCount: Int,
    codingPath: [any CodingKey]
  ) throws(DecodingError) {
    guard byteCount <= limits.maximumStringByteCount else {
      throw resourceLimitError(
        named: "maximumStringByteCount",
        maximum: limits.maximumStringByteCount,
        codingPath: codingPath
      )
    }
    try consumeCumulativeByteCount(
      byteCount,
      codingPath: codingPath
    )
  }

  /// Consumes bytes without overflowing while computing the cumulative total.
  @usableFromInline
  internal func consumeCumulativeByteCount(
    _ byteCount: Int,
    codingPath: [any CodingKey]
  ) throws(DecodingError) {
    guard
      byteCount <= limits.maximumCumulativeByteCount,
      cumulativeByteCount <= limits.maximumCumulativeByteCount - byteCount
    else {
      throw resourceLimitError(
        named: "maximumCumulativeByteCount",
        maximum: limits.maximumCumulativeByteCount,
        codingPath: codingPath
      )
    }

    cumulativeByteCount += byteCount
  }

  /// Builds a bounded error that never asks libxpc to describe the hostile graph.
  @usableFromInline
  internal func resourceLimitError(
    named limitName: StaticString,
    maximum: Int,
    codingPath: [any CodingKey]
  ) -> DecodingError {
    DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription:
          "XPCCoding decoder resource limit '\(limitName)' exhausted (maximum: \(maximum))."
      )
    )
  }

}
