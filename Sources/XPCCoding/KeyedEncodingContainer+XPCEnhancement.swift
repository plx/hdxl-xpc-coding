import Foundation

extension KeyedEncodingContainer {

  // MARK: - Inline Arrays

  /// Encodes an inline array's bytes as binary data for `key`, without forming an
  /// intermediate `Data`.
  ///
  /// With ``XPCEncoder`` this reaches the direct `xpc_data_create` path. With any
  /// other encoder it falls back to encoding an equivalent `Data`, so the encoded
  /// entry is interchangeable with encoding a plain `Data` for the same key.
  ///
  /// The bytes are read through the array's span for the duration of this call and
  /// are not referenced afterwards; the caller keeps ownership of `inlineArray`. An
  /// empty inline array encodes empty binary data.
  ///
  /// - Parameters:
  ///   - inlineArray: The bytes to encode.
  ///   - key: The key to associate the data with.
  /// - Throws: An error from the underlying encoder. This overload derives its own
  ///   buffer from `inlineArray`, so it never reports an invalid pointer/count pair.
  public mutating func efficientlyEncodeBinaryData<let N: Int>(
    _ inlineArray: InlineArray<N, UInt8>,
    forKey key: Key
  ) throws {
    try inlineArray.span.withUnsafeBytes { unsafeBytes in
      try efficientlyEncodeBinaryData(
        unsafeBytes,
        forKey: key
      )
    }
  }

  // MARK: - Data Elements

