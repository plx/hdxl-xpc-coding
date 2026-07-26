import Foundation

// MARK: XPCEnhancedUnkeyedEncodingContainer

/// Provides an extended API allowing direct encoding for unsafe pointers to binary data, *potentially* bypassing the need for a transient copy.
public protocol XPCEnhancedUnkeyedEncodingContainer: UnkeyedEncodingContainer {
  
  // MARK: - Individual Data Elements

  /// Encodes the data pointed-to by `unsafePointer` as xpc data (bypassing any intermediate `Data` values).
  ///
  /// A zero `count` encodes empty data and permits a nil or non-nil pointer. A positive `count`
  /// requires a non-nil pointer. For a positive count, the caller must keep at least `count`
  /// initialized, readable bytes alive for the duration of this call; their extent, initialization,
  /// and lifetime cannot be checked dynamically.
  ///
  /// - Throws: `EncodingError.invalidValue` when `count` is negative or is positive for a nil
  ///   pointer.
  /// - Note: The bytes are copied before this method returns.
  mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeRawPointer?,
    count: Int
  ) throws

  /// Encodes the data pointed-to by `unsafePointer` as xpc data (bypassing any intermediate `Data` values).
  ///
  /// A zero `count` encodes empty data and permits a nil or non-nil pointer. A positive `count`
  /// requires a non-nil pointer. For a positive count, the caller must keep at least `count`
  /// initialized, readable bytes alive for the duration of this call; their extent, initialization,
  /// and lifetime cannot be checked dynamically.
  ///
  /// - Throws: `EncodingError.invalidValue` when `count` is negative or is positive for a nil
  ///   pointer.
  /// - Note: The bytes are copied before this method returns.
  mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeMutableRawPointer?,
    count: Int
  ) throws

  /// Encodes the data pointed-to by `unsafeBufferPointer` as xpc data (bypassing any intermediate `Data` values).
  ///
  /// - Note: the encoded data will copied after this call—we're just avoiding creating the `Data` value wrapping it.
  mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeRawBufferPointer) throws
  
  /// Encodes the data pointed-to by `unsafeBufferPointer` as xpc data (bypassing any intermediate `Data` values).
  ///
  /// - Note: the encoded data will copied after this call—we're just avoiding creating the `Data` value wrapping it.
  mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeMutableRawBufferPointer) throws
  
}

// MARK: - Default Implementations

extension XPCEnhancedUnkeyedEncodingContainer {
  
  // MARK: - Individual Data Elements
  
  @inlinable
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
  
  @inlinable
  public mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeRawBufferPointer) throws {
    try directlyEncodeXPCData(
      unsafeBufferPointer.baseAddress,
      count: unsafeBufferPointer.count
    )
  }

  @inlinable
  public mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeMutableRawBufferPointer) throws {
    try directlyEncodeXPCData(
      unsafeBufferPointer.baseAddress,
      count: unsafeBufferPointer.count
    )
  }

}
