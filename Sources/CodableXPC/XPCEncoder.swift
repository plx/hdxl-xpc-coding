// Sources/CodableXPC/XPCEncoder.swift - Encoder implementation for XPC
//
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// -----------------------------------------------------------------------------
//
// This file contains stuff an Encoder implementation for xpc_object_t as well
// as generic utility functions for encoding primiives that are reused by the
// encoding containers.
//
// -----------------------------------------------------------------------------//

import XPC

public class XPCEncoder: Encoder {
  @usableFromInline
  internal enum ContainerKind: String {
    case keyed
    case unkeyed
    case singleValue
    case noContainer
  }
  
  @usableFromInline
  internal var _codingPath: [CodingKey]
  
  @inlinable @inline(__always)
  public var codingPath: [any CodingKey] { _codingPath }
  
  @usableFromInline
  internal var _userInfo: [CodingUserInfoKey : Any] = [:]
  
  @inlinable
  public var userInfo: [CodingUserInfoKey : Any] { _userInfo}
  
  @usableFromInline
  internal var topLevelContainer: xpc_object_t?
  
  @usableFromInline
  internal var containerKind: ContainerKind = .noContainer
  
  public init(at codingPath: [CodingKey] = []) {
    self._codingPath = codingPath
  }
  
  public func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
    switch containerKind {
    case .noContainer:
      topLevelContainer = xpc_dictionary_create(nil, nil, 0)
      containerKind = .keyed
    case .keyed:
      break
    default:
      preconditionFailure("This encoder already has a container of kind \(containerKind)")
    }
    
    // It is OK to force this because we are explicitly passing a dictionary
    let container = try! XPCKeyedEncodingContainer<Key>(referencing: self, wrapping: topLevelContainer!)
    return KeyedEncodingContainer(container)
  }
  
  public func unkeyedContainer() -> UnkeyedEncodingContainer {
    switch containerKind {
    case .noContainer:
      topLevelContainer = xpc_array_create(nil, 0)
      containerKind = .unkeyed
    case .unkeyed:
      break
    default:
      preconditionFailure("This encoder already has a container of kind \(containerKind)")
    }
    
    //It is OK to force this through becasue we are explicitly passing an array
    return try! XPCUnkeyedEncodingContainer(referencing: self, wrapping: topLevelContainer!)
  }
  
  public func singleValueContainer() -> SingleValueEncodingContainer {
    switch containerKind {
    case .noContainer:
      containerKind = .singleValue
    default:
      preconditionFailure("This encoder already has a container of kind \(containerKind)")
    }
    
    return XPCSingleValueEncodingContainer(referencing: self) { [unowned(unsafe) self] in
      topLevelContainer = $0
    }
  }
  
  public static func encode<T: Encodable>(_ value: T, at codingPath: [CodingKey] = []) throws -> xpc_object_t {
    let encoder = XPCEncoder(at: codingPath)
    try value.encode(to: encoder)
    return encoder.topLevelContainer!
  }
}

extension XPCEncoder {
  
  @inlinable
  internal func withTransientCodingPathElement<Key, R>(
    _ codingPathElement: Key,
    _ closure: ([any CodingKey]) throws -> R
  ) rethrows -> R where Key: CodingKey {
    _codingPath.append(codingPathElement)
    defer {
      #if DEBUG
      assert(!_codingPath.isEmpty)
      let removed = _codingPath.removeLast()
      assert(removed.stringValue == codingPathElement.stringValue)
      assert(removed.intValue == codingPathElement.intValue)
      #else
      _codingPath.removeLast()
      #endif
    }
    return try closure(_codingPath)
  }
  
}
