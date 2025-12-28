import Foundation

extension UnkeyedEncodingContainer {
  
  // MARK: - Data Elements
  
  /// Convenience by-which external types can take advantage of "fewer-copy" XPC APIs without inlining the type-introspection checks at each call site.
  @inlinable
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeRawPointer: UnsafeRawPointer?,
    count: Int
  ) throws {
    switch self as? XPCEnhancedUnkeyedEncodingContainer {
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
    switch self as? XPCEnhancedUnkeyedEncodingContainer {
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
    switch self as? XPCEnhancedUnkeyedEncodingContainer {
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
    switch self as? XPCEnhancedUnkeyedEncodingContainer {
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
  
  // MARK: - Element Buffers
  
  /// Convenience by-which external types can take advantage of "fewer-copy" XPC APIs without inlining the type-introspection checks at each call site.
  @inlinable
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafePointer: UnsafePointer<T>?,
    count: Int
  ) throws {
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
  
  /// Convenience by-which external types can take advantage of "fewer-copy" XPC APIs without inlining the type-introspection checks at each call site.
  @inlinable
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafeMutablePointer: UnsafeMutablePointer<T>?,
    count: Int
  ) throws {
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
  
  /// Convenience by-which external types can take advantage of "fewer-copy" XPC APIs without inlining the type-introspection checks at each call site.
  @inlinable
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafeBufferPointer: UnsafeBufferPointer<T>
  ) throws {
    for element in unsafeBufferPointer {
      try encode(element)
    }
  }
  
  /// Convenience by-which external types can take advantage of "fewer-copy" XPC APIs without inlining the type-introspection checks at each call site.
  @inlinable
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafeMutableBufferPointer: UnsafeMutableBufferPointer<T>
  ) throws {
    for element in unsafeMutableBufferPointer {
      try encode(element)
    }
  }
  
}
