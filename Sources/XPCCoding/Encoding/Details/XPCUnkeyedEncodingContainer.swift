import Foundation
import XPC

// MARK: XPCUnkeyedEncodingContainer

/// Our internal unkeyed encoding container.
@usableFromInline
internal struct XPCUnkeyedEncodingContainer: UnkeyedEncodingContainer {

  @usableFromInline
  internal typealias StringKeyStrategy = XPCEncoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCEncoder.StringValueStrategy
  
  /// We always retrieve our string key strategy from our parent encoder.
  @inlinable @inline(__always)
  internal var stringKeyStrategy: StringKeyStrategy { encoder.stringKeyStrategy }
  
  /// We always retrieve our string value strategy from our parent encoder.
  @inlinable @inline(__always)
  internal var stringValueStrategy: StringValueStrategy { encoder.stringValueStrategy }

  /// We always retrieve our coding path from our parent encoder.
  @usableFromInline  @inline(__always)
  internal var codingPath: [CodingKey] { encoder.codingPath }
  
  /// Count of already-encoded items in this container.
  @usableFromInline
  internal var count: Int {
    xpc_array_get_count(underlyingXPCArray)
  }
  
  /// The encoder into-which we're doing our encoding.
  @usableFromInline
  internal let encoder: _XPCEncoder
  
  /// The underlying XPC array we're encoding into.
  @usableFromInline
  internal let underlyingXPCArray: xpc_object_t
  
  // MARK: - Initialization

  /// Memberwise-initialize a new unkeyed encoding container.
  /// - Parameters:
  ///   - encoder: The encoder into-which we're doing our encoding.
  ///   - underlyingXPCArray: The underlying XPC array we're encoding into.
  /// - Throws: `EncodingError.invalidValue` if `underlyingXPCArray` is not an XPC array.
  @usableFromInline
  internal init(
    referencing encoder: _XPCEncoder,
    wrapping underlyingXPCArray: xpc_object_t
  ) throws {
    self.encoder = encoder
    
    guard underlyingXPCArray.isArray else {
      throw EncodingError.invalidValue(
        underlyingXPCArray,
        EncodingError.Context(
          codingPath: encoder.codingPath,
          debugDescription: "Supplied a non-array xpc object (actual type: `\(underlyingXPCArray.typeDescription))"
        )
      )
    }
    
    self.underlyingXPCArray = underlyingXPCArray
  }

  // MARK: - UnkeyedEncodingContainer
  
