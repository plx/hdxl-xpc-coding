import Foundation
import XPC

@usableFromInline
internal struct XPCSingleValueDecodingContainer: SingleValueDecodingContainer {
  
  @usableFromInline
  internal typealias StringKeyStrategy = XPCDecoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCDecoder.StringValueStrategy
  
  @inlinable @inline(__always)
  internal var stringKeyStrategy: XPCDecoder.StringKeyStrategy { decoder.stringKeyStrategy }
  
  @inlinable @inline(__always)
  internal var stringValueStrategy: XPCDecoder.StringValueStrategy { decoder.stringValueStrategy }

  @usableFromInline
  internal let decoder: _XPCDecoder
  
  @usableFromInline
  internal let underlyingMessage: xpc_object_t

  // MARK: - Properties
  public var codingPath: [any CodingKey]
  
  // MARK: - Initialization
  @usableFromInline
  internal init(
    referencing decoder: _XPCDecoder,
    wrapping xpcObject: xpc_object_t,
    codingPath: [any CodingKey]
  ) {
    self.decoder = decoder
    self.underlyingMessage = xpcObject
    self.codingPath = codingPath
  }
  
  public func decodeNil() -> Bool {
    underlyingMessage.decodeNil(at: codingPath)
  }
  
  public func decode(_ type: Bool.Type) throws -> Bool {
    try underlyingMessage.extractValue(ofType: type, at: codingPath)
  }
  
  public func decode(_ type: String.Type) throws -> String {
    try underlyingMessage.extractStringValue(
      stringValueStrategy: stringValueStrategy,
      at: codingPath
    )
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
    if let directExtraction = underlyingMessage.attemptDirectExtraction(type, stringValueStrategy: stringValueStrategy) {
      return directExtraction
    }
    
    return try T(
      from: _XPCDecoder(
        stringKeyStrategy: stringKeyStrategy,
        stringValueStrategy: stringValueStrategy,
        decoding: underlyingMessage,
        at: codingPath
      )
    )
  }
}

