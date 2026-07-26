import Darwin
import Testing
import XPC
@testable import XPCCoding

// MARK: - Referencing Encoder State Tests

@Suite("Referencing Encoder State")
struct ReferencingEncoderStateTests {

  @Test(arguments: ReferencingEncoderPath.allCases)
  func `repeated keyed requests retain every field`(
    path: ReferencingEncoderPath
  ) throws {
    let expected = RepeatedKeyedPayload(first: 17, second: 29)
    let encodedPayload = try encodePayload(expected, through: path)

    #expect(
      try XPCDecoder.standard.decode(
        RepeatedKeyedPayload.self,
        from: encodedPayload
      ) == expected
    )
  }

  @Test(arguments: ReferencingEncoderPath.allCases)
  func `repeated unkeyed requests retain every element in order`(
    path: ReferencingEncoderPath
  ) throws {
    let expected = RepeatedUnkeyedPayload(first: 17, second: 29)
    let encodedPayload = try encodePayload(expected, through: path)

    #expect(
      try XPCDecoder.standard.decode(
        RepeatedUnkeyedPayload.self,
        from: encodedPayload
      ) == expected
    )
  }

  @Test(arguments: ReferencingEncoderPath.allCases)
  func `single value completion installs exactly once`(
    path: ReferencingEncoderPath
  ) throws {
    let encodedPayload = try encodePayload(
      RepeatedSingleValueCompletionProbe(first: 17, second: 29),
      through: path
    )

    #expect(
      try XPCDecoder.standard.decode(
        Int.self,
        from: encodedPayload
      ) == 17
    )
  }

  @Test
  func `array references preserve single value index validation`() throws {
    let encoder = _XPCArrayReferencingEncoder(
      stringKeyStrategy: .standard,
      stringValueStrategy: .standard,
      codingPath: [ReferencingEncoderPathKey.payload],
      userInfo: [:],
      index: 0,
      array: xpc_array_create_empty()
    )
    var container = encoder.singleValueContainer()

    do {
      try container.encode(17)
      Issue.record("Expected an out-of-bounds array reference to fail.")
    } catch let EncodingError.invalidValue(_, context) {
      #expect(context.codingPath.map(\.stringValue) == ["payload"])
      #expect(context.debugDescription.contains("0..<0"))
    } catch {
      Issue.record("Expected EncodingError.invalidValue, received \(error).")
    }
  }

  @Test(arguments: ReferencingEncoderDestination.allCases)
  func `referencing encoders match root container state dispositions`(
    destination: ReferencingEncoderDestination
  ) throws {
    for initialKind in _XPCEncoder.ContainerKind.allCases {
      let rootEncoder = makeRootEncoder()
      let referencingEncoder = makeReferencingEncoder(destination: destination)

      try establishContainer(initialKind, on: rootEncoder)
      try establishContainer(initialKind, on: referencingEncoder)

      #expect(rootEncoder.topLevelContainerKind == referencingEncoder.topLevelContainerKind)
      for requestedKind in _XPCEncoder.ContainerKind.allCases {
        #expect(
          dispositionSignature(
            rootEncoder.containerRequestDisposition(containerKind: requestedKind)
          )
            == dispositionSignature(
              referencingEncoder.containerRequestDisposition(containerKind: requestedKind)
            )
        )
      }
    }
  }

  @Test(
    .enabled(
      if: referencingEncoderSubprocessIsolationIsSupported,
      referencingEncoderSubprocessIsolationRequirement
    )
  )
  func `keyed to unkeyed transitions remain prohibited`() async {
    await #expect(processExitsWith: .failure) {
      _ = try encodePayload(
        KeyedThenUnkeyedTransitionProbe(),
        through: .root
      )
    }
    await #expect(processExitsWith: .failure) {
      _ = try encodePayload(
        KeyedThenUnkeyedTransitionProbe(),
        through: .keyedDefaultSuper
      )
    }
    await #expect(processExitsWith: .failure) {
      _ = try encodePayload(
        KeyedThenUnkeyedTransitionProbe(),
        through: .keyedNamedSuper
      )
    }
    await #expect(processExitsWith: .failure) {
      _ = try encodePayload(
        KeyedThenUnkeyedTransitionProbe(),
        through: .unkeyedSuper
      )
    }
  }

  @Test(
    .enabled(
      if: referencingEncoderSubprocessIsolationIsSupported,
      referencingEncoderSubprocessIsolationRequirement
    )
  )
  func `unkeyed to keyed transitions remain prohibited`() async {
    await #expect(processExitsWith: .failure) {
      _ = try encodePayload(
        UnkeyedThenKeyedTransitionProbe(),
        through: .root
      )
    }
    await #expect(processExitsWith: .failure) {
      _ = try encodePayload(
        UnkeyedThenKeyedTransitionProbe(),
        through: .keyedDefaultSuper
      )
    }
    await #expect(processExitsWith: .failure) {
      _ = try encodePayload(
        UnkeyedThenKeyedTransitionProbe(),
        through: .keyedNamedSuper
      )
    }
    await #expect(processExitsWith: .failure) {
      _ = try encodePayload(
        UnkeyedThenKeyedTransitionProbe(),
        through: .unkeyedSuper
      )
    }
  }

}

