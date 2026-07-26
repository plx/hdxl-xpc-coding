import Foundation

extension KeyedEncodingContainer {

  // MARK: - Inline Arrays

  /// Convenience to efficiently encode the contents of an inline array as binary data.
  @inlinable
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

  /// Efficiently encodes raw binary data directly as XPC data for the given key.
  ///
  /// When used with ``XPCEncoder``, this method bypasses the standard `Data` encoding
  /// path and directly creates an `xpc_data_t` object from the raw bytes.
  ///
  /// - Parameters:
  ///   - unsafeRawPointer: A pointer to the raw bytes to encode. May be nil only when `count` is
  ///     zero.
  ///   - count: The nonnegative number of bytes to encode.
  ///   - key: The key to associate the data with.
  /// - Throws: `EncodingError.invalidValue` when `count` is negative or is positive for a nil
  ///   pointer.
  /// - Important: For a positive count, the caller must keep at least `count` initialized,
  ///   readable bytes alive for the duration of this call. Their extent, initialization, and
  ///   lifetime cannot be checked dynamically.
  @inlinable
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

  /// Efficiently encodes raw binary data directly as XPC data for the given key.
  ///
  /// When used with ``XPCEncoder``, this method bypasses the standard `Data` encoding
  /// path and directly creates an `xpc_data_t` object from the raw bytes.
  ///
  /// - Parameters:
  ///   - unsafeMutableRawPointer: A pointer to the raw bytes to encode. May be nil only when
  ///     `count` is zero.
  ///   - count: The nonnegative number of bytes to encode.
  ///   - key: The key to associate the data with.
  /// - Throws: `EncodingError.invalidValue` when `count` is negative or is positive for a nil
  ///   pointer.
  /// - Important: For a positive count, the caller must keep at least `count` initialized,
  ///   readable bytes alive for the duration of this call. Their extent, initialization, and
  ///   lifetime cannot be checked dynamically.
  @inlinable
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

  /// Efficiently encodes raw binary data directly as XPC data for the given key.
  ///
  /// When used with ``XPCEncoder``, this method bypasses the standard `Data` encoding
  /// path and directly creates an `xpc_data_t` object from the raw bytes.
  ///
  /// - Parameters:
  ///   - unsafeRawBufferPointer: A buffer pointer to the raw bytes to encode.
  ///   - key: The key to associate the data with.
  @inlinable
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeRawBufferPointer: UnsafeRawBufferPointer,
    forKey key: Key
  ) throws {
    try encode(
      UnsafeRawBufferPointerShim(unsafeRawBufferPointer: unsafeRawBufferPointer),
      forKey: key
    )
  }

  /// Efficiently encodes raw binary data directly as XPC data for the given key.
  ///
  /// When used with ``XPCEncoder``, this method bypasses the standard `Data` encoding
  /// path and directly creates an `xpc_data_t` object from the raw bytes.
  ///
  /// - Parameters:
  ///   - unsafeMutableRawBufferPointer: A buffer pointer to the raw bytes to encode.
  ///   - key: The key to associate the data with.
  @inlinable
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

  /// Efficiently encodes a buffer of elements as a nested unkeyed container for the given key.
  ///
  /// - Parameters:
  ///   - unsafePointer: A pointer to the elements to encode. May be nil only when `count` is zero.
  ///   - count: The nonnegative number of elements to encode.
  ///   - key: The key to associate the array with.
  /// - Throws: `EncodingError.invalidValue` when `count` is negative or is positive for a nil
  ///   pointer.
  /// - Important: For a positive count, the caller must keep at least `count` initialized,
  ///   readable `T` values alive for the duration of this call. Their extent, initialization, and
  ///   lifetime cannot be checked dynamically.
  @inlinable
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

  /// Efficiently encodes a buffer of elements as a nested unkeyed container for the given key.
  ///
  /// - Parameters:
  ///   - unsafeMutablePointer: A pointer to the elements to encode. May be nil only when `count` is
  ///     zero.
  ///   - count: The nonnegative number of elements to encode.
  ///   - key: The key to associate the array with.
  /// - Throws: `EncodingError.invalidValue` when `count` is negative or is positive for a nil
  ///   pointer.
  /// - Important: For a positive count, the caller must keep at least `count` initialized,
  ///   readable `T` values alive for the duration of this call. Their extent, initialization, and
  ///   lifetime cannot be checked dynamically.
  @inlinable
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

  /// Efficiently encodes a buffer of elements as a nested unkeyed container for the given key.
  ///
  /// - Parameters:
  ///   - unsafeBufferPointer: A buffer pointer to the elements to encode.
  ///   - key: The key to associate the array with.
  @inlinable
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafeBufferPointer: UnsafeBufferPointer<T>,
    forKey key: Key
  ) throws {
    var container = nestedUnkeyedContainer(forKey: key)
    try container.efficientlyEncodeElements(unsafeBufferPointer)
  }

  /// Efficiently encodes a buffer of elements as a nested unkeyed container for the given key.
  ///
  /// - Parameters:
  ///   - unsafeMutableBufferPointer: A buffer pointer to the elements to encode.
  ///   - key: The key to associate the array with.
  @inlinable
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
@usableFromInline
internal struct UnsafeRawPointerShim: Encodable {
  