  /// Encodes `count` raw bytes beginning at `unsafeRawPointer` as binary data for
  /// `key`.
  ///
  /// When used with ``XPCEncoder``, this bypasses the standard `Data` encoding path
  /// and directly creates an XPC data object from the raw bytes. With any other
  /// encoder it falls back to encoding an equivalent `Data`. Both paths enforce the
  /// same pointer/count contract.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` encodes those `count` bytes;
  /// - a non-nil pointer with a `count` of zero encodes empty data; and
  /// - a nil pointer with a `count` of zero encodes empty data.
  ///
  /// Every other combination is invalid and is rejected before the pointer is read
  /// and before anything is written for `key`: a negative `count`, and a nil pointer
  /// with a positive `count`.
  ///
  /// - Parameters:
  ///   - unsafeRawPointer: A pointer to the raw bytes to encode. May be nil only when `count` is
  ///     zero.
  ///   - count: The nonnegative number of bytes to encode.
  ///   - key: The key to associate the data with.
  /// - Throws: `EncodingError.invalidValue`, carrying this container's coding path
  ///   extended by `key`, when `count` is negative or when `count` is positive for a
  ///   nil pointer. Otherwise, any error from the underlying encoder.
  /// - Important: For a positive `count` the caller must keep at least `count`
  ///   initialized, readable bytes alive for the whole of this call. That extent,
  ///   that initialization, and that lifetime cannot be checked dynamically, so
  ///   passing a shorter, uninitialized, or already-deallocated region is undefined
  ///   behavior. The bytes are read before this method returns, and the pointer is
  ///   never retained past it.
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeRawPointer: UnsafeRawPointer?,
    count: Int,
    forKey key: Key
  ) throws {
    var pointerCodingPath: [any CodingKey] = codingPath
    pointerCodingPath.append(key)
    try validateUnsafePointerCount(
      unsafeRawPointer,
      count: count,
      codingPath: pointerCodingPath
    )
    try encode(
      UnsafeRawPointerShim(
        unsafeRawPointer: unsafeRawPointer,
        count: count
      ),
      forKey: key
    )
  }

  /// Encodes `count` raw bytes beginning at `unsafeMutableRawPointer` as binary data
  /// for `key`.
  ///
  /// This behaves exactly like the `UnsafeRawPointer?` overload; the memory is only
  /// ever read. When used with ``XPCEncoder``, this bypasses the standard `Data`
  /// encoding path and directly creates an XPC data object from the raw bytes;
  /// with any other encoder it falls back to encoding an equivalent `Data`. Both
  /// paths enforce the same pointer/count contract.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` encodes those `count` bytes;
  /// - a non-nil pointer with a `count` of zero encodes empty data; and
  /// - a nil pointer with a `count` of zero encodes empty data.
  ///
  /// Every other combination is invalid and is rejected before the pointer is read
  /// and before anything is written for `key`: a negative `count`, and a nil pointer
  /// with a positive `count`.
  ///
  /// - Parameters:
  ///   - unsafeMutableRawPointer: A pointer to the raw bytes to encode. May be nil only when
  ///     `count` is zero.
  ///   - count: The nonnegative number of bytes to encode.
  ///   - key: The key to associate the data with.
  /// - Throws: `EncodingError.invalidValue`, carrying this container's coding path
  ///   extended by `key`, when `count` is negative or when `count` is positive for a
  ///   nil pointer. Otherwise, any error from the underlying encoder.
  /// - Important: For a positive `count` the caller must keep at least `count`
  ///   initialized, readable bytes alive for the whole of this call, and must not
  ///   mutate them concurrently. That extent, that initialization, and that lifetime
  ///   cannot be checked dynamically, so passing a shorter, uninitialized, or
  ///   already-deallocated region is undefined behavior. The bytes are read before
  ///   this method returns, and the pointer is never retained past it.
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeMutableRawPointer: UnsafeMutableRawPointer?,
    count: Int,
    forKey key: Key
  ) throws {
    var pointerCodingPath: [any CodingKey] = codingPath
    pointerCodingPath.append(key)
    try validateUnsafePointerCount(
      unsafeMutableRawPointer,
      count: count,
      codingPath: pointerCodingPath
    )
    try encode(
      UnsafeMutableRawPointerShim(
        unsafeMutableRawPointer: unsafeMutableRawPointer,
        count: count
      ),
      forKey: key
    )
  }

  /// Encodes the bytes addressed by `unsafeRawBufferPointer` as binary data for `key`.
  ///
  /// This is the buffer-shaped spelling of the pointer/count overload. When used with
  /// ``XPCEncoder``, it bypasses the standard `Data` encoding path and directly
  /// creates an XPC data object from the raw bytes; with any other encoder it
  /// falls back to encoding an equivalent `Data`. An empty buffer encodes empty
  /// binary data.
  ///
  /// The caller must satisfy `UnsafeRawBufferPointer`'s own invariant that a nil
  /// `baseAddress` is valid only when `count` is zero. Behavior is undefined for a
  /// buffer that violates that invariant.
  ///
  /// - Parameters:
  ///   - unsafeRawBufferPointer: A buffer pointer to the raw bytes to encode.
  ///   - key: The key to associate the data with.
  /// - Throws: Any error from the underlying encoder.
  /// - Important: The buffer must address `count` initialized, readable bytes that
  ///   stay alive for the whole of this call. That cannot be checked dynamically, so
  ///   a buffer over a shorter, uninitialized, or already-deallocated region is
  ///   undefined behavior. The bytes are read before this method returns, and the
  ///   buffer is never retained past it.
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeRawBufferPointer: UnsafeRawBufferPointer,
    forKey key: Key
  ) throws {
    try encode(
      UnsafeRawBufferPointerShim(unsafeRawBufferPointer: unsafeRawBufferPointer),
      forKey: key
    )
  }

  /// Encodes the bytes addressed by `unsafeMutableRawBufferPointer` as binary data
  /// for `key`.
  ///
  /// This behaves exactly like the `UnsafeRawBufferPointer` overload; the memory is
  /// only ever read. When used with ``XPCEncoder``, it bypasses the standard `Data`
  /// encoding path and directly creates an XPC data object from the raw bytes;
  /// with any other encoder it falls back to encoding an equivalent `Data`. An empty
  /// buffer encodes empty binary data.
  ///
  /// The caller must satisfy `UnsafeMutableRawBufferPointer`'s own invariant that a
  /// nil `baseAddress` is valid only when `count` is zero. Behavior is undefined for
  /// a buffer that violates that invariant.
  ///
  /// - Parameters:
  ///   - unsafeMutableRawBufferPointer: A buffer pointer to the raw bytes to encode.
  ///   - key: The key to associate the data with.
  /// - Throws: Any error from the underlying encoder.
  /// - Important: The buffer must address `count` initialized, readable bytes that
  ///   stay alive for the whole of this call, and they must not be mutated
  ///   concurrently. That cannot be checked dynamically, so a buffer over a shorter,
  ///   uninitialized, or already-deallocated region is undefined behavior. The bytes
  ///   are read before this method returns, and the buffer is never retained past it.
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeMutableRawBufferPointer: UnsafeMutableRawBufferPointer,
    forKey key: Key
  ) throws {
    try encode(
      UnsafeMutableRawBufferPointerShim(unsafeMutableRawBufferPointer: unsafeMutableRawBufferPointer),
      forKey: key
    )
  }

  // MARK: - Element Buffers

  /// Encodes `count` elements beginning at `unsafePointer` as a nested unkeyed
  /// container for `key`.
  ///
  /// Each value is encoded through the nested container's ordinary `encode(_:)`, so
  /// this is a call-site convenience over creating that container and looping; it
  /// works with any encoder.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` encodes those `count` elements;
  /// - a non-nil pointer with a `count` of zero encodes an empty nested container;
  ///   and
  /// - a nil pointer with a `count` of zero encodes an empty nested container.
  ///
  /// Every other combination is invalid and is rejected before the pointer is read
  /// and before the nested container is created: a negative `count`, and a nil
  /// pointer with a positive `count`.
  ///
  /// - Parameters:
  ///   - unsafePointer: A pointer to the elements to encode. May be nil only when `count` is zero.
  ///   - count: The nonnegative number of elements to encode.
  ///   - key: The key to associate the array with.
  /// - Throws: `EncodingError.invalidValue`, carrying this container's coding path
  ///   extended by `key`, when `count` is negative or when `count` is positive for a
  ///   nil pointer. Otherwise, any error thrown while encoding an element — in which
  ///   case the nested container exists and holds the elements already encoded.
  /// - Important: For a positive `count` the caller must keep at least `count`
  ///   initialized, readable `T` values alive for the whole of this call. That
  ///   extent, that initialization, and that lifetime cannot be checked dynamically,
  ///   so passing a shorter, uninitialized, or already-deallocated region is
  ///   undefined behavior. The elements are read before this method returns, and the
  ///   pointer is never retained past it.
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafePointer: UnsafePointer<T>?,
    count: Int,
    forKey key: Key
  ) throws {
    var pointerCodingPath: [any CodingKey] = codingPath
    pointerCodingPath.append(key)
    try validateUnsafePointerCount(
      unsafePointer,
      count: count,
      codingPath: pointerCodingPath
    )
    var container = nestedUnkeyedContainer(forKey: key)
    try container.efficientlyEncodeElements(
      unsafePointer,
      count: count
    )
  }

  /// Encodes `count` elements beginning at `unsafeMutablePointer` as a nested unkeyed
  /// container for `key`.
  ///
  /// This behaves exactly like the `UnsafePointer<T>?` overload; the memory is only
  /// ever read. Each value is encoded through the nested container's ordinary
  /// `encode(_:)`, so this is a call-site convenience over creating that container
  /// and looping; it works with any encoder.
  ///
  /// These are the valid combinations:
  ///
  /// - a non-nil pointer with a positive `count` encodes those `count` elements;
  /// - a non-nil pointer with a `count` of zero encodes an empty nested container;
  ///   and
  /// - a nil pointer with a `count` of zero encodes an empty nested container.
  ///
  /// Every other combination is invalid and is rejected before the pointer is read
  /// and before the nested container is created: a negative `count`, and a nil
  /// pointer with a positive `count`.
  ///
  /// - Parameters:
  ///   - unsafeMutablePointer: A pointer to the elements to encode. May be nil only when `count` is
  ///     zero.
  ///   - count: The nonnegative number of elements to encode.
  ///   - key: The key to associate the array with.
  /// - Throws: `EncodingError.invalidValue`, carrying this container's coding path
  ///   extended by `key`, when `count` is negative or when `count` is positive for a
  ///   nil pointer. Otherwise, any error thrown while encoding an element — in which
  ///   case the nested container exists and holds the elements already encoded.
  /// - Important: For a positive `count` the caller must keep at least `count`
  ///   initialized, readable `T` values alive for the whole of this call, and must
  ///   not mutate them concurrently. That extent, that initialization, and that
  ///   lifetime cannot be checked dynamically, so passing a shorter, uninitialized,
  ///   or already-deallocated region is undefined behavior. The elements are read
  ///   before this method returns, and the pointer is never retained past it.
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafeMutablePointer: UnsafeMutablePointer<T>?,
    count: Int,
    forKey key: Key
  ) throws {
    var pointerCodingPath: [any CodingKey] = codingPath
    pointerCodingPath.append(key)
    try validateUnsafePointerCount(
      unsafeMutablePointer,
      count: count,
      codingPath: pointerCodingPath
    )
    var container = nestedUnkeyedContainer(forKey: key)
    try container.efficientlyEncodeElements(
      unsafeMutablePointer,
      count: count
    )
  }

  /// Encodes every element of `unsafeBufferPointer` as a nested unkeyed container for
  /// `key`.
  ///
  /// This is the buffer-shaped spelling of the pointer/count overload. Each value is
  /// encoded through the nested container's ordinary `encode(_:)`, so this is a
  /// call-site convenience over creating that container and looping; it works with
  /// any encoder. An empty buffer encodes an empty nested container.
  ///
  /// Unlike the pointer/count overload, this one performs no validation: the caller
  /// must satisfy `UnsafeBufferPointer`'s own invariant that a nil `baseAddress` is
  /// valid only when `count` is zero.
  ///
  /// - Parameters:
  ///   - unsafeBufferPointer: A buffer pointer to the elements to encode.
  ///   - key: The key to associate the array with.
  /// - Throws: Any error thrown while encoding an element, in which case the nested
  ///   container exists and holds the elements already encoded.
  /// - Important: The buffer must address `count` initialized, readable `T` values
  ///   that stay alive for the whole of this call. That cannot be checked
  ///   dynamically, so a buffer over a shorter, uninitialized, or already-deallocated
  ///   region is undefined behavior. The elements are read before this method
  ///   returns, and the buffer is never retained past it.
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafeBufferPointer: UnsafeBufferPointer<T>,
    forKey key: Key
  ) throws {
    var container = nestedUnkeyedContainer(forKey: key)
    try container.efficientlyEncodeElements(unsafeBufferPointer)
  }

  /// Encodes every element of `unsafeMutableBufferPointer` as a nested unkeyed
  /// container for `key`.
  ///
  /// This behaves exactly like the `UnsafeBufferPointer<T>` overload; the memory is
  /// only ever read. Each value is encoded through the nested container's ordinary
  /// `encode(_:)`, so this is a call-site convenience over creating that container
  /// and looping; it works with any encoder. An empty buffer encodes an empty nested
  /// container.
  ///
  /// Unlike the pointer/count overload, this one performs no validation: the caller
  /// must satisfy `UnsafeMutableBufferPointer`'s own invariant that a nil
  /// `baseAddress` is valid only when `count` is zero.
  ///
  /// - Parameters:
  ///   - unsafeMutableBufferPointer: A buffer pointer to the elements to encode.
  ///   - key: The key to associate the array with.
  /// - Throws: Any error thrown while encoding an element, in which case the nested
  ///   container exists and holds the elements already encoded.
  /// - Important: The buffer must address `count` initialized, readable `T` values
  ///   that stay alive for the whole of this call, and they must not be mutated
  ///   concurrently. That cannot be checked dynamically, so a buffer over a shorter,
  ///   uninitialized, or already-deallocated region is undefined behavior. The
  ///   elements are read before this method returns, and the buffer is never retained
  ///   past it.
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafeMutableBufferPointer: UnsafeMutableBufferPointer<T>,
    forKey key: Key
  ) throws {
    var container = nestedUnkeyedContainer(forKey: key)
    try container.efficientlyEncodeElements(unsafeMutableBufferPointer)
  }

}