// MARK: - Subprocess Support

private let referencingEncoderSubprocessIsolationRequirement: Comment = """
  Subprocess-isolated tests need a test host that can re-launch itself with the \
  sanitizer runtime loaded early enough to install its interceptors.
  """

private let referencingEncoderSubprocessIsolationIsSupported: Bool = {
  let interceptingSanitizerSymbols = ["__asan_init", "__tsan_init"]
  let allLoadedImages = UnsafeMutableRawPointer(bitPattern: -2)
  return interceptingSanitizerSymbols.allSatisfy { symbolName in
    symbolName.withCString { symbol in
      dlsym(allLoadedImages, symbol) == nil
    }
  }
}()

// MARK: - Encoder Paths

enum ReferencingEncoderPath: CaseIterable {
  case root
  case keyedDefaultSuper
  case keyedNamedSuper
  case unkeyedSuper
}

enum ReferencingEncoderDestination: CaseIterable {
  case array
  case dictionary
}

private enum ReferencingEncoderPathKey: String, CodingKey {
  case payload
}

private struct KeyedDefaultSuperWrapper<Payload: Encodable>: Encodable {
  let payload: Payload

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: ReferencingEncoderPathKey.self)
    try payload.encode(to: container.superEncoder())
  }
}

private struct KeyedNamedSuperWrapper<Payload: Encodable>: Encodable {
  let payload: Payload

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: ReferencingEncoderPathKey.self)
    try payload.encode(to: container.superEncoder(forKey: .payload))
  }
}

private struct UnkeyedSuperWrapper<Payload: Encodable>: Encodable {
  let payload: Payload

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    try payload.encode(to: container.superEncoder())
  }
}

private func encodePayload<Payload: Encodable>(
  _ payload: Payload,
  through path: ReferencingEncoderPath
) throws -> xpc_object_t {
  switch path {
  case .root:
    return try XPCEncoder.standard.encode(payload)
  case .keyedDefaultSuper:
    let wrapper = try XPCEncoder.standard.encode(
      KeyedDefaultSuperWrapper(payload: payload)
    )
    return try #require(xpc_dictionary_get_value(wrapper, XPCCodingKey.superKey.stringValue))
  case .keyedNamedSuper:
    let wrapper = try XPCEncoder.standard.encode(
      KeyedNamedSuperWrapper(payload: payload)
    )
    return try #require(
      xpc_dictionary_get_value(
        wrapper,
        ReferencingEncoderPathKey.payload.stringValue
      )
    )
  case .unkeyedSuper:
    let wrapper = try XPCEncoder.standard.encode(
      UnkeyedSuperWrapper(payload: payload)
    )
    return xpc_array_get_value(wrapper, 0)
  }
}

// MARK: - Repeated Container Payloads

private struct RepeatedKeyedPayload: Codable, Equatable {
  let first: Int
  let second: Int

  private enum CodingKeys: String, CodingKey {
    case first
    case second
  }

