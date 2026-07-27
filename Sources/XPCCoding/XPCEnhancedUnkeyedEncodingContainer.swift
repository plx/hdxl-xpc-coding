import Foundation

// MARK: XPCEnhancedUnkeyedEncodingContainer

/// An unkeyed encoding container that can append raw bytes as an xpc data element
/// directly.
///
/// This protocol is the "fast path" that
/// `UnkeyedEncodingContainer.efficientlyEncodeBinaryData(_:count:)` and its overloads
/// look for: they check whether the container conforms, call these requirements when
/// it does, and fall back to encoding an equivalent `Data` when it does not. Prefer
/// those extension methods — conforming containers are found for you, and the same
/// call site keeps working with `JSONEncoder` or any other encoder. Cast to this
/// protocol directly only when a call must reach the direct path or fail.
///
/// Every successful requirement call appends exactly one element, whatever the byte
/// count.
///
/// ``XPCEncoder``'s own unkeyed container conforms. The protocol is public so a
/// container in another module can offer the same fast path; every conforming type
/// must uphold the pointer/count contract described on each requirement, because
/// callers rely on it uniformly across the fast and fallback paths.
///
/// XPCCoding's conforming containers are scoped to one encoding operation. This
/// protocol is not `Sendable`; do not share a container across tasks.
public protocol XPCEnhancedUnkeyedEncodingContainer: UnkeyedEncodingContainer {

  // MARK: - Individual Data Elements

  /// Appends `count` bytes beginning at `unsafePointer` as one xpc data element,
  /// bypassing any intermediate `Data`.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` appends those `count` bytes;
  /// - a non-nil pointer with a `count` of zero appends an empty data element; and
  /// - a nil pointer with a `count` of zero appends an empty data element.
  ///
  /// A conforming implementation must reject every other combination — a negative
  /// `count`, and a nil pointer with a positive `count` — by throwing
  /// `EncodingError.invalidValue` before reading the pointer and before appending any
  /// element, rather than by trapping or by passing the pair to libxpc.
  ///
  /// - Parameters:
  ///   - unsafePointer: The first byte to encode. May be nil only when `count` is
  ///     zero.
  ///   - count: The nonnegative number of bytes to encode.
  /// - Throws: `EncodingError.invalidValue`, carrying this container's coding path,
  ///   for an invalid pointer/count pair.
  /// - Important: For a positive `count` the caller must keep at least `count`
  ///   initialized, readable bytes alive for the whole of this call. That extent,
  ///   that initialization, and that lifetime cannot be checked dynamically, so
  ///   passing a shorter, uninitialized, or already-deallocated region is undefined
  ///   behavior. The bytes are copied before this method returns, and the pointer is
  ///   never retained past it.
  mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeRawPointer?,
    count: Int
  ) throws

  /// Appends `count` bytes beginning at `unsafePointer` as one xpc data element,
  /// bypassing any intermediate `Data`.
  ///
  /// The memory is only ever read; this requirement exists so a caller holding a
  /// mutable pointer need not launder it. Its contract is identical to the
  /// `UnsafeRawPointer?` requirement's.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` appends those `count` bytes;
  /// - a non-nil pointer with a `count` of zero appends an empty data element; and
  /// - a nil pointer with a `count` of zero appends an empty data element.
  ///
  /// A conforming implementation must reject every other combination — a negative
  /// `count`, and a nil pointer with a positive `count` — by throwing
  /// `EncodingError.invalidValue` before reading the pointer and before appending any
  /// element, rather than by trapping or by passing the pair to libxpc.
  ///
  /// - Parameters:
  ///   - unsafePointer: The first byte to encode. May be nil only when `count` is
  ///     zero.
  ///   - count: The nonnegative number of bytes to encode.
  /// - Throws: `EncodingError.invalidValue`, carrying this container's coding path,
  ///   for an invalid pointer/count pair.
  /// - Important: For a positive `count` the caller must keep at least `count`
  ///   initialized, readable bytes alive for the whole of this call, and must not
  ///   mutate them concurrently. That extent, that initialization, and that lifetime
  ///   cannot be checked dynamically, so passing a shorter, uninitialized, or
  ///   already-deallocated region is undefined behavior. The bytes are copied before
  ///   this method returns, and the pointer is never retained past it.
  mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeMutableRawPointer?,
    count: Int
  ) throws

  /// Appends the bytes addressed by `unsafeBufferPointer` as one xpc data element,
  /// bypassing any intermediate `Data`.
  ///
  /// An empty buffer appends an empty data element. The caller must satisfy
  /// `UnsafeRawBufferPointer`'s own invariant that a nil `baseAddress` is valid only
  /// when `count` is zero.
  ///
  /// - Parameter unsafeBufferPointer: The bytes to encode as one element.
  /// - Throws: Any error raised while appending the encoded element.
  /// - Important: The buffer must address `count` initialized, readable bytes that
  ///   stay alive for the whole of this call. That cannot be checked dynamically, so
  ///   a buffer over a shorter, uninitialized, or already-deallocated region is
  ///   undefined behavior. The bytes are copied before this method returns, and the
  ///   buffer is never retained past it.
  mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeRawBufferPointer) throws

  /// Appends the bytes addressed by `unsafeBufferPointer` as one xpc data element,
  /// bypassing any intermediate `Data`.
  ///
  /// The memory is only ever read; this requirement exists so a caller holding a
  /// mutable buffer need not launder it. Its contract is identical to the
  /// `UnsafeRawBufferPointer` requirement's.
  ///
  /// An empty buffer appends an empty data element. The caller must satisfy
  /// `UnsafeMutableRawBufferPointer`'s own invariant that a nil `baseAddress` is valid
  /// only when `count` is zero.
  ///
  /// - Parameter unsafeBufferPointer: The bytes to encode as one element.
  /// - Throws: Any error raised while appending the encoded element.
  /// - Important: The buffer must address `count` initialized, readable bytes that
  ///   stay alive for the whole of this call, and they must not be mutated
  ///   concurrently. That cannot be checked dynamically, so a buffer over a shorter,
  ///   uninitialized, or already-deallocated region is undefined behavior. The bytes
  ///   are copied before this method returns, and the buffer is never retained past
  ///   it.
  mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeMutableRawBufferPointer) throws

}

