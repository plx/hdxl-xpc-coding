import Foundation

extension SingleValueEncodingContainer {
  
  @inlinable
  public mutating func efficientlyEncodeBinaryData<let N: Int>(
    _ inlineArray: InlineArray<N, UInt8>
  ) throws {
    try inlineArray.span.withUnsafeBytes { unsafeBytes in
      try efficientlyEncodeBinaryData(
        unsafeBytes
      )
    }
  }
  
  /// Efficiently encodes `count` raw bytes beginning at `unsafeRawPointer`.
  ///
  /// A zero count encodes empty data and permits a nil or non-nil pointer. A positive count
  /// requires a non-nil pointer. For a positive count, the caller must keep at least `count`
  /// initialized, readable bytes alive for the duration of this call; their extent, initialization,
  /// and lifetime cannot be checked dynamically.
  ///
  /// - Throws: `EncodingError.invalidValue` when `count` is negative or is positive for a nil
  ///   pointer.
  @inlinable
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
  
  /// Efficiently encodes `count` raw bytes beginning at `unsafeMutableRawPointer`.
  ///
  /// A zero count encodes empty data and permits a nil or non-nil pointer. A positive count
  /// requires a non-nil pointer. For a positive count, the caller must keep at least `count`
  /// initialized, readable bytes alive for the duration of this call; their extent, initialization,
  /// and lifetime cannot be checked dynamically.
  ///
  /// - Throws: `EncodingError.invalidValue` when `count` is negative or is positive for a nil
  ///   pointer.
  @inlinable
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
  
  /// Convenience by-which external types can take advantage of "fewer-copy" XPC APIs without inlining the type-introspection checks at each call site.
  @inlinable
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
  
  /// Convenience by-which external types can take advantage of "fewer-copy" XPC APIs without inlining the type-introspection checks at each call site.
  @inlinable
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
