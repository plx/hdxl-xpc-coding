// MARK: XPCDecoder.ResourceLimits

extension XPCDecoder {

  /// Finite resource limits applied independently to each top-level decode operation.
  ///
  /// Limits are checked before XPCCoding descends into a child object, enumerates a
  /// container, or copies string/data bytes. A limit of zero permits no use of that
  /// resource; the root object itself is at nesting depth zero and consumes one node.
  ///
  /// The standard limits are deliberately generous for local IPC while still placing
  /// a firm ceiling below process-exhaustion territory:
  ///
  /// - nesting depth: 128;
  /// - elements in one container: 65,536;
  /// - total visited nodes: 262,144;
  /// - bytes in one string or dictionary key: 8 MiB;
  /// - bytes in one data value: 32 MiB; and
  /// - cumulative decoded string/data/key bytes: 64 MiB.
  ///
  /// Nesting depth measures recursive decoding transitions below the root, including
  /// a generic single-value decode that recursively interprets the same XPC object.
  /// Repeated traversal of the same XPC object consumes the budgets again. Object
  /// identity is not used as a cycle test, so an acyclic graph may safely reference
  /// the same child object from multiple siblings. Cycles are rejected through the
  /// nesting-depth ceiling before they can exhaust the process stack.
  ///
  /// These limits are decoder-local behavior. They are not serialized, do not need
  /// to match the encoder's settings, and do not change XPCCoding's XPC-object
  /// representation.
  public struct ResourceLimits: Sendable, Equatable, Hashable {

    /// The maximum number of recursive decoding transitions below the root object.
    public let maximumNestingDepth: Int

    /// The maximum number of entries in any one XPC array or dictionary.
    public let maximumContainerElementCount: Int

    /// The maximum number of XPC-object visits in one top-level decode operation.
    public let maximumTotalNodeCount: Int

    /// The maximum encoded byte count of one XPC string, data-backed string, or dictionary key.
    public let maximumStringByteCount: Int

    /// The maximum byte count of one XPC data value decoded as data or a data-backed primitive.
    public let maximumDataByteCount: Int

    /// The maximum cumulative encoded byte count of decoded strings, data, and dictionary keys.
    public let maximumCumulativeByteCount: Int

    /// The standard finite limits used by ``XPCDecoder``.
    public static let standard = Self(
      maximumNestingDepth: 128,
      maximumContainerElementCount: 65_536,
      maximumTotalNodeCount: 262_144,
      maximumStringByteCount: 8 * 1_024 * 1_024,
      maximumDataByteCount: 32 * 1_024 * 1_024,
      maximumCumulativeByteCount: 64 * 1_024 * 1_024
    )

    /// Creates a validated resource-limit set.
    ///
    /// - Precondition: Every argument is nonnegative and
    ///   `maximumTotalNodeCount` is at least one, because every decode visits
    ///   its root object.
    public init(
      maximumNestingDepth: Int,
      maximumContainerElementCount: Int,
      maximumTotalNodeCount: Int,
      maximumStringByteCount: Int,
      maximumDataByteCount: Int,
      maximumCumulativeByteCount: Int
    ) {
      precondition(
        maximumNestingDepth >= 0,
        "maximumNestingDepth must be nonnegative."
      )
      precondition(
        maximumContainerElementCount >= 0,
        "maximumContainerElementCount must be nonnegative."
      )
      precondition(
        maximumTotalNodeCount >= 1,
        "maximumTotalNodeCount must be at least one."
      )
      precondition(
        maximumStringByteCount >= 0,
        "maximumStringByteCount must be nonnegative."
      )
      precondition(
        maximumDataByteCount >= 0,
        "maximumDataByteCount must be nonnegative."
      )
      precondition(
        maximumCumulativeByteCount >= 0,
        "maximumCumulativeByteCount must be nonnegative."
      )

      self.maximumNestingDepth = maximumNestingDepth
      self.maximumContainerElementCount = maximumContainerElementCount
      self.maximumTotalNodeCount = maximumTotalNodeCount
      self.maximumStringByteCount = maximumStringByteCount
      self.maximumDataByteCount = maximumDataByteCount
      self.maximumCumulativeByteCount = maximumCumulativeByteCount
    }

  }

}

// MARK: - CustomStringConvertible

extension XPCDecoder.ResourceLimits: CustomStringConvertible {

  /// A brief, human-readable summary of every configured limit.
  ///
  /// - Note: Intended for diagnostics and logging. The exact text is not API
  ///   and must not be parsed.
  public var description: String {
    """
    (depth: \(maximumNestingDepth), container-elements: \(maximumContainerElementCount), \
    nodes: \(maximumTotalNodeCount), string-bytes: \(maximumStringByteCount), \
    data-bytes: \(maximumDataByteCount), cumulative-bytes: \(maximumCumulativeByteCount))
    """
  }

}

// MARK: - CustomDebugStringConvertible

extension XPCDecoder.ResourceLimits: CustomDebugStringConvertible {

  /// A developer-facing description naming every configured limit.
  ///
  /// - Note: Intended for diagnostics and logging. The exact text is not API
  ///   and must not be parsed.
  public var debugDescription: String {
    """
    XPCDecoder.ResourceLimits(
      maximumNestingDepth: \(maximumNestingDepth),
      maximumContainerElementCount: \(maximumContainerElementCount),
      maximumTotalNodeCount: \(maximumTotalNodeCount),
      maximumStringByteCount: \(maximumStringByteCount),
      maximumDataByteCount: \(maximumDataByteCount),
      maximumCumulativeByteCount: \(maximumCumulativeByteCount)
    )
    """
  }

}
