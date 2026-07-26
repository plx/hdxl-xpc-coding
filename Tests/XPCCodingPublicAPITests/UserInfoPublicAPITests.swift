import Foundation
import Testing
import XPCCoding

@Suite("Black-box userInfo")
struct UserInfoPublicAPITests {

  @Test
  func `encoder user info reaches every recursive coder shape`() throws {
    let marker = "same-operation-marker"
    let transientRecorder = PublicUserInfoRecorder()
    let encoder = XPCEncoder()
    encoder.userInfo[PublicUserInfoKeys.marker] = marker
    encoder.userInfo[PublicUserInfoKeys.reference] = transientRecorder

    let transientObject = try encoder.withTransientEncoder { transientEncoder in
      transientRecorder.observe(
        "encode.transient",
        marker: marker,
        userInfo: transientEncoder.userInfo
      )
      var container = transientEncoder.singleValueContainer()
      try container.encode(29)
    }
    #expect(try XPCDecoder().decode(Int.self, from: transientObject) == 29)
    try transientRecorder.requireEvents(["encode.transient"])

    let encodingRecorder = PublicUserInfoRecorder()
    encoder.userInfo[PublicUserInfoKeys.reference] = encodingRecorder
    _ = try encoder.encode(
      PublicUserInfoShapePayload(
        marker: marker,
        recorder: encodingRecorder
      )
    )
    try encodingRecorder.requireEvents(
      PublicUserInfoShapePayload.encodingEvents
    )
  }

  @Test
  func `decoder user info reaches every recursive coder shape`() throws {
    let marker = "same-operation-marker"
    let fixtureRecorder = PublicUserInfoRecorder()
    let object = try XPCEncoder().encode(
      PublicUserInfoShapePayload(
        marker: marker,
        recorder: fixtureRecorder,
        enforceEncodingEvents: false
      )
    )
    #expect(fixtureRecorder.events.isEmpty)

    let decodingRecorder = PublicUserInfoRecorder()
    let decoder = XPCDecoder()
    decoder.userInfo[PublicUserInfoKeys.marker] = marker
    decoder.userInfo[PublicUserInfoKeys.reference] = decodingRecorder

    let decoded = try decoder.decode(
      PublicUserInfoShapePayload.self,
      from: object
    )

    #expect(decoded.marker == marker)
    #expect(decoded.recorder === decodingRecorder)
    try decodingRecorder.requireEvents(
      PublicUserInfoShapePayload.decodingEvents
    )
  }

  @Test
  func `facades snapshot independent operations without serializing user info`() throws {
    let encoder = XPCEncoder()
    encoder.userInfo[PublicUserInfoKeys.marker] = "first"
    let firstObject = try encoder.encode(
      PublicUserInfoEcho(expectedMarker: "first")
    )

    encoder.userInfo[PublicUserInfoKeys.marker] = "second"
    let secondObject = try encoder.encode(
      PublicUserInfoEcho(expectedMarker: "second")
    )

    let decoder = XPCDecoder()
    decoder.userInfo[PublicUserInfoKeys.marker] = "first"
    #expect(
      try decoder.decode(PublicUserInfoEcho.self, from: firstObject).expectedMarker
        == "first"
    )

    decoder.userInfo[PublicUserInfoKeys.marker] = "second"
    #expect(
      try decoder.decode(PublicUserInfoEcho.self, from: secondObject).expectedMarker
        == "second"
    )

    let reference = PublicUserInfoRecorder()
    encoder.userInfo = [PublicUserInfoKeys.reference: reference]
    let primitiveObject = try encoder.encode(29)
    #expect(try XPCDecoder().decode(Int.self, from: primitiveObject) == 29)

    let codec = XPCCodec(
      configuration: .init(
        stringKeyStrategy: .percentEscape,
        stringValueStrategy: .percentEscape
      )
    )
    let firstFactoryEncoder = codec.makeEncoder()
    firstFactoryEncoder.userInfo[PublicUserInfoKeys.marker] = "factory"
    #expect(codec.makeEncoder().userInfo.isEmpty)

    let firstFactoryDecoder = codec.makeDecoder()
    firstFactoryDecoder.userInfo[PublicUserInfoKeys.marker] = "factory"
    #expect(codec.makeDecoder().userInfo.isEmpty)
  }

}

// MARK: - Complete Shape Fixture

private struct PublicUserInfoShapePayload: Codable {
  static let placements = [
    "keyed-child",
    "unkeyed-child",
    "single-value-child",
    "nested-keyed-child",
    "nested-unkeyed-child",
    "keyed-default-super",
    "keyed-named-super",
    "unkeyed-super",
  ]

