import XPC

@usableFromInline
internal class _XPCEncoder: Encoder {
  
  @usableFromInline
  internal typealias StringKeyStrategy = XPCEncoder.StringKeyStrategy
  
  @usableFromInline
  internal typealias StringValueStrategy = XPCEncoder.StringValueStrategy
  
  @usableFromInline
  internal let stringKeyStrategy: XPCEncoder.StringKeyStrategy
  
  @usableFromInline
  internal let stringValueStrategy: XPCEncoder.StringValueStrategy

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
  internal var codingPath: [any CodingKey] { _codingPath }
  
  @usableFromInline
  internal var _userInfo: [CodingUserInfoKey : Any] = [:]
  
  @inlinable
  internal var userInfo: [CodingUserInfoKey : Any] { _userInfo}
  
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
  internal init(
    stringKeyStrategy: StringKeyStrategy,
    stringValueStrategy: StringValueStrategy,
    codingPath: [CodingKey] = []
  ) {
    self.stringKeyStrategy = stringKeyStrategy
    self.stringValueStrategy = stringValueStrategy
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

}

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
  
}

extension _XPCEncoder {
  
  @usableFromInline
  internal static func encode(
    _ value: some Encodable,
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
    guard let output = encoder.topLevelContainer else {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "Couldn't get a `topLevelContainer` from encoder.",
          underlyingError: nil
        )
      )
    }
    return output
  }
  
}
