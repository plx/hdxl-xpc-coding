// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

// MARK: XPCSingleValueDecodingContainer

/// Internal single-value decoding container.
@usableFromInline
internal struct XPCSingleValueDecodingContainer: SingleValueDecodingContainer {
  
  @usableFromInline
  internal typealias StringKeyStrategy = XPCDecoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCDecoder.StringValueStrategy
  
  /// We always source the string key strategy from the parent decoder.
  @inlinable @inline(__always)
  internal var stringKeyStrategy: XPCDecoder.StringKeyStrategy { decoder.stringKeyStrategy }
  
  /// We always source the string value strategy from the parent decoder.
  @inlinable @inline(__always)
  internal var stringValueStrategy: XPCDecoder.StringValueStrategy { decoder.stringValueStrategy }

  /// The parent decoder.
  @usableFromInline
  internal let decoder: _XPCDecoder
  
  /// The underlying XPC message from-which we're' decoding.
  @usableFromInline
  internal let underlyingMessage: xpc_object_t

  /// The coding path for this container.
  @usableFromInline
  internal let codingPath: [any CodingKey]

  /// The recursive decoding depth of this value below the root object.
  @usableFromInline
  internal let depth: Int
  
  // MARK: - Initialization

  /// Memberwise initializer.
  @usableFromInline
  internal init(
    referencing decoder: _XPCDecoder,
    wrapping xpcObject: xpc_object_t,
    codingPath: [any CodingKey],
    depth: Int? = nil
  ) {
    self.decoder = decoder
    self.underlyingMessage = xpcObject
    self.codingPath = codingPath
    self.depth = depth ?? decoder.depth
  }
  
  // MARK: - SingleValueDecodingContainer

  public func decodeNil() -> Bool {
    underlyingMessage.decodeNil(at: codingPath)
  }
  
  public func decode(_ type: Bool.Type) throws -> Bool {
    try decoder.extractVisitedValue(
      type,
      from: underlyingMessage,
      at: codingPath
    )
  }
  
  public func decode(_ type: String.Type) throws -> String {
    try decoder.extractVisitedString(
      from: underlyingMessage,
      at: codingPath
    )
  }
  
  public func decode(_ type: Double.Type) throws -> Double {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }
  
  public func decode(_ type: Float.Type) throws -> Float {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }
  
  public func decode(_ type: Int.Type) throws -> Int {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }
  
  public func decode(_ type: Int8.Type) throws -> Int8 {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }
  
  public func decode(_ type: Int16.Type) throws -> Int16 {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }
  
  public func decode(_ type: Int32.Type) throws -> Int32 {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }
  
  public func decode(_ type: Int64.Type) throws -> Int64 {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }

  public func decode(_ type: Int128.Type) throws -> Int128 {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }

  public func decode(_ type: UInt.Type) throws -> UInt {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }
  
  public func decode(_ type: UInt8.Type) throws -> UInt8 {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }
  
  public func decode(_ type: UInt16.Type) throws -> UInt16 {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }
  
  public func decode(_ type: UInt32.Type) throws -> UInt32 {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }
  
  public func decode(_ type: UInt64.Type) throws -> UInt64 {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }

  public func decode(_ type: UInt128.Type) throws -> UInt128 {
    try decoder.extractVisitedValue(type, from: underlyingMessage, at: codingPath)
  }

  public func decode<T: Decodable>(_ type: T.Type) throws -> T {
    try decoder.decodeChildValue(
      type,
      from: underlyingMessage,
      at: codingPath,
      depth: depth + 1
    )
  }

}