// MARK: - UnsafeRawPointerShim

/// Internal "adapter" used to ensure binary data takes our "efficient path" when used with a keyed encoder.
///
/// The underlying issue is that there's an asymmetry between keyed encoding containers and the other two types:
///
/// - unkeyed and snigle-value containers get used directly when encoding data
/// - keyed encoding containers are used indirectly (the actual container is used via a struct wrapper that hides the underlying container)
///
/// As such, there's no way for end-user code to check if the keyed encoding container has our fast path available;
/// instead, the best we can do is:
///
/// - use a wrapper type as our encoded value
/// - have the wrapper type use a single-value encoding container from its encoder
/// - attempt to call the appropriate special-case method we want to call (and fall back to the standard path if it's not available)
///
/// - SeeAlso: ``UnsafeMutableRawPointerShim``
/// - SeeAlso: ``UnsafeRawBufferPointerShim``
/// - SeeAlso: ``UnsafeMutableRawBufferPointerShim``
internal struct UnsafeRawPointerShim: Encodable {

  internal let unsafeRawPointer: UnsafeRawPointer?

  internal let count: Int

  init(unsafeRawPointer: UnsafeRawPointer?, count: Int) {
    self.unsafeRawPointer = unsafeRawPointer
    self.count = count
  }

  internal func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.efficientlyEncodeBinaryData(
      unsafeRawPointer,
      count: count
    )
  }

}