  static let encodingEvents = Set(
    ["encode.root"] + placements.map { "encode.\($0)" }
  )

  static let decodingEvents = Set(
    ["decode.root"] + placements.map { "decode.\($0)" }
  )

  let marker: String
  let recorder: PublicUserInfoRecorder
  let enforceEncodingEvents: Bool

  private enum CodingKeys: String, CodingKey {
    case keyedChild
    case unkeyedChild
    case singleValueChild
    case nestedKeyedChild
    case nestedUnkeyedChild
    case keyedNamedSuper
    case unkeyedSuper
  }

  private enum NestedKeys: String, CodingKey {
    case value
  }

  func encode(to encoder: any Encoder) throws {
    recorder.observe(
      "encode.root",
      marker: marker,
      userInfo: encoder.userInfo
    )

    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(
      leaf(placement: "keyed-child"),
      forKey: .keyedChild
    )
    try container.encode(
      PublicUserInfoUnkeyedWrapper(
        leaf: leaf(placement: "unkeyed-child")
      ),
      forKey: .unkeyedChild
    )
    try container.encode(
      PublicUserInfoSingleValueWrapper(
        leaf: leaf(placement: "single-value-child")
      ),
      forKey: .singleValueChild
    )

    var nestedKeyedContainer = container.nestedContainer(
      keyedBy: NestedKeys.self,
      forKey: .nestedKeyedChild
    )
    try nestedKeyedContainer.encode(
      leaf(placement: "nested-keyed-child"),
      forKey: .value
    )

    var nestedUnkeyedContainer = container.nestedUnkeyedContainer(
      forKey: .nestedUnkeyedChild
    )
    try nestedUnkeyedContainer.encode(
      leaf(placement: "nested-unkeyed-child")
    )

    let defaultSuperEncoder = container.superEncoder()
    try leaf(placement: "keyed-default-super").encode(
      to: defaultSuperEncoder
    )

    let namedSuperEncoder = container.superEncoder(
      forKey: .keyedNamedSuper
    )
    try leaf(placement: "keyed-named-super").encode(
      to: namedSuperEncoder
    )

    try container.encode(
      PublicUserInfoUnkeyedSuperWrapper(
        leaf: leaf(placement: "unkeyed-super")
      ),
      forKey: .unkeyedSuper
    )

    if enforceEncodingEvents {
      try recorder.requireEvents(Self.encodingEvents)
    }
  }

  init(
    marker: String,
    recorder: PublicUserInfoRecorder,
    enforceEncodingEvents: Bool = true
  ) {
    self.marker = marker
    self.recorder = recorder
    self.enforceEncodingEvents = enforceEncodingEvents
  }

  init(from decoder: any Decoder) throws {
    guard
      let marker = decoder.userInfo[PublicUserInfoKeys.marker] as? String,
      let recorder = decoder.userInfo[PublicUserInfoKeys.reference]
        as? PublicUserInfoRecorder
    else {
      throw PublicUserInfoTestError.missingRootUserInfo
    }

    recorder.observe(
      "decode.root",
      marker: marker,
      userInfo: decoder.userInfo
    )

    let container = try decoder.container(keyedBy: CodingKeys.self)
    var leaves = [
      try container.decode(
        PublicUserInfoLeaf.self,
        forKey: .keyedChild
      ),
      try container.decode(
        PublicUserInfoUnkeyedWrapper.self,
        forKey: .unkeyedChild
      ).leaf,
      try container.decode(
        PublicUserInfoSingleValueWrapper.self,
        forKey: .singleValueChild
      ).leaf,
    ]

    let nestedKeyedContainer = try container.nestedContainer(
      keyedBy: NestedKeys.self,
      forKey: .nestedKeyedChild
    )
    leaves.append(
      try nestedKeyedContainer.decode(
        PublicUserInfoLeaf.self,
        forKey: .value
      )
    )

    var nestedUnkeyedContainer = try container.nestedUnkeyedContainer(
      forKey: .nestedUnkeyedChild
    )
    leaves.append(
      try nestedUnkeyedContainer.decode(PublicUserInfoLeaf.self)
    )

    leaves.append(
      try PublicUserInfoLeaf(from: container.superDecoder())
    )
    leaves.append(
      try PublicUserInfoLeaf(
        from: container.superDecoder(forKey: .keyedNamedSuper)
      )
    )
    leaves.append(
      try container.decode(
        PublicUserInfoUnkeyedSuperWrapper.self,
        forKey: .unkeyedSuper
      ).leaf
    )

    guard leaves.allSatisfy({ $0.marker == marker }) else {
      throw PublicUserInfoTestError.incorrectMarker
    }
    try recorder.requireEvents(Self.decodingEvents)

    self.marker = marker
    self.recorder = recorder
    self.enforceEncodingEvents = true
  }