// MARK: - Default Implementations

extension XPCEnhancedUnkeyedEncodingContainer {

  // MARK: - Individual Data Elements

  /// Appends `count` bytes beginning at `unsafePointer` as one xpc data element,
  /// bypassing any intermediate `Data`.
  ///
  /// This default implementation validates the pointer/count pair and then forwards
  /// to the `UnsafeMutableRawPointer?` requirement, so a conforming type gets the
  /// required validation from one place. Overriding it does not remove the
  /// obligation to enforce the same contract.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` appends those `count` bytes;
  /// - a non-nil pointer with a `count` of zero appends an empty data element; and
  /// - a nil pointer with a `count` of zero appends an empty data element.
  ///
  /// Every other combination is rejected before the pointer is read and before any
  /// element is appended: a negative `count`, and a nil pointer with a positive
  /// `count`.
  ///
  /// - Parameters:
  ///   - unsafePointer: The first byte to encode. May be nil only when `count` is
  ///     zero.
  ///   - count: The nonnegative number of bytes to encode.
  /// - Throws: `EncodingError.invalidValue`, carrying this container's coding path,
  ///   when `count` is negative or when `count` is positive for a nil pointer.
  /// - Important: For a positive `count` the caller must keep at least `count`
  ///   initialized, readable bytes alive for the whole of this call. That extent,
  ///   that initialization, and that lifetime cannot be checked dynamically, so
  ///   passing a shorter, uninitialized, or already-deallocated region is undefined
  ///   behavior. The bytes are copied before this method returns, and the pointer is
  ///   never retained past it.
  public mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeRawPointer?,
    count: Int
  ) throws {
    try validateUnsafePointerCount(
      unsafePointer,
      count: count,
      codingPath: codingPath
    )
    try directlyEncodeXPCData(
      unsafePointer.map { UnsafeMutableRawPointer(mutating: $0) },
      count: count
    )
  }

  /// Appends the bytes addressed by `unsafeBufferPointer` as one xpc data element,
  /// bypassing any intermediate `Data`.
  ///
  /// This default implementation forwards the buffer's base address and count to
  /// `directlyEncodeXPCData(_:count:)`, so the buffer overload and the pointer/count
  /// overload enforce one contract. An empty buffer appends an empty data element.
  /// The caller must satisfy `UnsafeRawBufferPointer`'s own validity invariants.
  ///
  /// - Parameter unsafeBufferPointer: The bytes to encode as one element.
  /// - Throws: Any error raised while appending the encoded element.
  /// - Important: The buffer must address `count` initialized, readable bytes that
  ///   stay alive for the whole of this call. That cannot be checked dynamically, so
  ///   a buffer over a shorter, uninitialized, or already-deallocated region is
  ///   undefined behavior. The bytes are copied before this method returns, and the
  ///   buffer is never retained past it.
  public mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeRawBufferPointer) throws {
    try directlyEncodeXPCData(
      unsafeBufferPointer.baseAddress,
      count: unsafeBufferPointer.count
    )
  }

  /// Appends the bytes addressed by `unsafeBufferPointer` as one xpc data element,
  /// bypassing any intermediate `Data`.
  ///
  /// This default implementation forwards the buffer's base address and count to
  /// `directlyEncodeXPCData(_:count:)`, so the buffer overload and the pointer/count
  /// overload enforce one contract. An empty buffer appends an empty data element.
  /// The caller must satisfy `UnsafeMutableRawBufferPointer`'s own validity
  /// invariants.
  ///
  /// - Parameter unsafeBufferPointer: The bytes to encode as one element.
  /// - Throws: Any error raised while appending the encoded element.
  /// - Important: The buffer must address `count` initialized, readable bytes that
  ///   stay alive for the whole of this call, and they must not be mutated
  ///   concurrently. That cannot be checked dynamically, so a buffer over a shorter,
  ///   uninitialized, or already-deallocated region is undefined behavior. The bytes
  ///   are copied before this method returns, and the buffer is never retained past
  ///   it.
  public mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeMutableRawBufferPointer) throws {
    try directlyEncodeXPCData(
      unsafeBufferPointer.baseAddress,
      count: unsafeBufferPointer.count
    )
  }

}
