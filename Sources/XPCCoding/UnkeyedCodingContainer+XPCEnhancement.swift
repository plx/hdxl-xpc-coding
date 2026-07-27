import Foundation

extension UnkeyedEncodingContainer {
  
  // MARK: - Data Elements

  /// Appends an inline array's bytes as one binary-data element, without forming an
  /// intermediate `Data`.
  ///
  /// With ``XPCEncoder`` this reaches the direct `xpc_data_create` path. With any
  /// other encoder it falls back to encoding an equivalent `Data`, so the appended
  /// element is interchangeable with encoding a plain `Data` at this position. The
  /// whole array becomes a single element, not one element per byte.
  ///
  /// The bytes are read through the array's span for the duration of this call and
  /// are not referenced afterwards; the caller keeps ownership of `inlineArray`. An
  /// empty inline array appends one empty binary-data element.
  ///
  /// - Parameter inlineArray: The bytes to encode as one element.
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

  /// Appends `count` raw bytes beginning at `unsafeRawPointer` as one binary-data
  /// element.
  ///
  /// With ``XPCEncoder`` this reaches the direct `xpc_data_create` path, skipping the
  /// intermediate `Data`. With any other encoder it falls back to encoding an
  /// equivalent `Data`. Both paths enforce the same pointer/count contract, and both
  /// append exactly one element.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` appends those `count` bytes;
  /// - a non-nil pointer with a `count` of zero appends an empty data element; and
  /// - a nil pointer with a `count` of zero appends an empty data element.
  ///
  /// Every other combination is invalid and is rejected before the pointer is read
  /// and before any element is appended: a negative `count`, and a nil pointer with a
  /// positive `count`.
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
    switch self as? XPCEnhancedUnkeyedEncodingContainer {
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
  
  /// Appends `count` raw bytes beginning at `unsafeMutableRawPointer` as one
  /// binary-data element.
  ///
  /// This behaves exactly like the `UnsafeRawPointer?` overload; the memory is only
  /// ever read. With ``XPCEncoder`` it reaches the direct `xpc_data_create` path,
  /// skipping the intermediate `Data`; with any other encoder it falls back to
  /// encoding an equivalent `Data`. Both paths enforce the same pointer/count
  /// contract, and both append exactly one element.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` appends those `count` bytes;
  /// - a non-nil pointer with a `count` of zero appends an empty data element; and
  /// - a nil pointer with a `count` of zero appends an empty data element.
  ///
  /// Every other combination is invalid and is rejected before the pointer is read
  /// and before any element is appended: a negative `count`, and a nil pointer with a
  /// positive `count`.
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
    switch self as? XPCEnhancedUnkeyedEncodingContainer {
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
  
  /// Appends the bytes addressed by `unsafeRawBufferPointer` as one binary-data
  /// element.
  ///
  /// This is the buffer-shaped spelling of the pointer/count overload, and exists so
  /// external types can take the "fewer-copy" XPC path without inlining the
  /// type-introspection check at each call site. With ``XPCEncoder`` it reaches the
  /// direct `xpc_data_create` path; with any other encoder it falls back to encoding
  /// an equivalent `Data`. An empty buffer appends one empty binary-data element.
  ///
  /// The caller must satisfy `UnsafeRawBufferPointer`'s own invariant that a nil
  /// `baseAddress` is valid only when `count` is zero. Behavior is undefined for a
  /// buffer that violates that invariant.
  ///
  /// - Parameter unsafeRawBufferPointer: The bytes to encode as one element.
  /// - Throws: Any error from the underlying encoder.
  /// - Important: The buffer must address `count` initialized, readable bytes that
  ///   stay alive for the whole of this call. That cannot be checked dynamically, so
  ///   a buffer over a shorter, uninitialized, or already-deallocated region is
  ///   undefined behavior. The bytes are read before this method returns, and the
  ///   buffer is never retained past it.
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeRawBufferPointer: UnsafeRawBufferPointer
  ) throws {
    switch self as? XPCEnhancedUnkeyedEncodingContainer {
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
  
  /// Appends the bytes addressed by `unsafeMutableRawBufferPointer` as one
  /// binary-data element.
  ///
  /// This behaves exactly like the `UnsafeRawBufferPointer` overload; the memory is
  /// only ever read. With ``XPCEncoder`` it reaches the direct `xpc_data_create`
  /// path; with any other encoder it falls back to encoding an equivalent `Data`. An
  /// empty buffer appends one empty binary-data element.
  ///
  /// The caller must satisfy `UnsafeMutableRawBufferPointer`'s own invariant that a
  /// nil `baseAddress` is valid only when `count` is zero. Behavior is undefined for
  /// a buffer that violates that invariant.
  ///
  /// - Parameter unsafeMutableRawBufferPointer: The bytes to encode as one element.
  /// - Throws: Any error from the underlying encoder.
  /// - Important: The buffer must address `count` initialized, readable bytes that
  ///   stay alive for the whole of this call, and they must not be mutated
  ///   concurrently. That cannot be checked dynamically, so a buffer over a shorter,
  ///   uninitialized, or already-deallocated region is undefined behavior. The bytes
  ///   are read before this method returns, and the buffer is never retained past it.
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeMutableRawBufferPointer: UnsafeMutableRawBufferPointer
  ) throws {
    switch self as? XPCEnhancedUnkeyedEncodingContainer {
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
  
  // MARK: - Element Buffers
  
  /// Appends `count` elements beginning at `unsafePointer`, one encoded element each.
  ///
  /// Each value is encoded through the container's ordinary `encode(_:)`, so this is
  /// a call-site convenience over a manual loop rather than a distinct
  /// representation; it works with any encoder.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` appends those `count` elements;
  /// - a non-nil pointer with a `count` of zero appends nothing; and
  /// - a nil pointer with a `count` of zero appends nothing.
  ///
  /// Every other combination is invalid and is rejected before the pointer is read
  /// and before any element is appended: a negative `count`, and a nil pointer with a
  /// positive `count`.
  ///
  /// - Parameters:
  ///   - unsafePointer: The first element to encode. May be nil only when `count` is
  ///     zero.
  ///   - count: The nonnegative number of elements to encode.
  /// - Throws: `EncodingError.invalidValue`, carrying this container's coding path,
  ///   when `count` is negative or when `count` is positive for a nil pointer.
  ///   Otherwise, any error thrown while encoding an element — in which case the
  ///   elements already appended stay appended.
  /// - Important: For a positive `count` the caller must keep at least `count`
  ///   initialized, readable `T` values alive for the whole of this call. That
  ///   extent, that initialization, and that lifetime cannot be checked dynamically,
  ///   so passing a shorter, uninitialized, or already-deallocated region is
  ///   undefined behavior. The elements are read before this method returns, and the
  ///   pointer is never retained past it.
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafePointer: UnsafePointer<T>?,
    count: Int
  ) throws {
    try validateUnsafePointerCount(
      unsafePointer,
      count: count,
      codingPath: codingPath
    )
    guard
      let unsafePointer,
      count > 0
    else {
      return
    }
    
    for offset in 0..<count {
      try encode(
        unsafePointer.advanced(by: offset).pointee
      )
    }
  }
  
  /// Appends `count` elements beginning at `unsafeMutablePointer`, one encoded
  /// element each.
  ///
  /// This behaves exactly like the `UnsafePointer<T>?` overload; the memory is only
  /// ever read. Each value is encoded through the container's ordinary `encode(_:)`,
  /// so this is a call-site convenience over a manual loop rather than a distinct
  /// representation; it works with any encoder.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` appends those `count` elements;
  /// - a non-nil pointer with a `count` of zero appends nothing; and
  /// - a nil pointer with a `count` of zero appends nothing.
  ///
  /// Every other combination is invalid and is rejected before the pointer is read
  /// and before any element is appended: a negative `count`, and a nil pointer with a
  /// positive `count`.
  ///
  /// - Parameters:
  ///   - unsafeMutablePointer: The first element to encode. May be nil only when
  ///     `count` is zero.
  ///   - count: The nonnegative number of elements to encode.
  /// - Throws: `EncodingError.invalidValue`, carrying this container's coding path,
  ///   when `count` is negative or when `count` is positive for a nil pointer.
  ///   Otherwise, any error thrown while encoding an element — in which case the
  ///   elements already appended stay appended.
  /// - Important: For a positive `count` the caller must keep at least `count`
  ///   initialized, readable `T` values alive for the whole of this call, and must
  ///   not mutate them concurrently. That extent, that initialization, and that
  ///   lifetime cannot be checked dynamically, so passing a shorter, uninitialized,
  ///   or already-deallocated region is undefined behavior. The elements are read
  ///   before this method returns, and the pointer is never retained past it.
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafeMutablePointer: UnsafeMutablePointer<T>?,
    count: Int
  ) throws {
    try validateUnsafePointerCount(
      unsafeMutablePointer,
      count: count,
      codingPath: codingPath
    )
    guard
      let unsafeMutablePointer,
      count > 0
    else {
      return
    }
    
    for offset in 0..<count {
      try encode(
        unsafeMutablePointer.advanced(by: offset).pointee
      )
    }
  }
  
  /// Appends every element of `unsafeBufferPointer`, one encoded element each.
  ///
  /// This is the buffer-shaped spelling of the pointer/count overload. Each value is
  /// encoded through the container's ordinary `encode(_:)`, so this is a call-site
  /// convenience over a manual loop rather than a distinct representation; it works
  /// with any encoder. An empty buffer appends nothing.
  ///
  /// Unlike the pointer/count overload, this one performs no validation: the caller
  /// must satisfy `UnsafeBufferPointer`'s own invariant that a nil `baseAddress` is
  /// valid only when `count` is zero.
  ///
  /// - Parameter unsafeBufferPointer: The elements to encode.
  /// - Throws: Any error thrown while encoding an element, in which case the elements
  ///   already appended stay appended.
  /// - Important: The buffer must address `count` initialized, readable `T` values
  ///   that stay alive for the whole of this call. That cannot be checked
  ///   dynamically, so a buffer over a shorter, uninitialized, or already-deallocated
  ///   region is undefined behavior. The elements are read before this method
  ///   returns, and the buffer is never retained past it.
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafeBufferPointer: UnsafeBufferPointer<T>
  ) throws {
    for element in unsafeBufferPointer {
      try encode(element)
    }
  }
  
  /// Appends every element of `unsafeMutableBufferPointer`, one encoded element each.
  ///
  /// This behaves exactly like the `UnsafeBufferPointer<T>` overload; the memory is
  /// only ever read. Each value is encoded through the container's ordinary
  /// `encode(_:)`, so this is a call-site convenience over a manual loop rather than
  /// a distinct representation; it works with any encoder. An empty buffer appends
  /// nothing.
  ///
  /// Unlike the pointer/count overload, this one performs no validation: the caller
  /// must satisfy `UnsafeMutableBufferPointer`'s own invariant that a nil
  /// `baseAddress` is valid only when `count` is zero.
  ///
  /// - Parameter unsafeMutableBufferPointer: The elements to encode.
  /// - Throws: Any error thrown while encoding an element, in which case the elements
  ///   already appended stay appended.
  /// - Important: The buffer must address `count` initialized, readable `T` values
  ///   that stay alive for the whole of this call, and they must not be mutated
  ///   concurrently. That cannot be checked dynamically, so a buffer over a shorter,
  ///   uninitialized, or already-deallocated region is undefined behavior. The
  ///   elements are read before this method returns, and the buffer is never retained
  ///   past it.
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafeMutableBufferPointer: UnsafeMutableBufferPointer<T>
  ) throws {
    for element in unsafeMutableBufferPointer {
      try encode(element)
    }
  }
  
}