  func encode(to encoder: any Encoder) throws {
    var firstContainer = encoder.container(keyedBy: CodingKeys.self)
    try firstContainer.encode(first, forKey: .first)

    var secondContainer = encoder.container(keyedBy: CodingKeys.self)
    try secondContainer.encode(second, forKey: .second)
  }
}

private struct RepeatedUnkeyedPayload: Codable, Equatable {
  let first: Int
  let second: Int

  func encode(to encoder: any Encoder) throws {
    var firstContainer = encoder.unkeyedContainer()
    try firstContainer.encode(first)

    var secondContainer = encoder.unkeyedContainer()
    try secondContainer.encode(second)
  }

  init(first: Int, second: Int) {
    self.first = first
    self.second = second
  }

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    self.first = try container.decode(Int.self)
    self.second = try container.decode(Int.self)
  }
}

private struct RepeatedSingleValueCompletionProbe: Encodable {
  let first: Int
  let second: Int

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(first)

    do {
      try container.encode(second)
      throw RepeatedSingleValueCompletionError.secondCompletionSucceeded
    } catch is EncodingError {
      return
    }
  }
}

private enum RepeatedSingleValueCompletionError: Error {
  case secondCompletionSucceeded
}

private struct KeyedThenUnkeyedTransitionProbe: Encodable {
  func encode(to encoder: any Encoder) throws {
    _ = encoder.container(keyedBy: ReferencingEncoderPathKey.self)
    _ = encoder.unkeyedContainer()
  }
}

private struct UnkeyedThenKeyedTransitionProbe: Encodable {
  func encode(to encoder: any Encoder) throws {
    _ = encoder.unkeyedContainer()
    _ = encoder.container(keyedBy: ReferencingEncoderPathKey.self)
  }
}

// MARK: - State Machine Parity

private func makeRootEncoder() -> _XPCEncoder {
  _XPCEncoder(
    stringKeyStrategy: .standard,
    stringValueStrategy: .standard
  )
}

private func makeReferencingEncoder(
  destination: ReferencingEncoderDestination
) -> _XPCEncoder {
  switch destination {
  case .array:
    let parent = xpc_array_create_empty()
    xpc_array_append_value(parent, xpc_null_create())
    return _XPCArrayReferencingEncoder(
      stringKeyStrategy: .standard,
      stringValueStrategy: .standard,
      codingPath: [ReferencingEncoderPathKey.payload],
      userInfo: [:],
      index: 0,
      array: parent
    )
  case .dictionary:
    return _XPCDictionaryReferencingEncoder(
      stringKeyStrategy: .standard,
      stringValueStrategy: .standard,
      codingPath: [ReferencingEncoderPathKey.payload],
      userInfo: [:],
      codingKey: ReferencingEncoderPathKey.payload,
      dictionary: xpc_dictionary_create_empty()
    )
  }
}

private func establishContainer(
  _ containerKind: _XPCEncoder.ContainerKind,
  on encoder: _XPCEncoder
) throws {
  switch containerKind {
  case .keyed:
    _ = encoder.container(keyedBy: ReferencingEncoderPathKey.self)
  case .unkeyed:
    _ = encoder.unkeyedContainer()
  case .pendingSingleValue:
    _ = encoder.singleValueContainer()
  case .completedSingleValue:
    var container = encoder.singleValueContainer()
    try container.encode(17)
  }
}

private enum DispositionSignature: Equatable {
  case create
  case `continue`
  case singleValueBlocked
  case switchBlocked(
    current: _XPCEncoder.ContainerKind,
    requested: _XPCEncoder.ContainerKind
  )
}

private func dispositionSignature(
  _ disposition: _XPCEncoder.ContainerRequestDisposition
) -> DispositionSignature {
  switch disposition {
  case .proceedWithContainerCreation:
    .create
  case .continueExistingContainer:
    .continue
  case .unableToContinueSingleValueContainer:
    .singleValueBlocked
  case .unableToSwitchContainerKind(let current, let requested):
    .switchBlocked(
      current: current,
      requested: requested
    )
  }
}
