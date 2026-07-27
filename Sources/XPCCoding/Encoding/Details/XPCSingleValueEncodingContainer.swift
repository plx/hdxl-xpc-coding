// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

// MARK: XPCSingleValueEncodingContainer

/// Our internal implementation of `SingleValueEncodingContainer`.
internal struct XPCSingleValueEncodingContainer: SingleValueEncodingContainer {

  internal typealias StringKeyStrategy = XPCEncoder.StringKeyStrategy

  internal typealias StringValueStrategy = XPCEncoder.StringValueStrategy

  /// We always use the encoder's string key strategy.
  internal var stringKeyStrategy: StringKeyStrategy { encoder.stringKeyStrategy }

  /// We always use the encoder's string value strategy.
  internal var stringValueStrategy: StringValueStrategy { encoder.stringValueStrategy }

  /// The immutable path at which this container was created.
  internal let codingPath: [any CodingKey]

  /// Our parent encoder.
  internal let encoder: _XPCEncoder

  /// The closure we use to insert the encoded value into the parent encoder's XPC object.
  internal let insertionClosure: (xpc_object_t) throws -> Void

  // MARK: - Initialization

  /// Initialize a new `XPCSingleValueEncodingContainer`.
  ///
  /// - Parameters:
  ///   - encoder: The parent encoder.
  ///   - codingPath: The immutable path at which the container was created.
  ///   - insertionClosure: The closure we use to insert the encoded value into the parent encoder's XPC object.
  internal init(
    referencing encoder: _XPCEncoder,
    codingPath: [any CodingKey],
    insertionClosure: @escaping (xpc_object_t) throws -> Void
  ) {
    self.encoder = encoder
    self.codingPath = codingPath
    self.insertionClosure = insertionClosure
  }

  // MARK: - SingleValueEncodingContainer

  internal mutating func encodeNil() throws {
    try insertionClosure(xpc_null_create())
  }

  internal mutating func encode(_ value: Bool) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: String) throws {
    try encodeStringValue(value)
  }

  internal mutating func encode(_ value: Double) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: Float) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: Int) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: Int8) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: Int16) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: Int32) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: Int64) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: Int128) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: UInt) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: UInt8) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: UInt16) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: UInt32) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: UInt64) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode(_ value: UInt128) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }

  internal mutating func encode<T: Encodable>(_ value: T) throws {
    let xpcObject = try _XPCEncoder.encode(
      value,
      at: codingPath,
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      userInfo: encoder.userInfo
    )
    try insertionClosure(xpcObject)
  }
}

// MARK: - Support API

extension XPCSingleValueEncodingContainer {

  /// How we encode `LosslessXPCObjectConvertible` values (which cover almost all protocol requirements).
  internal func encodeLosslessXPCObjectConvertible(_ value: some LosslessXPCObjectConvertible) throws {
    try insertionClosure(value.xpcObjectRepresentation)
  }

  /// Special-case handling of `String` values (in order to support `stringValueStrategy`).
  internal func encodeStringValue(_ value: String) throws {
    try insertionClosure(
      try value.makeXPCObjectRepresentation(
        stringValueStrategy: stringValueStrategy,
        codingPath: codingPath
      )
    )
  }

}

// MARK: - XPCEnhancedSingleValueEncodingContainer

extension XPCSingleValueEncodingContainer: XPCEnhancedSingleValueEncodingContainer {

  internal mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeRawPointer?,
    count: Int
  ) throws {
    try validateUnsafePointerCount(
      unsafePointer,
      count: count,
      codingPath: codingPath
    )
    let xpcObject = xpc_data_create(
      unsafePointer,
      count
    )
    try insertionClosure(xpcObject)
  }

  internal mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeMutableRawPointer?,
    count: Int
  ) throws {
    try validateUnsafePointerCount(
      unsafePointer,
      count: count,
      codingPath: codingPath
    )
    let xpcObject = xpc_data_create(
      unsafePointer.map { UnsafeRawPointer($0) },
      count
    )
    try insertionClosure(xpcObject)
  }

  internal mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeRawBufferPointer) throws {
    try directlyEncodeXPCData(
      unsafeBufferPointer.baseAddress,
      count: unsafeBufferPointer.count
    )
  }

  internal mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeMutableRawBufferPointer) throws {
    try directlyEncodeXPCData(
      unsafeBufferPointer.baseAddress,
      count: unsafeBufferPointer.count
    )
  }

}
