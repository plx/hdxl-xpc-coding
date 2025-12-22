// Sources/CodableXPC/XPCSingleValueDecodingContainer.swift -
// SingleValueDecodingContainer for XPC
//
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// -----------------------------------------------------------------------------
//
// This file contains a SingleValueDecodingContainer implementation for
// xpc_object_t.
//
// -----------------------------------------------------------------------------//

import Foundation
import XPC

@usableFromInline
internal struct XPCSingleValueDecodingContainer: SingleValueDecodingContainer {
  
  @usableFromInline
  internal let decoder: XPCDecoder
  
  @usableFromInline
  internal let underlyingMessage: xpc_object_t

  // MARK: - Properties
  public var codingPath: [CodingKey] {
    decoder.codingPath
  }
  
  // MARK: - Initialization
  @usableFromInline
  internal init(
    referencing decoder: XPCDecoder,
    wrapping xpcObject: xpc_object_t
  ) {
    self.decoder = decoder
    self.underlyingMessage = xpcObject
  }
  
  public func decodeNil() -> Bool {
    underlyingMessage.decodeNil(at: codingPath)
  }
  
  public func decode(_ type: Bool.Type) throws -> Bool {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: String.Type) throws -> String {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: Double.Type) throws -> Double {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: Float.Type) throws -> Float {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: Int.Type) throws -> Int {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: Int8.Type) throws -> Int8 {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: Int16.Type) throws -> Int16 {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: Int32.Type) throws -> Int32 {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: Int64.Type) throws -> Int64 {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }

  public func decode(_ type: Int128.Type) throws -> Int128 {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }

  public func decode(_ type: UInt.Type) throws -> UInt {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: UInt8.Type) throws -> UInt8 {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: UInt16.Type) throws -> UInt16 {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: UInt32.Type) throws -> UInt32 {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: UInt64.Type) throws -> UInt64 {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }

  public func decode(_ type: UInt128.Type) throws -> UInt128 {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }

  public func decode<T: Decodable>(_ type: T.Type) throws -> T {
    try T(
      from: XPCDecoder(
        underlyingMessage: underlyingMessage,
        at: decoder.codingPath
      )
    )
  }
}

