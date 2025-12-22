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
    case pendingSingleValue
    case completedSingleValue
  }

  @usableFromInline
  internal enum ContainerState {
    case keyed(xpc_object_t)
    case unkeyed(xpc_object_t)
    case pendingSingleValue
    case completedSingleValue(xpc_object_t)
    case noContainerYet
    
    @inlinable
    var containerObject: xpc_object_t? {
      switch self {
      case .keyed(let containerObject):
        containerObject
      case .unkeyed(let containerObject):
        containerObject
      case .pendingSingleValue:
        nil
      case .completedSingleValue(let containerObject):
        containerObject
      case .noContainerYet:
        nil
      }
    }

    @inlinable
    var containerKind: ContainerKind? {
      switch self {
      case .keyed:
        .keyed
      case .unkeyed:
        .unkeyed
      case .pendingSingleValue:
        .pendingSingleValue
      case .completedSingleValue:
        .completedSingleValue
      case .noContainerYet:
        nil
      }
    }

    @inlinable
    internal var canBeginContainer: Bool {
      switch self {
      case .noContainerYet:
        true
      default:
        false
      }
    }
    
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
  internal var topLevelContainerState: ContainerState = .noContainerYet
  
  @inlinable
  internal var topLevelContainerKind: ContainerKind? {
    topLevelContainerState.containerKind
  }
  
  @inlinable
  internal var topLevelContainer: xpc_object_t? {
    topLevelContainerState.containerObject
  }
  
  @inlinable
  internal init(at codingPath: [CodingKey] = []) {
    self._codingPath = codingPath
  }
  
  @usableFromInline
  internal enum ContainerRequestDisposition {
    case unableToContinueSingleValueContainer
    case unableToSwitchContainerKind(ContainerKind, ContainerKind)
    case continueExistingContainer(xpc_object_t)
    case proceedWithContainerCreation
  }
  
  @inlinable
  internal func abortDueToImpossibleContainerKindSwitch(
    currentKind: ContainerKind,
    requestedKind: ContainerKind,
    file: StaticString = #file,
    line: UInt = #line
  ) -> Never {
    preconditionFailure(
      """
      This container has received an impossible request to transition from a \(currentKind) container to a \(requestedKind) container.
      """,
      file: file,
      line: line
    )
  }

  @inlinable
  internal func abortDueToImpossibleSingleValueContainerContinuation(
    file: StaticString = #file,
    line: UInt = #line
  ) -> Never {
    preconditionFailure(
      """
      This container has received an impossible request to continue a single-valued container.
      """,
      file: file,
      line: line
    )
  }

  @inlinable
  internal func containerRequestDisposition(
    containerKind: ContainerKind
  ) -> ContainerRequestDisposition {
    switch (topLevelContainerState, containerKind) {
    case (.noContainerYet, _):
      .proceedWithContainerCreation
    case (.pendingSingleValue, _):
      .unableToContinueSingleValueContainer
    case (.completedSingleValue, _):
      .unableToContinueSingleValueContainer
    case (.keyed(let xpcObject), .keyed):
      .continueExistingContainer(xpcObject)
    case (.keyed, _):
      .unableToSwitchContainerKind(.keyed, containerKind)
    case (.unkeyed(let xpcObject), .unkeyed):
      .continueExistingContainer(xpcObject)
    case (.unkeyed, _):
      .unableToSwitchContainerKind(.keyed, containerKind)
    }
  }
  
  @usableFromInline
  internal final func prepareKeyedEncodingContainer<Key>(
    keyedBy type: Key.Type,
    wrapping xpcDictionary: xpc_object_t,
    file: StaticString = #file,
    line: UInt = #line
  ) -> KeyedEncodingContainer<Key> where Key : CodingKey {
    precondition(
      xpcDictionary.isDictionary,
      "Internal error: non-dictionary xpc object provided when we *must* have a dictionary!",
      file: file,
      line: line
    )
    do {
      let container = try XPCKeyedEncodingContainer<Key>(
        referencing: self,
        wrapping: xpcDictionary
      )
      return KeyedEncodingContainer(container)
    }
    catch let error {
      preconditionFailure(
        """
        Encountered unrecoverable internal error creating keyed-container:
        
        - keyedBy: \(type)
        - error: \(String(reflecting: error))
        """,
        file: file,
        line: line
      )
    }
  }
  
  @usableFromInline
  internal final func prepareUnkeyedEncodingContainer(
    wrapping xpcArray: xpc_object_t,
    file: StaticString = #file,
    line: UInt = #line
  ) -> any UnkeyedEncodingContainer {
    precondition(
      xpcArray.isArray,
      "Internal error: non-array xpc object provided when we *must* have a array!",
      file: file,
      line: line
    )
    do {
      return try XPCUnkeyedEncodingContainer(
        referencing: self,
        wrapping: xpcArray
      )
    }
    catch let error {
      preconditionFailure(
        """
        Encountered unrecoverable internal error creating unkeyed-container:
        
        - error: \(String(reflecting: error))
        """,
        file: file,
        line: line
      )
    }
  }
  
  @usableFromInline
  internal final func prepareSingleValueEncodingContainer(
    file: StaticString = #file,
    line: UInt = #line
  ) -> any SingleValueEncodingContainer {
    precondition(
      topLevelContainerKind == .pendingSingleValue,
      "Internal error: creating a single-value container when *not* in the pending-single-value state",
      file: file,
      line: line
    )
    return XPCSingleValueEncodingContainer(referencing: self) { [self] singleValueXPCObject in
      topLevelContainerState = .completedSingleValue(singleValueXPCObject)
    }
  }
  
  public func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
    switch containerRequestDisposition(containerKind: .keyed) {
    case .proceedWithContainerCreation:
      let dictionaryLikeTopLevelObject = xpc_dictionary_create_empty()
      topLevelContainerState = .keyed(dictionaryLikeTopLevelObject)
      return prepareKeyedEncodingContainer(
        keyedBy: type,
        wrapping: dictionaryLikeTopLevelObject
      )
    case .continueExistingContainer(let existingXPCDictionary):
      return prepareKeyedEncodingContainer(
        keyedBy: type,
        wrapping: existingXPCDictionary
      )
    case .unableToContinueSingleValueContainer:
      abortDueToImpossibleSingleValueContainerContinuation()
    case .unableToSwitchContainerKind(let currentKind, let requestedKind):
      abortDueToImpossibleContainerKindSwitch(
        currentKind: currentKind,
        requestedKind: requestedKind
      )
    }
  }
  
  public func unkeyedContainer() -> UnkeyedEncodingContainer {
    switch containerRequestDisposition(containerKind: .unkeyed) {
    case .proceedWithContainerCreation:
      let arrayLikeTopLevelObject = xpc_array_create_empty()
      topLevelContainerState = .unkeyed(arrayLikeTopLevelObject)
      return prepareUnkeyedEncodingContainer(
        wrapping: arrayLikeTopLevelObject
      )
    case .continueExistingContainer(let existingXPCArray):
      return prepareUnkeyedEncodingContainer(
        wrapping: existingXPCArray
      )
    case .unableToContinueSingleValueContainer:
      abortDueToImpossibleSingleValueContainerContinuation()
    case .unableToSwitchContainerKind(let currentKind, let requestedKind):
      abortDueToImpossibleContainerKindSwitch(
        currentKind: currentKind,
        requestedKind: requestedKind
      )
    }
  }
  
  public func singleValueContainer() -> SingleValueEncodingContainer {
    switch containerRequestDisposition(containerKind: .unkeyed) {
    case .proceedWithContainerCreation:
      topLevelContainerState = .pendingSingleValue
      return prepareSingleValueEncodingContainer()
    case .continueExistingContainer:
      abortDueToImpossibleSingleValueContainerContinuation()
    case .unableToContinueSingleValueContainer:
      abortDueToImpossibleSingleValueContainerContinuation()
    case .unableToSwitchContainerKind(let currentKind, let requestedKind):
      abortDueToImpossibleContainerKindSwitch(
        currentKind: currentKind,
        requestedKind: requestedKind
      )
    }
  }

  @inlinable
  internal static func encode<T: Encodable>(
    _ value: T,
    at codingPath: [any CodingKey]
  ) throws -> xpc_object_t {
    var directCompatibilityError: Error? = nil
    if let convertibleValue = value as? XPCObjectConvertible {
      do {
        return try convertibleValue.makeXPCObjectRepresentation()
      }
      catch let incompatibilityError {
        directCompatibilityError = EncodingError.invalidValue(
          value,
          EncodingError.Context(
            codingPath: codingPath,
            debugDescription: "Tried to encode incompatible top-level value: \(value)",
            underlyingError: incompatibilityError
          )
        )
      }
    }
    
    let encoder = XPCEncoder(at: codingPath)
    try value.encode(to: encoder)
    guard let topLevelContainer = encoder.topLevelContainer else {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "Unable to encode incompatible top-level value: \(value)",
          underlyingError: directCompatibilityError
        )
      )
    }
    
    return topLevelContainer
  }

  @inlinable
  public static func encode<T: Encodable>(_ value: T) throws -> xpc_object_t {
    try encode(value, at: [])
  }
}

extension XPCEncoder {
  
  @inlinable
  internal func verifyKeyCompatibility(
    key: some CodingKey,
    codingPath: [any CodingKey]
  ) throws(EncodingError) {
    do {
      try key.verifyXPCCompatibility()
    }
    catch let incompatibilityError {
      throw EncodingError.invalidValue(
        key,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "Tried to encode something with an xpc-incompatible key `\(key)`",
          underlyingError: incompatibilityError
        )
      )
    }
  }

  @inlinable
  internal func withTransientCodingPathElement<Key, R>(
    _ codingPathElement: Key,
    _ closure: ([any CodingKey]) throws -> R
  ) throws -> R where Key: CodingKey {
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
    try verifyKeyCompatibility(
      key: codingPathElement,
      codingPath: codingPath
    )
    return try closure(_codingPath)
  }
  
}
