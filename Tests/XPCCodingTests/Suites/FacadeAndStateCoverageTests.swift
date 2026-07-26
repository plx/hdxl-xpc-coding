import Testing
import XPC
@testable import XPCCoding

// MARK: - Facade And State Coverage Tests

@Suite("Facade And State Coverage")
struct FacadeAndStateCoverageTests {

  @Test
  func `manual facade descriptions and accessors expose configuration`() throws {
    // These are intentionally explicit because the facade types are public API:
    // their descriptions and configuration accessors should report the same
    // strategies that are used to build fresh encoder and decoder facades.
    let configuration = XPCCodec.Configuration(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    let codec = XPCCodec(configuration: configuration)
    let encoder = codec.makeEncoder()
    let decoder = codec.makeDecoder()

    #expect(codec.stringKeyStrategy == configuration.stringKeyStrategy)
    #expect(codec.stringValueStrategy == configuration.stringValueStrategy)
    #expect(encoder.description.contains("string-keys"))
    #expect(encoder.debugDescription.contains("XPCEncoder"))
    #expect(decoder.description.contains("string-keys"))
    #expect(decoder.debugDescription.contains("XPCDecoder"))
  }

  @Test
  func `generated facade descriptions and accessors expose configuration`() throws {
    for configuration in XPCCodec.Configuration.allCases {
      let codec = XPCCodec(configuration: configuration)
      let encoder = codec.makeEncoder()
      let decoder = codec.makeDecoder()

      #expect(codec.stringKeyStrategy == configuration.stringKeyStrategy)
      #expect(codec.stringValueStrategy == configuration.stringValueStrategy)
      #expect(encoder.description.contains("\(configuration.stringKeyStrategy.encodingStrategy)"))
      #expect(encoder.debugDescription.contains("\(configuration.stringValueStrategy.encodingStrategy)"))
      #expect(decoder.description.contains("\(configuration.stringKeyStrategy.decodingStrategy)"))
      #expect(decoder.debugDescription.contains("\(configuration.stringValueStrategy.decodingStrategy)"))
    }
  }

  @Test
  func `manual transient encoder succeeds and reports no encoding`() throws {
    // `withTransientEncoder` is the public escape hatch for callers that need to
    // drive the underlying Encoder manually. This covers both the success path
    // and the no-container error when the closure does not encode anything.
    let encoded = try XPCEncoder.standard.withTransientEncoder { encoder in
      _ = encoder.userInfo
      var container = encoder.singleValueContainer()
      try container.encode(123)
    }
    let decoded = try XPCDecoder.standard.decode(Int.self, from: encoded)
    #expect(decoded == 123)

    #expect(throws: TransientEncoderError.self) {
      try XPCEncoder.standard.withTransientEncoder { encoder in
        _ = encoder.userInfo
      }
    }
  }

