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
  
  /// Convenience by-which external types can take advantage of "fewer-copy" XPC APIs without inlining the type-introspection checks at each call site.
  @inlinable
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeRawPointer: UnsafeRawPointer?,
    count: Int
  ) throws {
    switch self as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      try container.directlyEncodeXPCData(
        unsafeRawPointer,
        count: count
      )
    case .none:
      guard
        let unsafeRawPointer,
        count > 0
      else {
        return try encode(Data())
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
  
  /// Convenience by-which external types can take advantage of "fewer-copy" XPC APIs without inlining the type-introspection checks at each call site.
  @inlinable
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeMutableRawPointer: UnsafeMutableRawPointer?,
    count: Int
  ) throws {
    switch self as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      try container.directlyEncodeXPCData(
        unsafeMutableRawPointer,
        count: count
      )
    case .none:
      guard
        let unsafeMutableRawPointer,
        count > 0
      else {
        return try encode(Data())
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
      try container.directlyEncodeXPCData(unsafeRawBufferPointer)
    case .none:
      guard
        let baseAddress = unsafeRawBufferPointer.baseAddress,
        unsafeRawBufferPointer.count > 0
      else {
        return try encode(Data())
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
      try container.directlyEncodeXPCData(unsafeMutableRawBufferPointer)
    case .none:
      guard
        let baseAddress = unsafeMutableRawBufferPointer.baseAddress,
        unsafeMutableRawBufferPointer.count > 0
      else {
        return try encode(Data())
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
