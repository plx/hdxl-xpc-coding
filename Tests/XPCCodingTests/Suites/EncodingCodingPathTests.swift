import Testing
@testable import XPCCoding

@Suite("Encoding Coding Paths")
struct EncodingCodingPathTests {

  @Test
  func `keyed nested containers retain complete creation paths`() throws {
    let recorder = EncodingPathRecorder()

    _ = try XPCEncoder.standard.encode(
      KeyedNestedPathProbe(recorder: recorder)
    )

    #expect(recorder["keyed-container"] == ["keyed"])
    #expect(recorder["keyed-leaf.encoder"] == ["keyed", "leaf"])
    #expect(recorder["keyed-leaf.single-value"] == ["keyed", "leaf"])
    #expect(recorder["unkeyed-container"] == ["unkeyed"])
    #expect(recorder["unkeyed-leaf.encoder"] == ["unkeyed", "0"])
    #expect(recorder["unkeyed-leaf.single-value"] == ["unkeyed", "0"])
  }

  @Test
  func `unkeyed nested containers retain complete creation paths`() throws {
    let recorder = EncodingPathRecorder()

    _ = try XPCEncoder.standard.encode(
      UnkeyedNestedPathProbe(recorder: recorder)
    )

    #expect(recorder["keyed-container"] == ["0"])
    #expect(recorder["keyed-leaf.encoder"] == ["0", "leaf"])
    #expect(recorder["keyed-leaf.single-value"] == ["0", "leaf"])
    #expect(recorder["unkeyed-container"] == ["1"])
    #expect(recorder["unkeyed-leaf.encoder"] == ["1", "0"])
    #expect(recorder["unkeyed-leaf.single-value"] == ["1", "0"])
  }

  @Test
  func `retained sibling containers remain path-independent`() throws {
    let recorder = EncodingPathRecorder()

    _ = try XPCEncoder.standard.encode(
      RetainedSiblingPathProbe(recorder: recorder)
    )

    #expect(recorder["first-container"] == ["first"])
    #expect(recorder["second-container"] == ["second"])
    #expect(recorder["first-leaf.encoder"] == ["first", "leaf"])
    #expect(recorder["second-leaf.encoder"] == ["second", "leaf"])
  }

  @Test
  func `referencing encoders preserve keyed and unkeyed insertion paths`() throws {
    let recorder = EncodingPathRecorder()

    _ = try XPCEncoder.standard.encode(
      KeyedSuperEncoderPathProbe(recorder: recorder)
    )
    _ = try XPCEncoder.standard.encode(
      UnkeyedSuperEncoderPathProbe(recorder: recorder)
    )

    #expect(recorder["keyed-super.encoder"] == ["outer", "namedSuper"])
    #expect(recorder["keyed-super.single-value"] == ["outer", "namedSuper"])
    #expect(recorder["default-super.encoder"] == ["outer", "super"])
    #expect(recorder["default-super.single-value"] == ["outer", "super"])
    #expect(recorder["unkeyed-super.encoder"] == ["outer", "0"])
    #expect(recorder["unkeyed-super.single-value"] == ["outer", "0"])
  }

  @Test
  func `escaped nested container preserves complete user error path`() {
    expectInvalidValuePath(["outer", "leaf"]) {
      _ = try XPCEncoder.standard.encode(DeferredUserFailureProbe())
    }
  }

  @Test
  func `escaped nested container preserves complete codec error path`() {
    let encoder = XPCEncoder(
      stringKeyStrategy: .standard,
      stringValueStrategy: .throwOnDiscovery
    )

    expectInvalidValuePath(["outer", "leaf"]) {
      _ = try encoder.encode(DeferredCodecFailureProbe())
    }
  }

}

private final class EncodingPathRecorder {

  private var paths: [String: [String]] = [:]

  subscript(label: String) -> [String]? {
    paths[label]
  }

  func record(_ label: String, codingPath: [any CodingKey]) {
    paths[label] = codingPath.map(\.stringValue)
  }

}

private enum EncodingPathKey: String, CodingKey {
  case keyed
  case unkeyed
  case leaf
  case first
  case second
  case parentOperation
  case outer
  case namedSuper
}

private struct RecordingEncodingLeaf: Encodable {

  let label: String
  let recorder: EncodingPathRecorder

  func encode(to encoder: any Encoder) throws {
    recorder.record("\(label).encoder", codingPath: encoder.codingPath)
    var container = encoder.singleValueContainer()
    recorder.record("\(label).single-value", codingPath: container.codingPath)
    try container.encode(17)
  }

}

private struct KeyedNestedPathProbe: Encodable {

  let recorder: EncodingPathRecorder