  @usableFromInline
  internal mutating func encodeNil() throws {
    try withNextCodingKey { _ in
      xpc_array_append_value(underlyingXPCArray, xpc_null_create())
    }
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Bool) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode(_ value: String) throws {
    // string needs special handling to respect our string-value strategy
    try appendNextStringValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Double) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Float) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int8) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int16) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int32) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: Int64) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode(_ value: Int128) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode(_ value: UInt) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt8) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt16) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt32) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }
  
  @usableFromInline
  internal mutating func encode(_ value: UInt64) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode(_ value: UInt128) throws {
    try appendNextLosslesslyConvertibleValue(value)
  }

  @usableFromInline
  internal mutating func encode<T: Encodable>(_ value: T) throws {
    // Fast path for Data - encode directly as xpc_data_t
    if let data = value as? Data {
      try withNextCodingKey { _ in
        data.withUnsafeBytes { buffer in
          xpc_array_append_value(
            underlyingXPCArray,
            xpc_data_create(buffer.baseAddress, buffer.count)
          )
        }
      }
      return
    }

    try withNextCodingKey { codingPath in
      do {
        let xpcObject = try _XPCEncoder.encode(
          value,
          at: codingPath,
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: stringValueStrategy
        )
        xpc_array_append_value(underlyingXPCArray, xpcObject)
      } catch let underlyingError {
        throw EncodingError.invalidValue(
          value,
          EncodingError.Context(
            codingPath: codingPath,
            debugDescription: "Unabled to append value: \(String(reflecting: value))!",
            underlyingError: underlyingError
          )
        )
      }
    }
  }
  
  @usableFromInline
  internal mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
    do {
      return try withNextCodingKey { _ in
        let xpcDictionary = xpc_dictionary_create(nil, nil, 0)
        xpc_array_append_value(underlyingXPCArray, xpcDictionary)
        
        let container = try XPCKeyedEncodingContainer<NestedKey>(referencing: encoder, wrapping: xpcDictionary)
        return KeyedEncodingContainer(container)
      }
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable error preparing nested keyed container (due to API limitations requiring non-throwing construction here).
        
        - keyType: \(keyType)
        - error: \(String(reflecting: error))
        """
      )
    }
  }
  
  @usableFromInline
  internal mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    do {
      return try withNextCodingKey { _ in
        let xpcArray = xpc_array_create(nil, 0)
        xpc_array_append_value(underlyingXPCArray, xpcArray)
        
        return try XPCUnkeyedEncodingContainer(referencing: encoder, wrapping: xpcArray)
      }
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable error preparing nested unkeyed container (due to API limitations requiring non-throwing construction here).
        
        - error: \(String(reflecting: error))
        """
      )
    }
  }
  
  @usableFromInline
  internal mutating func superEncoder() -> Encoder {
    do {
      return try withNextCodingKey { codingPath in
        // TODO: investigate if we can refactor so as to avoid injecting this placeholder value
        xpc_array_append_value(underlyingXPCArray, xpc_null_create())
        return _XPCArrayReferencingEncoder(
          stringKeyStrategy: stringKeyStrategy,
          stringValueStrategy: stringValueStrategy,
          codingPath: codingPath,
          index: count - 1,
          array: underlyingXPCArray
        )
      }
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable error preparing nested unkeyed container (due to API limitations requiring non-throwing construction here).
        
        - error: \(String(reflecting: error))
        """
      )
    }
  }
}

// MARK: - Support API

extension XPCUnkeyedEncodingContainer {
  
  /// The coding key suitable-for appending our next encoded value.
  @usableFromInline
  internal var nextCodingKey: XPCCodingKey {
    XPCCodingKey(intValue: count)
  }
  
  /// Executes `closure` while temporarily extending our coding path with the value of `nextCodingKey`.
  /// 
  /// - Parameter closure: The closure to execute.
  /// - Returns: The return value of `closure`.
  /// - Throws: Any error thrown by `closure`.
  /// 
  /// - SeeAlso: ``_XPCEncoder.withTransientCodingPathElement(_:_:)```
  /// - SeeAlso: ``nextCodingKey``
  @inlinable
  internal func withNextCodingKey<R>(_ closure: ([any CodingKey]) throws -> R) throws -> R {
    try encoder.withTransientCodingPathElement(nextCodingKey) { codingPath in
      try closure(codingPath)
    }
  }
  
  /// Directly appends an XPC object to our underlying XPC array, with proper coding-path management.
  @inlinable
  internal func appendNextXPCValue(_ value: xpc_object_t) throws {
    try withNextCodingKey { _ in
      xpc_array_append_value(underlyingXPCArray, value)
    }
  }

  /// Directly appends a losslessly-convertible value to our underlying XPC array, with proper coding-path management.
  @inlinable
  internal func appendNextLosslesslyConvertibleValue(_ value: some LosslessXPCObjectConvertible) throws {
    try appendNextXPCValue(value.xpcObjectRepresentation)
  }

  /// Directly appends a string value to our underlying XPC array, with proper coding-path management (and ensuring proper string-value strategy handling). 
  @inlinable
  internal func appendNextStringValue(_ value: String) throws {
    try withNextCodingKey { codingPath in      
      do {
        let xpcObject = try value.makeXPCObjectRepresentation(stringValueStrategy: stringValueStrategy)
        xpc_array_append_value(underlyingXPCArray, xpcObject)
      }
      catch let incompatibilityError {
        throw EncodingError.invalidValue(
          value,
          EncodingError.Context(
            codingPath: codingPath,
            debugDescription: "Attempted to append xpc-incompatible value \(value).",
            underlyingError: incompatibilityError
          )
        )
      }
    }
  }
}

// MARK: - XPCEnhancedUnkeyedEncodingContainer

extension XPCUnkeyedEncodingContainer: XPCEnhancedUnkeyedEncodingContainer {
    
  @inlinable
  internal mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeRawPointer?,
    count: Int
  ) throws {
    try appendNextXPCValue(
      xpc_data_create(
        unsafePointer,
        count
      )
    )
  }
  
  @inlinable
  internal mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeMutableRawPointer?,
    count: Int
  ) throws {
    try appendNextXPCValue(
      xpc_data_create(
        unsafePointer.map { UnsafeRawPointer($0) },
        count
      )
    )
  }
  
  @inlinable
  internal mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeRawBufferPointer) throws {
    try appendNextXPCValue(
      xpc_data_create(
        unsafeBufferPointer.baseAddress,
        unsafeBufferPointer.count
      )
    )
  }
  
  @inlinable
  internal mutating func directlyEncodeXPCData(_ unsafeBufferPointer: UnsafeMutableRawBufferPointer) throws {
    try appendNextXPCValue(
      xpc_data_create(
        unsafeBufferPointer.baseAddress.map { UnsafeRawPointer($0) },
        unsafeBufferPointer.count
      )
    )
  }
 
}