  private func leaf(placement: String) -> PublicUserInfoLeaf {
    PublicUserInfoLeaf(
      marker: marker,
      placement: placement,
      recorder: recorder
    )
  }
}

private struct PublicUserInfoLeaf: Codable {
  let marker: String
  let placement: String
  let recorder: PublicUserInfoRecorder?

  private enum CodingKeys: String, CodingKey {
    case marker
    case placement
  }

  init(
    marker: String,
    placement: String,
    recorder: PublicUserInfoRecorder
  ) {
    self.marker = marker
    self.placement = placement
    self.recorder = recorder
  }

  func encode(to encoder: any Encoder) throws {
    recorder?.observe(
      "encode.\(placement)",
      marker: marker,
      userInfo: encoder.userInfo
    )
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(marker, forKey: .marker)
    try container.encode(placement, forKey: .placement)
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    marker = try container.decode(String.self, forKey: .marker)
    placement = try container.decode(String.self, forKey: .placement)
    recorder =
      decoder.userInfo[PublicUserInfoKeys.reference]
      as? PublicUserInfoRecorder
    recorder?.observe(
      "decode.\(placement)",
      marker: marker,
      userInfo: decoder.userInfo
    )
  }
}

private struct PublicUserInfoUnkeyedWrapper: Codable {
  let leaf: PublicUserInfoLeaf

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(leaf)
  }

  init(leaf: PublicUserInfoLeaf) {
    self.leaf = leaf
  }

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    leaf = try container.decode(PublicUserInfoLeaf.self)
  }
}

private struct PublicUserInfoSingleValueWrapper: Codable {
  let leaf: PublicUserInfoLeaf

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(leaf)
  }

  init(leaf: PublicUserInfoLeaf) {
    self.leaf = leaf
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    leaf = try container.decode(PublicUserInfoLeaf.self)
  }
}

private struct PublicUserInfoUnkeyedSuperWrapper: Codable {
  let leaf: PublicUserInfoLeaf

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    try leaf.encode(to: container.superEncoder())
  }

  init(leaf: PublicUserInfoLeaf) {
    self.leaf = leaf
  }

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    leaf = try PublicUserInfoLeaf(from: container.superDecoder())
  }
}

// MARK: - Snapshot Fixture

private struct PublicUserInfoEcho: Codable {
  let expectedMarker: String

  func encode(to encoder: any Encoder) throws {
    guard
      encoder.userInfo[PublicUserInfoKeys.marker] as? String
        == expectedMarker
    else {
      throw PublicUserInfoTestError.incorrectMarker
    }
    var container = encoder.singleValueContainer()
    try container.encode(expectedMarker)
  }

  init(expectedMarker: String) {
    self.expectedMarker = expectedMarker
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let encodedMarker = try container.decode(String.self)
    guard
      decoder.userInfo[PublicUserInfoKeys.marker] as? String
        == encodedMarker
    else {
      throw PublicUserInfoTestError.incorrectMarker
    }
    expectedMarker = encodedMarker
  }
}

// MARK: - User-Info Support

private enum PublicUserInfoKeys {
  static let marker = makeUserInfoKey(
    "com.hdxl.xpc-coding.tests.user-info.marker"
  )
  static let reference = makeUserInfoKey(
    "com.hdxl.xpc-coding.tests.user-info.reference"
  )
}

private final class PublicUserInfoRecorder {
  private(set) var events: Set<String> = []

  func observe(
    _ event: String,
    marker: String,
    userInfo: [CodingUserInfoKey: Any]
  ) {
    guard
      userInfo[PublicUserInfoKeys.marker] as? String == marker,
      let reference = userInfo[PublicUserInfoKeys.reference]
        as? PublicUserInfoRecorder,
      reference === self
    else {
      return
    }
    events.insert(event)
  }

  func requireEvents(_ expectedEvents: Set<String>) throws {
    guard events == expectedEvents else {
      throw PublicUserInfoTestError.incorrectEvents(
        expected: expectedEvents,
        actual: events
      )
    }
  }
}

private enum PublicUserInfoTestError: Error {
  case incorrectEvents(
    expected: Set<String>,
    actual: Set<String>
  )
  case incorrectMarker
  case missingRootUserInfo
}

private func makeUserInfoKey(_ rawValue: String) -> CodingUserInfoKey {
  guard let key = CodingUserInfoKey(rawValue: rawValue) else {
    preconditionFailure("Unable to construct a CodingUserInfoKey.")
  }
  return key
}
