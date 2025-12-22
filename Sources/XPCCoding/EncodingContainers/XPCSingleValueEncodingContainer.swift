// Sources/CodableXPC/XPCSingleValueEncodingContainer.swift -
// SingleValueEncodingContainer for XPC
//
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// -----------------------------------------------------------------------------
//
// This file contains a SincludeValueEncodingContainer implementation for
// xpc_object_t.
//
// -----------------------------------------------------------------------------//

import XPC

@usableFromInline
internal struct XPCSingleValueEncodingContainer: SingleValueEncodingContainer {
  // MARK: - Properties
  public var codingPath: [CodingKey] {
    encoder.codingPath
  }
  
  @usableFromInline
  internal let encoder: XPCEncoder
  
  @usableFromInline
  internal let insertionClosure: (xpc_object_t) throws -> ()
  
  // MARK: - Initialization
  init(
    referencing encoder: XPCEncoder,
    insertionClosure: @escaping (xpc_object_t) throws -> ()
  ) {
    self.encoder = encoder
    self.insertionClosure = insertionClosure
  }
  
  // MARK: - SingleValueEncodingContainer protocol methods
  @usableFromInline
  internal func encodeXPCObjectConvertible(_ value: some XPCObjectConvertible) throws {
    do {
      let xpcObject = try value.makeXPCObjectRepresentation()
      try insertionClosure(xpcObject)
    }
    catch let incompatibilityError {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: encoder.codingPath,
          debugDescription: "XPC-incompatible value \(String(describing: value))",
          underlyingError: incompatibilityError
        )
      )
    }
  }

  @usableFromInline
  internal func encodeLosslessXPCObjectConvertible(_ value: some LosslessXPCObjectConvertible) throws {
    try insertionClosure(value.xpcObjectRepresentation)
  }

  public mutating func encodeNil() throws {
    try insertionClosure(xpc_null_create())
  }
  
  public mutating func encode(_ value: Bool) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: String) throws {
    try encodeXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: Double) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: Float) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: Int) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: Int8) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: Int16) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: Int32) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: Int64) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: Int128) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: UInt) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: UInt8) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: UInt16) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: UInt32) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: UInt64) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: UInt128) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode<T: Encodable>(_ value: T) throws {
    let xpcObject = try XPCEncoder.encode(value, at: codingPath)
    try insertionClosure(xpcObject)
  }
}