  @Test
  func `generated transient encoder succeeds and reports no encoding`() throws {
    for value in generatedTransientValues(count: 32) {
      let encoded = try XPCEncoder.standard.withTransientEncoder { encoder in
        _ = encoder.userInfo
        var container = encoder.singleValueContainer()
        try container.encode(value)
      }
      let decoded = try XPCDecoder.standard.decode(Int.self, from: encoded)
      #expect(decoded == value)

      #expect(throws: TransientEncoderError.self) {
        try XPCEncoder.standard.withTransientEncoder { encoder in
          _ = encoder.userInfo
        }
      }
    }
  }

  @Test
  func `manual no-op encodable is rejected`() throws {
    // A custom Encodable that returns without requesting a container should not
    // produce an empty or null XPC object. The encoder must surface that as an
    // invalid-value encoding error.
    #expect(throws: EncodingError.self) {
      try _XPCEncoder.encode(
        NoOpEncodable(id: 1),
        stringKeyStrategy: .standard,
        stringValueStrategy: .standard
      )
    }
  }

  @Test
  func `generated no-op encodables are rejected`() throws {
    for value in generatedNoOpEncodables(count: 32) {
      #expect(throws: EncodingError.self) {
        try _XPCEncoder.encode(
          value,
          stringKeyStrategy: .standard,
          stringValueStrategy: .standard
        )
      }
    }
  }

  @Test
  func `manual encoder state descriptions and dispositions are coherent`() throws {
    // This exercises the non-trapping state-machine branches directly. The
    // trap branches still need a subprocess-style harness before they can be
    // safely counted toward coverage.
    let dictionary = xpc_dictionary_create(nil, nil, 0)
    let array = xpc_array_create(nil, 0)
    let singleValue = xpc_int64_create(5)

    let states: [_XPCEncoder.ContainerState] = [
      .noContainerYet,
      .keyed(dictionary),
      .unkeyed(array),
      .pendingSingleValue,
      .completedSingleValue(singleValue)
    ]

    #expect(states[0].canBeginContainer)
    #expect(!states[1].canBeginContainer)
    #expect(states[0].containerObject == nil)
    #expect(states[3].containerObject == nil)
    #expect(states[1].containerObject != nil)
    #expect(states[2].containerObject != nil)
    #expect(states[4].containerObject != nil)
    #expect(states[0].containerKind == nil)
    #expect(states[1].containerKind == .keyed)
    #expect(states[2].containerKind == .unkeyed)
    #expect(states[3].containerKind == .pendingSingleValue)
    #expect(states[4].containerKind == .completedSingleValue)

    for state in states {
      #expect(!state.description.isEmpty)
      #expect(!state.debugDescription.isEmpty)
    }

    #expect(_XPCEncoder.ContainerKind.keyed.description == "keyed")
    #expect(_XPCEncoder.ContainerKind.unkeyed.description == "unkeyed")
    #expect(_XPCEncoder.ContainerKind.pendingSingleValue.description.contains("pending"))
    #expect(_XPCEncoder.ContainerKind.completedSingleValue.description.contains("complete"))
    for kind in _XPCEncoder.ContainerKind.allCases {
      #expect(kind.debugDescription.contains("\(type(of: kind))"))
    }

    let encoder = _XPCEncoder(
      stringKeyStrategy: .standard,
      stringValueStrategy: .standard
    )
    let createDisposition = encoder.containerRequestDisposition(containerKind: .keyed)
    #expect(dispositionName(createDisposition) == "create")

    encoder.topLevelContainerState = .pendingSingleValue
    let pendingSingleValueDisposition = encoder.containerRequestDisposition(containerKind: .keyed)
    #expect(dispositionName(pendingSingleValueDisposition) == "singleValueBlocked")

    encoder.topLevelContainerState = .completedSingleValue(singleValue)
    let completedSingleValueDisposition = encoder.containerRequestDisposition(containerKind: .unkeyed)
    #expect(dispositionName(completedSingleValueDisposition) == "singleValueBlocked")

    encoder.topLevelContainerState = .keyed(dictionary)
    let continueKeyedDisposition = encoder.containerRequestDisposition(containerKind: .keyed)
    let switchFromKeyedDisposition = encoder.containerRequestDisposition(containerKind: .unkeyed)
    let singleValueFromKeyedDisposition = encoder.containerRequestDisposition(containerKind: .pendingSingleValue)
    #expect(dispositionName(continueKeyedDisposition) == "continue")
    #expect(dispositionName(switchFromKeyedDisposition) == "switchBlocked")
    // A kind switch must report the *current* container kind first and the *requested* one
    // second. A regression that swaps or mislabels them still lands in `switchBlocked`, so the
    // category check above is not enough — assert the associated values explicitly.
    #expect(switchKinds(switchFromKeyedDisposition)?.current == .keyed)
    #expect(switchKinds(switchFromKeyedDisposition)?.requested == .unkeyed)
    // Requesting a single-value container while a keyed container exists is a kind switch whose
    // *requested* kind is `.pendingSingleValue` (not a single-value continuation, and not the
    // active container's own kind).
    #expect(dispositionName(singleValueFromKeyedDisposition) == "switchBlocked")
    #expect(switchKinds(singleValueFromKeyedDisposition)?.current == .keyed)
    #expect(switchKinds(singleValueFromKeyedDisposition)?.requested == .pendingSingleValue)

    encoder.topLevelContainerState = .unkeyed(array)
    let continueUnkeyedDisposition = encoder.containerRequestDisposition(containerKind: .unkeyed)
    let switchFromUnkeyedDisposition = encoder.containerRequestDisposition(containerKind: .keyed)
    let singleValueFromUnkeyedDisposition = encoder.containerRequestDisposition(containerKind: .pendingSingleValue)
    #expect(dispositionName(continueUnkeyedDisposition) == "continue")
    #expect(dispositionName(switchFromUnkeyedDisposition) == "switchBlocked")
    #expect(switchKinds(switchFromUnkeyedDisposition)?.current == .unkeyed)
    #expect(switchKinds(switchFromUnkeyedDisposition)?.requested == .keyed)
    #expect(dispositionName(singleValueFromUnkeyedDisposition) == "switchBlocked")
    #expect(switchKinds(singleValueFromUnkeyedDisposition)?.current == .unkeyed)
    #expect(switchKinds(singleValueFromUnkeyedDisposition)?.requested == .pendingSingleValue)
  }

  @Test
  func `generated encoder state dispositions are coherent`() throws {
    for probe in generatedStateProbes(count: 32) {
      let encoder = _XPCEncoder(
        stringKeyStrategy: .standard,
        stringValueStrategy: .standard
      )
      encoder.topLevelContainerState = probe.state

      let disposition = encoder.containerRequestDisposition(containerKind: probe.requestedKind)
      #expect(
        dispositionName(disposition) == probe.expectedDisposition
      )
      #expect(probe.state.canBeginContainer == probe.expectedCanBeginContainer)
      #expect(!probe.state.description.isEmpty)
      #expect(!probe.state.debugDescription.isEmpty)
    }
  }

  @Test
  func `manual continuing an unkeyed encoder reuses the container`() throws {
    // The top-level encoder permits repeated requests for the same unkeyed
    // container. This covers the safe continuation branch without crossing
    // into the precondition-failure paths for switching container kinds.
    let encoder = _XPCEncoder(
      stringKeyStrategy: .standard,
      stringValueStrategy: .standard
    )
    _ = encoder.unkeyedContainer()
    var continued = encoder.unkeyedContainer()
    try continued.encode(7)

    let object = try #require(encoder.topLevelContainer)
    let decoded = try XPCDecoder.standard.decode([Int].self, from: object)
    #expect(decoded == [7])
  }

}