// MARK: - UnsafeMutableRawPointerShim

/// Internal "adapter" used to ensure binary data takes our "efficient path" when used with a keyed encoder.
///
/// The underlying issue is that there's an asymmetry between keyed encoding containers and the other two types:
///
/// - unkeyed and snigle-value containers get used directly when encoding data
/// - keyed encoding containers are used indirectly (the actual container is used via a struct wrapper that hides the underlying container)
///
/// As such, there's no way for end-user code to check if the keyed encoding container has our fast path available;
/// instead, the best we can do is:
///
/// - use a wrapper type as our encoded value
/// - have the wrapper type use a single-value encoding container from its encoder
/// - attempt to call the appropriate special-case method we want to call (and fall back to the standard path if it's not available)
///
/// - SeeAlso: ``UnsafeRawPointerShim``
/// - SeeAlso: ``UnsafeRawBufferPointerShim``
/// - SeeAlso: ``UnsafeMutableRawBufferPointerShim``
internal struct UnsafeMutableRawPointerShim: Encodable {

  internal let unsafeMutableRawPointer: UnsafeMutableRawPointer?

  internal let count: Int

  init(unsafeMutableRawPointer: UnsafeMutableRawPointer?, count: Int) {
    self.unsafeMutableRawPointer = unsafeMutableRawPointer
    self.count = count
  }

