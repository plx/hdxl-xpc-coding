import Foundation

// MARK: XPCEnhancedUnkeyedEncodingContainer

/// Provides an extended API allowing direct encoding for unsafe pointers to binary data, *potentially* bypassing the need for a transient copy.
public protocol XPCEnhancedUnkeyedEncodingContainer: UnkeyedEncodingContainer {
  
  // MARK: - Individual Data Elements

  /// Encodes the data pointed-to by `unsafePointer` as xpc data (bypassing any intermediate `Data` values).
  ///
  /// - Note: the encoded data will copied after this call—we're just avoiding creating the `Data` value wrapping it.
  mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeRawPointer?,
    count: Int
  ) throws

  /// Encodes the data pointed-to by `unsafePointer` as xpc data (bypassing any intermediate `Data` values).
  ///
  /// - Note: the encoded data will copied after this call—we're just avoiding creating the `Data` value wrapping it.
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

extension XPCEnhancedUnkeyedEncodingContainer {
  
  // MARK: - Individual Data Elements
  
  @inlinable
  public mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeRawPointer?,
    count: Int
  ) throws {
    try directlyEncodeXPCData(
      unsafePointer.map { UnsafeMutableRawPointer(mutating:  $0) },
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