// MARK: - Fixtures

private struct NoOpEncodable: Encodable {
  let id: Int

  func encode(to encoder: any Encoder) throws {
    _ = id
  }
}

private struct StateProbe {
  let state: _XPCEncoder.ContainerState
  let requestedKind: _XPCEncoder.ContainerKind
  let expectedDisposition: String
  let expectedCanBeginContainer: Bool
}

private func dispositionName(_ disposition: _XPCEncoder.ContainerRequestDisposition) -> String {
  switch disposition {
  case .proceedWithContainerCreation:
    "create"
  case .continueExistingContainer:
    "continue"
  case .unableToContinueSingleValueContainer:
    "singleValueBlocked"
  case .unableToSwitchContainerKind:
    "switchBlocked"
  }
}

/// Surfaces the associated `(current, requested)` kinds of a `switchBlocked` disposition.
///
/// `dispositionName(_:)` deliberately collapses to the disposition *category*, so it cannot
/// distinguish a correctly-reported kind switch from one whose current/requested kinds are
/// swapped or mislabeled. This accessor lets the tests pin those associated values directly.
private func switchKinds(
  _ disposition: _XPCEncoder.ContainerRequestDisposition
) -> (current: _XPCEncoder.ContainerKind, requested: _XPCEncoder.ContainerKind)? {
  guard case .unableToSwitchContainerKind(let current, let requested) = disposition else {
    return nil
  }
  return (current, requested)
}

private struct FacadeSeededGenerator: RandomNumberGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state = state &* 1_103_515_245 &+ 12_345
    return state
  }
}

private func generatedTransientValues(count: Int) -> [Int] {
  var generator = FacadeSeededGenerator(state: 0xfaca_de00_5eed)
  return (0..<count).map { _ in
    Int(truncatingIfNeeded: generator.next())
  }
}

private func generatedNoOpEncodables(count: Int) -> [NoOpEncodable] {
  generatedTransientValues(count: count).map(NoOpEncodable.init(id:))
}

private func generatedStateProbes(count: Int) -> [StateProbe] {
  var generator = FacadeSeededGenerator(state: 0x57a7_e000_5eed)
  var result: [StateProbe] = []
  result.reserveCapacity(count)

  for _ in 0..<count {
    let selector = Int(generator.next() % 5)
    let requestedKind = _XPCEncoder.ContainerKind.allCases[
      Int(generator.next() % UInt64(_XPCEncoder.ContainerKind.allCases.count))
    ]
    let dictionary = xpc_dictionary_create(nil, nil, 0)
    let array = xpc_array_create(nil, 0)
    let value = xpc_int64_create(Int64(truncatingIfNeeded: generator.next()))

    let state: _XPCEncoder.ContainerState
    let expectedCanBeginContainer: Bool
    switch selector {
    case 0:
      state = .noContainerYet
      expectedCanBeginContainer = true
    case 1:
      state = .keyed(dictionary)
      expectedCanBeginContainer = false
    case 2:
      state = .unkeyed(array)
      expectedCanBeginContainer = false
    case 3:
      state = .pendingSingleValue
      expectedCanBeginContainer = false
    default:
      state = .completedSingleValue(value)
      expectedCanBeginContainer = false
    }

    result.append(
      StateProbe(
        state: state,
        requestedKind: requestedKind,
        expectedDisposition: expectedDispositionName(
          state: state,
          requestedKind: requestedKind
        ),
        expectedCanBeginContainer: expectedCanBeginContainer
      )
    )
  }

  return result
}

private func expectedDispositionName(
  state: _XPCEncoder.ContainerState,
  requestedKind: _XPCEncoder.ContainerKind
) -> String {
  switch (state, requestedKind) {
  case (.noContainerYet, _):
    "create"
  case (.pendingSingleValue, _), (.completedSingleValue, _):
    "singleValueBlocked"
  case (.keyed, .keyed), (.unkeyed, .unkeyed):
    "continue"
  case (.keyed, _), (.unkeyed, _):
    "switchBlocked"
  }
}
