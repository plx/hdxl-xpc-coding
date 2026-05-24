import Foundation
import XPC

// MARK: _XPCEncoder

/// The internal encoder implementation behind the facade (and the actual `Encoder` conformance).
@usableFromInline
internal class _XPCEncoder: Encoder {
  
  @usableFromInline
  internal typealias StringKeyStrategy = XPCEncoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCEncoder.StringValueStrategy
  
  /// The string key strategy to use (locked at construction).
  @usableFromInline
  internal let stringKeyStrategy: XPCEncoder.StringKeyStrategy
  
  /// The string value strategy to use (locked at construction).
  @usableFromInline
  internal let stringValueStrategy: XPCEncoder.StringValueStrategy

  /// Backing storage for the coding path.
  @usableFromInline
  internal var _codingPath: [CodingKey]
  
  /// Read-only access to the coding path (protocol requirement).
  @inlinable @inline(__always)
  internal var codingPath: [any CodingKey] { _codingPath }
  
  /// Backing storage for the user info.
  @usableFromInline
  internal var _userInfo: [CodingUserInfoKey : Any] = [:]
  
  /// Read-only access to the user info (protocol requirement).
  @inlinable
  internal var userInfo: [CodingUserInfoKey : Any] { _userInfo}
  
  /// Our internal state vis-a-vis our top-level container.
  @usableFromInline
  internal var topLevelContainerState: ContainerState = .noContainerYet
  
  /// The active kind of our top-level container (if any).
  @inlinable
  internal var topLevelContainerKind: ContainerKind? {
    topLevelContainerState.containerKind
  }
  
  /// The underlying top-level container (if any).
  @inlinable
  internal var topLevelContainer: xpc_object_t? {
    topLevelContainerState.containerObject
  }
  
  /// Memberwise initializer.
  @inlinable
  internal init(
    stringKeyStrategy: StringKeyStrategy,
    stringValueStrategy: StringValueStrategy,
    codingPath: [CodingKey] = [],
    userInfo: [CodingUserInfoKey : Any] = [:]
  ) {
    self.stringKeyStrategy = stringKeyStrategy
    self.stringValueStrategy = stringValueStrategy
    self._codingPath = codingPath
    self._userInfo = userInfo
  }

  // MARK: - Encoder
  
  @usableFromInline
  internal func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
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

  @usableFromInline
  internal func unkeyedContainer() -> UnkeyedEncodingContainer {
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

  @usableFromInline
  internal func singleValueContainer() -> SingleValueEncodingContainer {
    switch containerRequestDisposition(containerKind: .pendingSingleValue) {
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

}

// MARK: - Support API

extension _XPCEncoder {
  
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
    return try closure(_codingPath)
  }

  /// Shorthand to create a transient encoder and immediately encode a value.
  /// 
  /// - Parameters:
  ///   - value: The value to encode.
  ///   - codingPath: The coding path to report in case of errors.
  ///   - stringKeyStrategy: The string key strategy to use.
  ///   - stringValueStrategy: The string value strategy to use.
  /// - Returns: The encoded value.
  /// - Throws: An error if encoding fails.
  @inlinable
  internal static func encode<T: Encodable>(
    _ value: T,
    at codingPath: [any CodingKey] = [],
    stringKeyStrategy: StringKeyStrategy,
    stringValueStrategy: StringValueStrategy
  ) throws -> xpc_object_t {
    let encoder = _XPCEncoder(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      codingPath: codingPath
    )
    try value.encode(to: encoder)
    guard let topLevelContainer = encoder.topLevelContainer else {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "Unable to obtain top-level container despite apparently-successful encoding."
        )
      )
    }
    return topLevelContainer
  }
  
}

// MARK: - Container Management

extension _XPCEncoder {

  /// Used to represent how we should proceed after being asked to create a container.
  @usableFromInline
  internal enum ContainerRequestDisposition {
    /// We can't continue a single-value container.
    case unableToContinueSingleValueContainer

    /// We were asked to create a new container of a different kind from the active one.
    /// 
    /// This shows up when a user requests a keyed container, but then goes on to request an unkeyed one (from the same encoder).
    /// Such "container-kind switches" are not allowed within the serialization API contract.
    case unableToSwitchContainerKind(ContainerKind, ContainerKind)

    /// The user has requested a container of the same kind as the active one.
    /// 
    /// Although potentially non-intuitive, this is actually allowed within the serialization API contract:
    /// 
    /// ```swift
    /// class Bar: Encodable {
    /// 
    ///   func encode(to encoder: Encoder) throws {
    ///     var container = encoder.container(keyedBy: CodingKeys.self)
    ///     try container.encode(Bar(), forKey: .bar)
    ///   }
    /// }
    /// 
    /// class Bar: Foo {
    /// 
    ///   override func encode(to encoder: Encoder) throws {
    ///     var container = encoder.container(keyedBy: CodingKeys.self)
    ///     try container.encode(Bar(), forKey: .bar)
    ///     try super.encode(to: encoder) 
    ///     // ^ re-using same encoder is allowed, as long as superclass doesn't request a different container kind.
    ///   }
    /// }
    /// ```
    case continueExistingContainer(xpc_object_t)

    /// We should proceed with creating the requested container.
    case proceedWithContainerCreation
  }

  /// Used to "crash out" when we're asked to create a container of a different kind from the active one (e.g. single-value -> keyed, or keyed -> unkeyed, etc.).
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

  /// Used to "crash out" when we're asked to *continue* a single-value container (e.g. to vend another single-value container after already vending one).
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

