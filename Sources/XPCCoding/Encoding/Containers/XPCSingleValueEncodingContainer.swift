import XPC

@usableFromInline
internal struct XPCSingleValueEncodingContainer: SingleValueEncodingContainer {
  
  @usableFromInline
  internal typealias StringKeyStrategy = XPCEncoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCEncoder.StringValueStrategy
  
  @inlinable @inline(__always)
  internal var stringKeyStrategy: StringKeyStrategy { encoder.stringKeyStrategy }
  
  @inlinable @inline(__always)
  internal var stringValueStrategy: StringValueStrategy { encoder.stringValueStrategy }

  // MARK: - Properties
  public var codingPath: [CodingKey] {
    encoder.codingPath
  }
  
  @usableFromInline
  internal let encoder: _XPCEncoder
  
  @usableFromInline
  internal let insertionClosure: (xpc_object_t) throws -> ()
  
  // MARK: - Initialization
  init(
    referencing encoder: _XPCEncoder,
    insertionClosure: @escaping (xpc_object_t) throws -> ()
  ) {
    self.encoder = encoder
    self.insertionClosure = insertionClosure
  }
  
  // MARK: - SingleValueEncodingContainer protocol methods

  @usableFromInline
  internal func encodeLosslessXPCObjectConvertible(_ value: some LosslessXPCObjectConvertible) throws {
    try insertionClosure(value.xpcObjectRepresentation)
  }

  @usableFromInline
  internal func encodeStringValue(_ value: String) throws {
    try insertionClosure(try value.makeXPCObjectRepresentation(stringValueStrategy: stringValueStrategy))
  }

  public mutating func encodeNil() throws {
    try insertionClosure(xpc_null_create())
  }
  
  public mutating func encode(_ value: Bool) throws {
    try encodeLosslessXPCObjectConvertible(value)
  }
  
  public mutating func encode(_ value: String) throws {
    try encodeStringValue(value)
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
    let xpcObject = try _XPCEncoder.encode(
      value,
      at: codingPath,
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy
    )
    try insertionClosure(xpcObject)
  }
}