  func encode(to encoder: any Encoder) throws {
    var root = encoder.container(keyedBy: EncodingPathKey.self)

    var keyed = root.nestedContainer(
      keyedBy: EncodingPathKey.self,
      forKey: .keyed
    )
    recorder.record("keyed-container", codingPath: keyed.codingPath)
    try keyed.encode(
      RecordingEncodingLeaf(label: "keyed-leaf", recorder: recorder),
      forKey: .leaf
    )

    var unkeyed = root.nestedUnkeyedContainer(forKey: .unkeyed)
    recorder.record("unkeyed-container", codingPath: unkeyed.codingPath)
    try unkeyed.encode(
      RecordingEncodingLeaf(label: "unkeyed-leaf", recorder: recorder)
    )
  }

}

private struct UnkeyedNestedPathProbe: Encodable {

  let recorder: EncodingPathRecorder

  func encode(to encoder: any Encoder) throws {
    var root = encoder.unkeyedContainer()

    var keyed = root.nestedContainer(keyedBy: EncodingPathKey.self)
    recorder.record("keyed-container", codingPath: keyed.codingPath)
    try keyed.encode(
      RecordingEncodingLeaf(label: "keyed-leaf", recorder: recorder),
      forKey: .leaf
    )

    var unkeyed = root.nestedUnkeyedContainer()
    recorder.record("unkeyed-container", codingPath: unkeyed.codingPath)
    try unkeyed.encode(
      RecordingEncodingLeaf(label: "unkeyed-leaf", recorder: recorder)
    )
  }

}

private struct RetainedSiblingPathProbe: Encodable {

  let recorder: EncodingPathRecorder

  func encode(to encoder: any Encoder) throws {
    var root = encoder.container(keyedBy: EncodingPathKey.self)
    var first = root.nestedContainer(
      keyedBy: EncodingPathKey.self,
      forKey: .first
    )
    var second = root.nestedContainer(
      keyedBy: EncodingPathKey.self,
      forKey: .second
    )

    try root.encode(17, forKey: .parentOperation)
    recorder.record("first-container", codingPath: first.codingPath)
    recorder.record("second-container", codingPath: second.codingPath)

    try first.encode(
      RecordingEncodingLeaf(label: "first-leaf", recorder: recorder),
      forKey: .leaf
    )
    try second.encode(
      RecordingEncodingLeaf(label: "second-leaf", recorder: recorder),
      forKey: .leaf
    )
  }

}

private struct KeyedSuperEncoderPathProbe: Encodable {

  let recorder: EncodingPathRecorder

  func encode(to encoder: any Encoder) throws {
    var root = encoder.container(keyedBy: EncodingPathKey.self)
    var container = root.nestedContainer(
      keyedBy: EncodingPathKey.self,
      forKey: .outer
    )
    try RecordingEncodingLeaf(
      label: "keyed-super",
      recorder: recorder
    ).encode(to: container.superEncoder(forKey: .namedSuper))
    try RecordingEncodingLeaf(
      label: "default-super",
      recorder: recorder
    ).encode(to: container.superEncoder())
  }

}

private struct UnkeyedSuperEncoderPathProbe: Encodable {

  let recorder: EncodingPathRecorder

  func encode(to encoder: any Encoder) throws {
    var root = encoder.container(keyedBy: EncodingPathKey.self)
    var container = root.nestedUnkeyedContainer(forKey: .outer)
    try RecordingEncodingLeaf(
      label: "unkeyed-super",
      recorder: recorder
    ).encode(to: container.superEncoder())
  }

}

private struct DeferredUserFailureProbe: Encodable {

  func encode(to encoder: any Encoder) throws {
    var root = encoder.container(keyedBy: EncodingPathKey.self)
    var nested = root.nestedContainer(
      keyedBy: EncodingPathKey.self,
      forKey: .outer
    )
    try nested.encode(UserFailureLeaf(), forKey: .leaf)
  }

}

private struct UserFailureLeaf: Encodable {

  func encode(to encoder: any Encoder) throws {
    throw EncodingError.invalidValue(
      17,
      EncodingError.Context(
        codingPath: encoder.codingPath,
        debugDescription: "Intentional user failure."
      )
    )
  }

}

private struct DeferredCodecFailureProbe: Encodable {

  func encode(to encoder: any Encoder) throws {
    var root = encoder.container(keyedBy: EncodingPathKey.self)
    var nested = root.nestedContainer(
      keyedBy: EncodingPathKey.self,
      forKey: .outer
    )
    try nested.encode(CodecFailureLeaf(), forKey: .leaf)
  }

}

private struct CodecFailureLeaf: Encodable {

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode("embedded\u{0}null")
  }

}

private func expectInvalidValuePath(
  _ expectedPath: [String],
  operation: () throws -> Void
) {
  do {
    try operation()
    Issue.record("Expected EncodingError.invalidValue.")
  } catch let EncodingError.invalidValue(_, context) {
    #expect(context.codingPath.map(\.stringValue) == expectedPath)
  } catch {
    Issue.record("Expected EncodingError.invalidValue, received \(error).")
  }
}