  /// Determine how we should proceed after being asked to create a container of a given kind.
  @inlinable
  internal func containerRequestDisposition(
    containerKind: ContainerKind
  ) -> ContainerRequestDisposition {
    switch (topLevelContainerState, containerKind) {
    case (.noContainerYet, _):
      // we can always start working with a new container
      .proceedWithContainerCreation
    case (.pendingSingleValue, _):
      // never ok to continue after vending a single-value container
      .unableToContinueSingleValueContainer
    case (.completedSingleValue, _):
      // never ok to continue after vending a single-value container
      .unableToContinueSingleValueContainer
    case (.keyed(let xpcObject), .keyed):
      // ok to "continue" a keyed container 
      .continueExistingContainer(xpcObject)
    case (.keyed, _):
      // not ok to "switch" from keyed to unkeyed
      .unableToSwitchContainerKind(.keyed, containerKind)
    case (.unkeyed(let xpcObject), .unkeyed):
      // ok to "continue" an unkeyed container
      .continueExistingContainer(xpcObject)
    case (.unkeyed, _):
      // not ok to "switch" from unkeyed to keyed
      .unableToSwitchContainerKind(.unkeyed, containerKind)
    }
  }
  
  /// Internal helper to create-or-continue a keyed container.
  ///
  /// - Note: the associated `Encoder` API doesn't support failure here, so we just "crash out" upon improper usage.
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

  /// Internal helper to create-or-continue an unkeyed container.
  ///
  /// - Note: the associated `Encoder` API doesn't support failure here, so we just "crash out" upon improper usage.
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

  /// Internal helper to create a single-value container.
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

}

// MARK: _XPCEncoder.ContainerKind

extension _XPCEncoder {
  /// The types of container we can have already created.
  @usableFromInline
  internal enum ContainerKind {
    /// We have created a keyed container.
    case keyed
    /// We have created an unkeyed container.
    case unkeyed

    /// We have vended a single-value container, but haven't yet received the underlying value.
    case pendingSingleValue

    /// We vended a single-value container and have received the completed value.
    case completedSingleValue
  }

}

// MARK: - Synthesized Conformances

extension _XPCEncoder.ContainerKind: Sendable {}
extension _XPCEncoder.ContainerKind: Equatable {}
extension _XPCEncoder.ContainerKind: Hashable {}
extension _XPCEncoder.ContainerKind: CaseIterable {}

// MARK: - CustomStringConvertible

extension _XPCEncoder.ContainerKind: CustomStringConvertible {

  @usableFromInline
  internal var description: String {
    switch self {
    case .keyed:
      "keyed"
    case .unkeyed:
      "unkeyed"
    case .pendingSingleValue:
      "single-value (pending)"
    case .completedSingleValue:
      "single-value (complete)"
    }
  }
}

// MARK: - CustomDebugStringConvertible

extension _XPCEncoder.ContainerKind: CustomDebugStringConvertible {

  @usableFromInline
  internal var debugDescription: String {
    switch self {
    case .keyed:
      "\(Self.self).keyed"
    case .unkeyed:
      "\(Self.self).unkeyed"
    case .pendingSingleValue:
      "\(Self.self).pendingSingleValue"
    case .completedSingleValue:
      "\(Self.self).completedSingleValue"
    }
  }

}

// MARK: _XPCEncoder.ContainerState

extension _XPCEncoder {

  /// The state of our top-level container.
  /// 
  /// The reason we use this is twofold:
  /// 
  /// - we can't make our container until we know the type of container we need
  /// - users aren't allowed to create multiple containers for a given encoder—we need to protect that invariant
  /// 
  @usableFromInline
  internal enum ContainerState {

    /// We have not yet created a container.
    case noContainerYet

    /// We have created a keyed container.
    case keyed(xpc_object_t)

    /// We have created an unkeyed container.
    case unkeyed(xpc_object_t)
    
    /// We have vended a single-value container, but haven't yet received the underlying value.
    case pendingSingleValue
    
    /// We vended a single-value container and have received the completed value.
    case completedSingleValue(xpc_object_t)
    
    /// Access the active container object, if any.
    @inlinable
    internal var containerObject: xpc_object_t? {
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

    /// Access the active container kind, or `nil` if no container has been created.
    @inlinable
    internal var containerKind: ContainerKind? {
      switch self {
      case .noContainerYet:
        nil
      case .keyed:
        .keyed
      case .unkeyed:
        .unkeyed
      case .pendingSingleValue:
        .pendingSingleValue
      case .completedSingleValue:
        .completedSingleValue
      }
    }

    /// `true` iff we're in a state from-which we can begin a container.
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

}

// MARK: - CustomStringConvertible

extension _XPCEncoder.ContainerState: CustomStringConvertible {

  @usableFromInline
  internal var description: String {
    switch self {
    case .noContainerYet:
      ".noContainerYet"
    case .keyed(let xpcObject):
      ".keyed(\(xpcObject.typeDescription))"
    case .unkeyed(let xpcObject):
      ".unkeyed(\(xpcObject.typeDescription))"
    case .pendingSingleValue:
      ".pendingSingleValue"
    case .completedSingleValue(let xpcObject):
      ".completedSingleValue(\(xpcObject.typeDescription))"
    }
  }

}

// MARK: - CustomStringConvertible

extension _XPCEncoder.ContainerState: CustomDebugStringConvertible {  
  @usableFromInline
  internal var debugDescription: String {
    switch self {
    case .noContainerYet:
      "\(Self.self).noContainerYet"
    case .keyed(let xpcObject):
      "\(Self.self).keyed(\(xpcObject.typeDescription))"
    case .unkeyed(let xpcObject):
      "\(Self.self).unkeyed(\(xpcObject.typeDescription))"
    case .pendingSingleValue:
      "\(Self.self).pendingSingleValue"
    case .completedSingleValue(let xpcObject):
      "\(Self.self).completedSingleValue(\(xpcObject.typeDescription))"
    }
  }
}