  internal func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.efficientlyEncodeBinaryData(
      unsafeMutableRawPointer,
      count: count
    )
  }

}

// MARK: - UnsafeRawBufferPointerShim

/// Internal "adapter" used to ensure binary data takes our "efficient path" when used with a keyed encoder.
///
/// The underlying issue is that there's an asymmetry between keyed encoding containers and the other two types:
///
/// - unkeyed and snigle-value containers get used directly when encoding data
/// - keyed encoding containers are used indirectly (the actual container is used via a struct wrapper that hides the underlying container)
///
/// As such, there's no way for end-user code to check if the keyed encoding container has our fast path available;
/// instead, the best we can do is:
///
/// - use a wrapper type as our encoded value
/// - have the wrapper type use a single-value encoding container from its encoder
/// - attempt to call the appropriate special-case method we want to call (and fall back to the standard path if it's not available)
///
/// - SeeAlso: ``UnsafeRawPointerShim``
/// - SeeAlso: ``UnsafeMutableRawPointerShim``
/// - SeeAlso: ``UnsafeMutableRawBufferPointerShim``
internal struct UnsafeRawBufferPointerShim: Encodable {

  internal let unsafeRawBufferPointer: UnsafeRawBufferPointer

  init(unsafeRawBufferPointer: UnsafeRawBufferPointer) {
    self.unsafeRawBufferPointer = unsafeRawBufferPointer
  }

  internal func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.efficientlyEncodeBinaryData(unsafeRawBufferPointer)
  }

}

// MARK: - UnsafeMutableRawBufferPointerShim

/// Internal "adapter" used to ensure binary data takes our "efficient path" when used with a keyed encoder.
///
/// The underlying issue is that there's an asymmetry between keyed encoding containers and the other two types:
///
/// - unkeyed and snigle-value containers get used directly when encoding data
/// - keyed encoding containers are used indirectly (the actual container is used via a struct wrapper that hides the underlying container)
///
/// As such, there's no way for end-user code to check if the keyed encoding container has our fast path available;
/// instead, the best we can do is:
///
/// - use a wrapper type as our encoded value
/// - have the wrapper type use a single-value encoding container from its encoder
/// - attempt to call the appropriate special-case method we want to call (and fall back to the standard path if it's not available)
///
/// - SeeAlso: ``UnsafeRawPointerShim``
/// - SeeAlso: ``UnsafeMutableRawPointerShim``
/// - SeeAlso: ``UnsafeRawBufferPointerShim``
internal struct UnsafeMutableRawBufferPointerShim: Encodable {

  internal let unsafeMutableRawBufferPointer: UnsafeMutableRawBufferPointer

  init(unsafeMutableRawBufferPointer: UnsafeMutableRawBufferPointer) {
    self.unsafeMutableRawBufferPointer = unsafeMutableRawBufferPointer
  }

  internal func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.efficientlyEncodeBinaryData(unsafeMutableRawBufferPointer)
  }

}
