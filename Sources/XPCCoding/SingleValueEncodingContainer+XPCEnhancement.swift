import Foundation

extension SingleValueEncodingContainer {

  /// Encodes an inline array's bytes as binary data, without forming an intermediate `Data`.
  ///
  /// With ``XPCEncoder`` this reaches the direct `xpc_data_create` path. With any
  /// other encoder it falls back to encoding an equivalent `Data`, so the encoded
  /// result is interchangeable with encoding a plain `Data` at this position.
  ///
  /// The bytes are read through the array's span for the duration of this call and
  /// are not referenced afterwards; the caller keeps ownership of `inlineArray`. An
  /// empty inline array encodes empty binary data.
  ///
  /// - Parameter inlineArray: The bytes to encode.
  /// - Throws: An error from the underlying encoder. This overload derives its own
  ///   buffer from `inlineArray`, so it never reports an invalid pointer/count pair.
  public mutating func efficientlyEncodeBinaryData<let N: Int>(
    _ inlineArray: InlineArray<N, UInt8>
  ) throws {
    try inlineArray.span.withUnsafeBytes { unsafeBytes in
      try efficientlyEncodeBinaryData(
        unsafeBytes
      )
    }
  }
  
  /// Encodes `count` raw bytes beginning at `unsafeRawPointer` as binary data.
  ///
  /// With ``XPCEncoder`` this reaches the direct `xpc_data_create` path, skipping the
  /// intermediate `Data`. With any other encoder it falls back to encoding an
  /// equivalent `Data`. Both paths enforce the same pointer/count contract.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` encodes those `count` bytes;
  /// - a non-nil pointer with a `count` of zero encodes empty data; and
  /// - a nil pointer with a `count` of zero encodes empty data.
  ///
  /// Every other combination is invalid and is rejected before the pointer is read:
  /// a negative `count`, and a nil pointer with a positive `count`.
  ///
  /// - Parameters:
  ///   - unsafeRawPointer: The first byte to encode. May be nil only when `count` is
  ///     zero.
  ///   - count: The nonnegative number of bytes to encode.
  /// - Throws: `EncodingError.invalidValue`, carrying this container's coding path,
  ///   when `count` is negative or when `count` is positive for a nil pointer.
  ///   Otherwise, any error from the underlying encoder.
  /// - Important: For a positive `count` the caller must keep at least `count`
  ///   initialized, readable bytes alive for the whole of this call. That extent,
  ///   that initialization, and that lifetime cannot be checked dynamically, so
  ///   passing a shorter, uninitialized, or already-deallocated region is undefined
  ///   behavior. The bytes are read before this method returns, and the pointer is
  ///   never retained past it.
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeRawPointer: UnsafeRawPointer?,
    count: Int
  ) throws {
    try validateUnsafePointerCount(
      unsafeRawPointer,
      count: count,
      codingPath: codingPath
    )
    switch self as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      defer {
        guard let updatedContainer = container as? Self else {
          preconditionFailure("Enhanced container unexpectedly changed dynamic type.")
        }
        self = updatedContainer
      }
      try container.directlyEncodeXPCData(
        unsafeRawPointer,
        count: count
      )
    case .none:
      guard
        let unsafeRawPointer,
        count > 0
      else {
        try encode(Data())
        return
      }
      try encode(
        Data(
          bytesNoCopy: UnsafeMutableRawPointer(mutating: unsafeRawPointer),
          count: count,
          deallocator: .none
        )
      )
    }
  }
  
  /// Encodes `count` raw bytes beginning at `unsafeMutableRawPointer` as binary data.
  ///
  /// This behaves exactly like the `UnsafeRawPointer?` overload; the memory is only
  /// ever read. With ``XPCEncoder`` it reaches the direct `xpc_data_create` path,
  /// skipping the intermediate `Data`; with any other encoder it falls back to
  /// encoding an equivalent `Data`. Both paths enforce the same pointer/count
  /// contract.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` encodes those `count` bytes;
  /// - a non-nil pointer with a `count` of zero encodes empty data; and
  /// - a nil pointer with a `count` of zero encodes empty data.
  ///
  /// Every other combination is invalid and is rejected before the pointer is read:
  /// a negative `count`, and a nil pointer with a positive `count`.
  ///
  /// - Parameters:
  ///   - unsafeMutableRawPointer: The first byte to encode. May be nil only when
  ///     `count` is zero.
  ///   - count: The nonnegative number of bytes to encode.
  /// - Throws: `EncodingError.invalidValue`, carrying this container's coding path,
  ///   when `count` is negative or when `count` is positive for a nil pointer.
  ///   Otherwise, any error from the underlying encoder.
  /// - Important: For a positive `count` the caller must keep at least `count`
  ///   initialized, readable bytes alive for the whole of this call, and must not
  ///   mutate them concurrently. That extent, that initialization, and that lifetime
  ///   cannot be checked dynamically, so passing a shorter, uninitialized, or
  ///   already-deallocated region is undefined behavior. The bytes are read before
  ///   this method returns, and the pointer is never retained past it.
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeMutableRawPointer: UnsafeMutableRawPointer?,
    count: Int
  ) throws {
    try validateUnsafePointerCount(
      unsafeMutableRawPointer,
      count: count,
      codingPath: codingPath
    )
    switch self as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      defer {
        guard let updatedContainer = container as? Self else {
          preconditionFailure("Enhanced container unexpectedly changed dynamic type.")
        }
        self = updatedContainer
      }
      try container.directlyEncodeXPCData(
        unsafeMutableRawPointer,
        count: count
      )
    case .none:
      guard
        let unsafeMutableRawPointer,
        count > 0
      else {
        try encode(Data())
        return
      }
      try encode(
        Data(
          bytesNoCopy: unsafeMutableRawPointer,
          count: count,
          deallocator: .none
        )
      )
    }
  }
  
  /// Encodes the bytes addressed by `unsafeRawBufferPointer` as binary data.
  ///
  /// This is the buffer-shaped spelling of the pointer/count overload, and exists so
  /// external types can take the "fewer-copy" XPC path without inlining the
  /// type-introspection check at each call site. With ``XPCEncoder`` it reaches the
  /// direct `xpc_data_create` path; with any other encoder it falls back to encoding
  /// an equivalent `Data`. An empty buffer encodes empty binary data.
  ///
  /// The caller must satisfy `UnsafeRawBufferPointer`'s own invariant that a nil
  /// `baseAddress` is valid only when `count` is zero. Behavior is undefined for a
  /// buffer that violates that invariant.
  ///
  /// - Parameter unsafeRawBufferPointer: The bytes to encode.
  /// - Throws: Any error from the underlying encoder.
  /// - Important: The buffer must address `count` initialized, readable bytes that
  ///   stay alive for the whole of this call. That cannot be checked dynamically, so
  ///   a buffer over a shorter, uninitialized, or already-deallocated region is
  ///   undefined behavior. The bytes are read before this method returns, and the
  ///   buffer is never retained past it.
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeRawBufferPointer: UnsafeRawBufferPointer
  ) throws {
    switch self as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      defer {
        guard let updatedContainer = container as? Self else {
          preconditionFailure("Enhanced container unexpectedly changed dynamic type.")
        }
        self = updatedContainer
      }
      try container.directlyEncodeXPCData(unsafeRawBufferPointer)
    case .none:
      guard
        let baseAddress = unsafeRawBufferPointer.baseAddress,
        !unsafeRawBufferPointer.isEmpty
      else {
        try encode(Data())
        return
      }
      try encode(
        Data(
          bytesNoCopy: UnsafeMutableRawPointer(mutating: baseAddress),
          count: unsafeRawBufferPointer.count,
          deallocator: .none
        )
      )
    }
  }
  
  /// Encodes the bytes addressed by `unsafeMutableRawBufferPointer` as binary data.
  ///
  /// This behaves exactly like the `UnsafeRawBufferPointer` overload; the memory is
  /// only ever read. With ``XPCEncoder`` it reaches the direct `xpc_data_create`
  /// path; with any other encoder it falls back to encoding an equivalent `Data`. An
  /// empty buffer encodes empty binary data.
  ///
  /// The caller must satisfy `UnsafeMutableRawBufferPointer`'s own invariant that a
  /// nil `baseAddress` is valid only when `count` is zero. Behavior is undefined for
  /// a buffer that violates that invariant.
  ///
  /// - Parameter unsafeMutableRawBufferPointer: The bytes to encode.
  /// - Throws: Any error from the underlying encoder.
  /// - Important: The buffer must address `count` initialized, readable bytes that
  ///   stay alive for the whole of this call, and they must not be mutated
  ///   concurrently. That cannot be checked dynamically, so a buffer over a shorter,
  ///   uninitialized, or already-deallocated region is undefined behavior. The bytes
  ///   are read before this method returns, and the buffer is never retained past it.
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeMutableRawBufferPointer: UnsafeMutableRawBufferPointer
  ) throws {
    switch self as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      defer {
        guard let updatedContainer = container as? Self else {
          preconditionFailure("Enhanced container unexpectedly changed dynamic type.")
        }
        self = updatedContainer
      }
      try container.directlyEncodeXPCData(unsafeMutableRawBufferPointer)
    case .none:
      guard
        let baseAddress = unsafeMutableRawBufferPointer.baseAddress,
        !unsafeMutableRawBufferPointer.isEmpty
      else {
        try encode(Data())
        return
      }
      try encode(
        Data(
          bytesNoCopy: baseAddress,
          count: unsafeMutableRawBufferPointer.count,
          deallocator: .none
        )
      )
    }
  }
  
}