  @usableFromInline
  internal let unsafeRawPointer: UnsafeRawPointer?
  
  @usableFromInline
  internal let count: Int
  
  @inlinable
  init(unsafeRawPointer: UnsafeRawPointer?, count: Int) {
    self.unsafeRawPointer = unsafeRawPointer
    self.count = count
  }
  
  @inlinable
  internal func encode(to encoder: any Encoder) throws {
    try validateUnsafePointerCount(
      unsafeRawPointer,
      count: count,
      codingPath: encoder.codingPath
    )
    var container = encoder.singleValueContainer()
    switch container as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      try container.directlyEncodeXPCData(
        unsafeRawPointer,
        count: count
      )
    case .none:
      guard count > .zero else {
        try container.encode(Data())
        return
      }
      switch unsafeRawPointer {
      case .some(let unsafeRawPointer):
        try container.encode(
          Data(
            bytesNoCopy: UnsafeMutableRawPointer(mutating: unsafeRawPointer),
            count: count,
            deallocator: .none
          )
        )
      case .none:
        try container.encode(Data())
      }
    }
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
@usableFromInline
internal struct UnsafeMutableRawPointerShim: Encodable {
  
  @usableFromInline
  internal let unsafeMutableRawPointer: UnsafeMutableRawPointer?
  
  @usableFromInline
  internal let count: Int
  
  @inlinable
  init(unsafeMutableRawPointer: UnsafeMutableRawPointer?, count: Int) {
    self.unsafeMutableRawPointer = unsafeMutableRawPointer
    self.count = count
  }
  
  @inlinable
  internal func encode(to encoder: any Encoder) throws {
    try validateUnsafePointerCount(
      unsafeMutableRawPointer,
      count: count,
      codingPath: encoder.codingPath
    )
    var container = encoder.singleValueContainer()
    switch container as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      try container.directlyEncodeXPCData(
        unsafeMutableRawPointer,
        count: count
      )
    case .none:
      guard count > .zero else {
        try container.encode(Data())
        return
      }
      switch unsafeMutableRawPointer {
      case .some(let unsafeMutableRawPointer):
        try container.encode(
          Data(
            bytesNoCopy: unsafeMutableRawPointer,
            count: count,
            deallocator: .none
          )
        )
      case .none:
        try container.encode(Data())
      }
    }
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
@usableFromInline
internal struct UnsafeRawBufferPointerShim: Encodable {
  
  @usableFromInline
  internal let unsafeRawBufferPointer: UnsafeRawBufferPointer
  
  @inlinable
  init(unsafeRawBufferPointer: UnsafeRawBufferPointer) {
    self.unsafeRawBufferPointer = unsafeRawBufferPointer
  }
  
  @inlinable
  internal func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch container as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      try container.directlyEncodeXPCData(unsafeRawBufferPointer)
    case .none:
      switch unsafeRawBufferPointer.baseAddress {
      case .some(let baseAddress):
        try container.encode(
          Data(
            bytesNoCopy: UnsafeMutableRawPointer(mutating: baseAddress),
            count: unsafeRawBufferPointer.count,
            deallocator: .none
          )
        )
      case .none:
        try container.encode(Data())
      }
    }
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
@usableFromInline
internal struct UnsafeMutableRawBufferPointerShim: Encodable {
  
  @usableFromInline
  internal let unsafeMutableRawBufferPointer: UnsafeMutableRawBufferPointer
  
  @inlinable
  init(unsafeMutableRawBufferPointer: UnsafeMutableRawBufferPointer) {
    self.unsafeMutableRawBufferPointer = unsafeMutableRawBufferPointer
  }
  
  @inlinable
  internal func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch container as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      try container.directlyEncodeXPCData(unsafeMutableRawBufferPointer)
    case .none:
      switch unsafeMutableRawBufferPointer.baseAddress {
      case .some(let baseAddress):
        try container.encode(
          Data(
            bytesNoCopy: baseAddress,
            count: unsafeMutableRawBufferPointer.count,
            deallocator: .none
          )
        )
      case .none:
        try container.encode(Data())
      }
    }
  }
  
}
