import Darwin
import XPC

/// Shared, operation-local accounting for one top-level decode.
internal final class _XPCDecodingState {

  /// The immutable resource-limit snapshot for this operation.
  internal let limits: XPCDecoder.ResourceLimits

  /// The number of XPC-object traversal attempts consumed so far.
  ///
  /// Repeated traversal of one object consumes another visit.
  internal var visitedNodeCount: Int

  /// The cumulative string/data/key byte count consumed so far.
  internal var cumulativeByteCount: Int

  internal init(limits: XPCDecoder.ResourceLimits) {
    self.limits = limits
    self.visitedNodeCount = 0
    self.cumulativeByteCount = 0
  }

  /// Validates a traversal depth and consumes one XPC-object visit.
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

  /// Checks and caches every dictionary key before `allKeys` is exposed.
  internal func validateDictionary(
    _ dictionary: xpc_object_t,
    stringKeyStrategy: XPCDecoder.StringKeyStrategy,
    codingPath: [any CodingKey]
  ) throws(DecodingError) -> [String] {
    let elementCount = xpc_dictionary_get_count(dictionary)
    try validateContainerElementCount(
      elementCount,
      codingPath: codingPath
    )

    var keyStrings: [String] = []
    keyStrings.reserveCapacity(elementCount)
    var validationError: DecodingError?
    xpc_dictionary_apply(dictionary) { keyCString, _ in
      guard validationError == nil else {
        return false
      }

      do {
        let remainingCumulativeBytes =
          limits.maximumCumulativeByteCount - cumulativeByteCount
        let remainingStringBytes = min(
          limits.maximumStringByteCount,
          remainingCumulativeBytes
        )
        let stringScanLimit =
          remainingStringBytes == .max
          ? Int.max
          : remainingStringBytes + 1
        let byteCount = Int(
          Darwin.strnlen(
            keyCString,
            stringScanLimit
          )
        )
        try consumeStringByteCount(
          byteCount,
          codingPath: codingPath
        )

        guard
          let encodedKey = String(
            validatingUTF8CString: keyCString,
            byteCount: byteCount
          )
        else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(
              codingPath: codingPath,
              debugDescription:
                "Unable to decode XPC dictionary key as valid UTF-8.",
              underlyingError: XPCStringExtractionError.unableToDecode(
                "Unable to decode \(byteCount) XPC dictionary-key bytes as UTF-8."
              )
            )
          )
        }

        let decodedKey: String
        switch stringKeyStrategy {
        case .passthrough:
          decodedKey = encodedKey
        case .percentEscape:
          guard
            let key = encodedKey.removingXPCCodingPercentEscapes()
          else {
            throw DecodingError.dataCorrupted(
              DecodingError.Context(
                codingPath: codingPath,
                debugDescription:
                  "Unable to remove XPCCoding percent escapes from an XPC dictionary key.",
                underlyingError:
                  XPCStringExtractionError.unableToRemovePercentEscapes(
                    "The XPC dictionary key does not use XPCCoding's percent-escape grammar."
                  )
              )
            )
          }
          decodedKey = key
        }

        keyStrings.append(decodedKey)
        return true
      } catch let error as DecodingError {
        validationError = error
        return false
      } catch {
        preconditionFailure("Dictionary-key validation only throws DecodingError.")
      }
    }

    if let validationError {
      throw validationError
    }
    return keyStrings
  }

  /// Checks an XPC string or data-backed string before its bytes are copied.
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
