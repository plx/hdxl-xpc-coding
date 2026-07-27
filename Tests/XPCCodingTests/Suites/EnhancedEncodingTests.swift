import Foundation
import Testing
import XPC
@testable import XPCCoding

// MARK: - Enhanced Encoding Tests

@Suite("Enhanced Encoding", .tags(.encoding))
struct EnhancedEncodingTests {

  @Test
  func `manual binary helper overloads preserve bytes through XPC`() throws {
    // These explicit cases exercise every public binary-data helper shape on
    // single-value, keyed, and unkeyed containers. They matter because the XPC
    // encoder has enhanced containers that should store the bytes directly as
    // `XPC_TYPE_DATA` instead of falling back through ordinary `Data` encoding.
    let bytes: [UInt8] = [0, 1, 2, 3, 5, 8, 13, 21, 0, 255]

    for mode in BinaryEncodingMode.allCases {
      let expectedData = mode.expectedData(from: bytes)

      let singleValueObject = try XPCEncoder.standard.encode(
        SingleValueBinaryPayload(bytes: bytes, mode: mode)
      )
      verifyXPCType(singleValueObject, is: XPC_TYPE_DATA)
      let singleValueData = try extractData(fromXPCData: singleValueObject)
      #expect(singleValueData == expectedData)

      let keyedObject = try XPCEncoder.standard.encode(
        KeyedBinaryPayload(bytes: bytes, mode: mode)
      )
      let keyedValue = try XPCDecoder.standard.decode(KeyedDataValue.self, from: keyedObject)
      #expect(keyedValue.data == expectedData)

      let unkeyedObject = try XPCEncoder.standard.encode(
        UnkeyedBinaryPayload(bytes: bytes, mode: mode)
      )
      let unkeyedValue = try XPCDecoder.standard.decode([Data].self, from: unkeyedObject)
      #expect(unkeyedValue == [expectedData])
    }
  }

  @Test
  func `manual binary helpers fall back to Data with non-XPC encoders`() throws {
    // The same helper APIs are public extensions on standard Swift encoding
    // containers, so they must remain correct when the encoder is not XPCCoding.
    // JSONEncoder gives us an explicit non-XPC path for the Data fallback code
    // used by the helpers and keyed shim types.
    let bytes: [UInt8] = [42, 43, 44, 45, 200, 201]

    for mode in BinaryEncodingMode.allCases {
      let expectedData = mode.expectedData(from: bytes)

      let singleValueJSON = try JSONEncoder().encode(
        SingleValueBinaryPayload(bytes: bytes, mode: mode)
      )
      let singleValueData = try JSONDecoder().decode(Data.self, from: singleValueJSON)
      #expect(singleValueData == expectedData)

      let keyedJSON = try JSONEncoder().encode(
        KeyedBinaryPayload(bytes: bytes, mode: mode)
      )
      let keyedValue = try JSONDecoder().decode(KeyedDataValue.self, from: keyedJSON)
      #expect(keyedValue.data == expectedData)

      let unkeyedJSON = try JSONEncoder().encode(
        UnkeyedBinaryPayload(bytes: bytes, mode: mode)
      )
      let unkeyedValue = try JSONDecoder().decode([Data].self, from: unkeyedJSON)
      #expect(unkeyedValue == [expectedData])
    }
  }

  @Test
  func `generated binary helper payloads preserve bytes`() throws {
    for bytes in generatedBytePayloads(count: 32, maximumLength: 96) {
      for mode in BinaryEncodingMode.allCases {
        let expectedData = mode.expectedData(from: bytes)

        let singleValueObject = try XPCEncoder.standard.encode(
          SingleValueBinaryPayload(bytes: bytes, mode: mode)
        )
        let singleValueData = try extractData(fromXPCData: singleValueObject)
        #expect(singleValueData == expectedData)

        let keyedObject = try XPCEncoder.standard.encode(
          KeyedBinaryPayload(bytes: bytes, mode: mode)
        )
        let keyedValue = try XPCDecoder.standard.decode(KeyedDataValue.self, from: keyedObject)
        #expect(keyedValue.data == expectedData)

        let unkeyedObject = try XPCEncoder.standard.encode(
          UnkeyedBinaryPayload(bytes: bytes, mode: mode)
        )
        let unkeyedValue = try XPCDecoder.standard.decode([Data].self, from: unkeyedObject)
        #expect(unkeyedValue == [expectedData])

        let singleValueJSON = try JSONEncoder().encode(
          SingleValueBinaryPayload(bytes: bytes, mode: mode)
        )
        let singleValueJSONData = try JSONDecoder().decode(Data.self, from: singleValueJSON)
        #expect(singleValueJSONData == expectedData)

        let keyedJSON = try JSONEncoder().encode(
          KeyedBinaryPayload(bytes: bytes, mode: mode)
        )
        let keyedJSONValue = try JSONDecoder().decode(KeyedDataValue.self, from: keyedJSON)
        #expect(keyedJSONValue.data == expectedData)

        let unkeyedJSON = try JSONEncoder().encode(
          UnkeyedBinaryPayload(bytes: bytes, mode: mode)
        )
        let unkeyedJSONValue = try JSONDecoder().decode([Data].self, from: unkeyedJSON)
        #expect(unkeyedJSONValue == [expectedData])
      }
    }
  }

  @Test
  func `manual inline array binary helper overloads preserve bytes`() throws {
    // InlineArray has dedicated public overloads that forward into the raw
    // buffer helpers. This fixed-size case proves the forwarding path works for
    // each container family rather than only for ordinary Array storage.
    let inlineArray: InlineArray<4, UInt8> = [3, 1, 4, 1]
    let expectedData = Data([3, 1, 4, 1])

    let singleValueObject = try XPCEncoder.standard.encode(
      SingleValueInlineArrayPayload(inlineArray: inlineArray)
    )
    #expect(try extractData(fromXPCData: singleValueObject) == expectedData)

    let keyedObject = try XPCEncoder.standard.encode(
      KeyedInlineArrayPayload(inlineArray: inlineArray)
    )
    let keyedValue = try XPCDecoder.standard.decode(KeyedDataValue.self, from: keyedObject)
    #expect(keyedValue.data == expectedData)

    let unkeyedObject = try XPCEncoder.standard.encode(
      UnkeyedInlineArrayPayload(inlineArray: inlineArray)
    )
    let unkeyedValue = try XPCDecoder.standard.decode([Data].self, from: unkeyedObject)
    #expect(unkeyedValue == [expectedData])
  }

  @Test
  func `generated inline array binary helper overloads preserve bytes`() throws {
    for probe in generatedInlineArrayPayloads() {
      let singleValueObject = try XPCEncoder.standard.encode(
        SingleValueInlineArrayPayload(inlineArray: probe.inlineArray)
      )
      #expect(try extractData(fromXPCData: singleValueObject) == probe.expectedData)

      let keyedObject = try XPCEncoder.standard.encode(
        KeyedInlineArrayPayload(inlineArray: probe.inlineArray)
      )
      let keyedValue = try XPCDecoder.standard.decode(KeyedDataValue.self, from: keyedObject)
      #expect(keyedValue.data == probe.expectedData)

      let unkeyedObject = try XPCEncoder.standard.encode(
        UnkeyedInlineArrayPayload(inlineArray: probe.inlineArray)
      )
      let unkeyedValue = try XPCDecoder.standard.decode([Data].self, from: unkeyedObject)
      #expect(unkeyedValue == [probe.expectedData])
    }
  }

  @Test
  func `manual element helper overloads preserve element order`() throws {
    // These explicit cases cover the element-buffer helpers separately from
    // raw binary data. They should behave like ordinary repeated `encode(_:)`
    // calls while avoiding per-call boilerplate for pointer-backed collections.
    let elements = [-7, -1, 0, 1, 8, 64, 1024]

    for mode in ElementEncodingMode.allCases {
      let expectedElements = mode.expectedElements(from: elements)

      let keyedObject = try XPCEncoder.standard.encode(
        KeyedElementPayload(elements: elements, mode: mode)
      )
      let keyedValue = try XPCDecoder.standard.decode(KeyedElementValue.self, from: keyedObject)
      #expect(keyedValue.elements == expectedElements)

      let unkeyedObject = try XPCEncoder.standard.encode(
        UnkeyedElementPayload(elements: elements, mode: mode)
      )
      let unkeyedValue = try XPCDecoder.standard.decode([Int].self, from: unkeyedObject)
      #expect(unkeyedValue == expectedElements)
    }
  }

  @Test
  func `generated element helper payloads preserve element order`() throws {
    for elements in generatedIntPayloads(count: 32, maximumLength: 64) {
      for mode in ElementEncodingMode.allCases {
        let expectedElements = mode.expectedElements(from: elements)

        let keyedObject = try XPCEncoder.standard.encode(
          KeyedElementPayload(elements: elements, mode: mode)
        )
        let keyedValue = try XPCDecoder.standard.decode(KeyedElementValue.self, from: keyedObject)
        #expect(keyedValue.elements == expectedElements)

        let unkeyedObject = try XPCEncoder.standard.encode(
          UnkeyedElementPayload(elements: elements, mode: mode)
        )
        let unkeyedValue = try XPCDecoder.standard.decode([Int].self, from: unkeyedObject)
        #expect(unkeyedValue == expectedElements)
      }
    }
  }

  @Test
  func `manual enhanced protocol defaults delegate to mutable pointer primitive`() throws {
    // The enhanced-container protocols provide default overloads in terms of
    // the mutable raw pointer primitive. This checks those defaults directly
    // with a recording container instead of relying on the concrete XPC encoder.
    let bytes: [UInt8] = [9, 8, 7, 6, 0, 5]
    let expectedData = Data(bytes)

    var singleValueContainer = RecordingEnhancedSingleValueContainer()
    try bytes.withUnsafeBytes {
      try singleValueContainer.directlyEncodeXPCData($0.baseAddress, count: $0.count)
    }
    #expect(singleValueContainer.recordedData == expectedData)

    try bytes.withUnsafeBytes {
      try singleValueContainer.directlyEncodeXPCData($0)
    }
    #expect(singleValueContainer.recordedData == expectedData)

    var mutableBytes = bytes
    try mutableBytes.withUnsafeMutableBytes {
      try singleValueContainer.directlyEncodeXPCData($0)
    }
    #expect(singleValueContainer.recordedData == expectedData)

    var unkeyedContainer = RecordingEnhancedUnkeyedContainer()
    try bytes.withUnsafeBytes {
      try unkeyedContainer.directlyEncodeXPCData($0.baseAddress, count: $0.count)
    }
    try bytes.withUnsafeBytes {
      try unkeyedContainer.directlyEncodeXPCData($0)
    }
    try mutableBytes.withUnsafeMutableBytes {
      try unkeyedContainer.directlyEncodeXPCData($0)
    }
    #expect(unkeyedContainer.recordedData == [expectedData, expectedData, expectedData])
  }

  @Test
  func `generated enhanced protocol defaults preserve arbitrary byte buffers`() throws {
    for bytes in generatedBytePayloads(count: 32, maximumLength: 96) {
      let expectedData = Data(bytes)

      var singleValueContainer = RecordingEnhancedSingleValueContainer()
      try bytes.withUnsafeBytes {
        try singleValueContainer.directlyEncodeXPCData($0.baseAddress, count: $0.count)
      }
      #expect(singleValueContainer.recordedData == expectedData)

      try bytes.withUnsafeBytes {
        try singleValueContainer.directlyEncodeXPCData($0)
      }
      #expect(singleValueContainer.recordedData == expectedData)

      var mutableBytes = bytes
      try mutableBytes.withUnsafeMutableBytes {
        try singleValueContainer.directlyEncodeXPCData($0)
      }
      #expect(singleValueContainer.recordedData == expectedData)

      var unkeyedContainer = RecordingEnhancedUnkeyedContainer()
      try bytes.withUnsafeBytes {
        try unkeyedContainer.directlyEncodeXPCData($0.baseAddress, count: $0.count)
      }
      try bytes.withUnsafeBytes {
        try unkeyedContainer.directlyEncodeXPCData($0)
      }
      try mutableBytes.withUnsafeMutableBytes {
        try unkeyedContainer.directlyEncodeXPCData($0)
      }
      #expect(unkeyedContainer.recordedData == [expectedData, expectedData, expectedData])
    }
  }

  @Test
  func `public wrappers write single-value struct mutations back`() throws {
    let bytes: [UInt8] = [0, 1, 2, 3, 5, 8, 13, 255]

    for invocation in BinaryWrapperInvocation.allCases {
      var container = RecordingEnhancedSingleValueContainer()

      try invocation.encode(
        bytes: bytes,
        into: &container
      )

      #expect(
        container.recordedData == invocation.expectedData(for: bytes),
        "Incorrect value-semantic result for \(invocation)."
      )
      #expect(
        container.directCallCount == 1,
        "Expected exactly one enhanced call for \(invocation)."
      )
    }
  }

  @Test
  func `public wrappers write unkeyed struct mutations back`() throws {
    let bytes: [UInt8] = [0, 1, 2, 3, 5, 8, 13, 255]

    for invocation in BinaryWrapperInvocation.allCases {
      var container = RecordingEnhancedUnkeyedContainer()

      try invocation.encode(
        bytes: bytes,
        into: &container
      )

      #expect(
        container.recordedData == [invocation.expectedData(for: bytes)],
        "Incorrect value-semantic result for \(invocation)."
      )
    }
  }

  @Test
  func `public wrappers preserve reference-semantic enhanced dispatch`() throws {
    let bytes: [UInt8] = [0, 1, 2, 3, 5, 8, 13, 255]

    for invocation in BinaryWrapperInvocation.allCases {
      var container = ReferenceRecordingEnhancedSingleValueContainer()

      try invocation.encode(
        bytes: bytes,
        into: &container
      )

      #expect(
        container.recordedData == invocation.expectedData(for: bytes),
        "Incorrect reference-semantic result for \(invocation)."
      )
      #expect(
        container.directCallCount == 1,
        "Expected exactly one enhanced call for \(invocation)."
      )
    }
  }

  @Test
  func `public wrappers validate before enhanced dispatch`() throws {
    let pointer: UnsafeRawPointer? = nil
    var singleValueContainer = RecordingEnhancedSingleValueContainer()
    var unkeyedContainer = RecordingEnhancedUnkeyedContainer()

    _ = try #require(throws: EncodingError.self) {
      try singleValueContainer.efficientlyEncodeBinaryData(
        pointer,
        count: 1
      )
    }
    _ = try #require(throws: EncodingError.self) {
      try unkeyedContainer.efficientlyEncodeBinaryData(
        pointer,
        count: 1
      )
    }

    #expect(singleValueContainer.directCallCount == 0)
    #expect(unkeyedContainer.recordedData.isEmpty)
  }

}

// MARK: - Binary Payloads

private enum BinaryCodingKeys: String, CodingKey {
  case data
  case elements
}

private enum BinaryEncodingMode: CaseIterable, Sendable, CustomStringConvertible {
  case rawPointer
  case mutableRawPointer
  case rawBuffer
  case mutableRawBuffer
  case nilRawPointer
  case nilMutableRawPointer
  case emptyRawBuffer
  case emptyMutableRawBuffer

  var description: String {
    switch self {
    case .rawPointer:
      "rawPointer"
    case .mutableRawPointer:
      "mutableRawPointer"
    case .rawBuffer:
      "rawBuffer"
    case .mutableRawBuffer:
      "mutableRawBuffer"
    case .nilRawPointer:
      "nilRawPointer"
    case .nilMutableRawPointer:
      "nilMutableRawPointer"
    case .emptyRawBuffer:
      "emptyRawBuffer"
    case .emptyMutableRawBuffer:
      "emptyMutableRawBuffer"
    }
  }

  func expectedData(from bytes: [UInt8]) -> Data {
    switch self {
    case .nilRawPointer, .nilMutableRawPointer, .emptyRawBuffer, .emptyMutableRawBuffer:
      Data()
    case .rawPointer, .mutableRawPointer, .rawBuffer, .mutableRawBuffer:
      Data(bytes)
    }
  }

  func encode(
    bytes: [UInt8],
    into container: inout any SingleValueEncodingContainer
  ) throws {
    switch self {
    case .rawPointer:
      try bytes.withUnsafeBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer.baseAddress, count: buffer.count)
      }
    case .mutableRawPointer:
      var mutableBytes = bytes
      try mutableBytes.withUnsafeMutableBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer.baseAddress, count: buffer.count)
      }
    case .rawBuffer:
      try bytes.withUnsafeBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer)
      }
    case .mutableRawBuffer:
      var mutableBytes = bytes
      try mutableBytes.withUnsafeMutableBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer)
      }
    case .nilRawPointer:
      let pointer: UnsafeRawPointer? = nil
      try container.efficientlyEncodeBinaryData(pointer, count: 0)
    case .nilMutableRawPointer:
      let pointer: UnsafeMutableRawPointer? = nil
      try container.efficientlyEncodeBinaryData(pointer, count: 0)
    case .emptyRawBuffer:
      try container.efficientlyEncodeBinaryData(
        UnsafeRawBufferPointer(start: nil, count: 0)
      )
    case .emptyMutableRawBuffer:
      try container.efficientlyEncodeBinaryData(
        UnsafeMutableRawBufferPointer(start: nil, count: 0)
      )
    }
  }

  func encode<Key: CodingKey>(
    bytes: [UInt8],
    into container: inout KeyedEncodingContainer<Key>,
    forKey key: Key
  ) throws {
    switch self {
    case .rawPointer:
      try bytes.withUnsafeBytes { buffer in
        try container.efficientlyEncodeBinaryData(
          buffer.baseAddress,
          count: buffer.count,
          forKey: key
        )
      }
    case .mutableRawPointer:
      var mutableBytes = bytes
      try mutableBytes.withUnsafeMutableBytes { buffer in
        try container.efficientlyEncodeBinaryData(
          buffer.baseAddress,
          count: buffer.count,
          forKey: key
        )
      }
    case .rawBuffer:
      try bytes.withUnsafeBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer, forKey: key)
      }
    case .mutableRawBuffer:
      var mutableBytes = bytes
      try mutableBytes.withUnsafeMutableBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer, forKey: key)
      }
    case .nilRawPointer:
      let pointer: UnsafeRawPointer? = nil
      try container.efficientlyEncodeBinaryData(pointer, count: 0, forKey: key)
    case .nilMutableRawPointer:
      let pointer: UnsafeMutableRawPointer? = nil
      try container.efficientlyEncodeBinaryData(pointer, count: 0, forKey: key)
    case .emptyRawBuffer:
      try container.efficientlyEncodeBinaryData(
        UnsafeRawBufferPointer(start: nil, count: 0),
        forKey: key
      )
    case .emptyMutableRawBuffer:
      try container.efficientlyEncodeBinaryData(
        UnsafeMutableRawBufferPointer(start: nil, count: 0),
        forKey: key
      )
    }
  }

  func encode(
    bytes: [UInt8],
    into container: inout any UnkeyedEncodingContainer
  ) throws {
    switch self {
    case .rawPointer:
      try bytes.withUnsafeBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer.baseAddress, count: buffer.count)
      }
    case .mutableRawPointer:
      var mutableBytes = bytes
      try mutableBytes.withUnsafeMutableBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer.baseAddress, count: buffer.count)
      }
    case .rawBuffer:
      try bytes.withUnsafeBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer)
      }
    case .mutableRawBuffer:
      var mutableBytes = bytes
      try mutableBytes.withUnsafeMutableBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer)
      }
    case .nilRawPointer:
      let pointer: UnsafeRawPointer? = nil
      try container.efficientlyEncodeBinaryData(pointer, count: 0)
    case .nilMutableRawPointer:
      let pointer: UnsafeMutableRawPointer? = nil
      try container.efficientlyEncodeBinaryData(pointer, count: 0)
    case .emptyRawBuffer:
      try container.efficientlyEncodeBinaryData(
        UnsafeRawBufferPointer(start: nil, count: 0)
      )
    case .emptyMutableRawBuffer:
      try container.efficientlyEncodeBinaryData(
        UnsafeMutableRawBufferPointer(start: nil, count: 0)
      )
    }
  }
}

private struct SingleValueBinaryPayload: Encodable {
  let bytes: [UInt8]
  let mode: BinaryEncodingMode

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try mode.encode(bytes: bytes, into: &container)
  }
}

private struct KeyedBinaryPayload: Encodable {
  let bytes: [UInt8]
  let mode: BinaryEncodingMode

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: BinaryCodingKeys.self)
    try mode.encode(bytes: bytes, into: &container, forKey: .data)
  }
}

private struct UnkeyedBinaryPayload: Encodable {
  let bytes: [UInt8]
  let mode: BinaryEncodingMode

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    try mode.encode(bytes: bytes, into: &container)
  }
}

private struct SingleValueInlineArrayPayload<let N: Int>: Encodable {
  let inlineArray: InlineArray<N, UInt8>

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.efficientlyEncodeBinaryData(inlineArray)
  }
}

private struct KeyedInlineArrayPayload<let N: Int>: Encodable {
  let inlineArray: InlineArray<N, UInt8>

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: BinaryCodingKeys.self)
    try container.efficientlyEncodeBinaryData(inlineArray, forKey: .data)
  }
}

private struct UnkeyedInlineArrayPayload<let N: Int>: Encodable {
  let inlineArray: InlineArray<N, UInt8>

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.efficientlyEncodeBinaryData(inlineArray)
  }
}

private struct KeyedDataValue: Decodable, Equatable {
  let data: Data
}

// MARK: - Element Payloads

private enum ElementEncodingMode: CaseIterable, Sendable, CustomStringConvertible {
  case pointer
  case mutablePointer
  case buffer
  case mutableBuffer
  case nilPointer
  case nilMutablePointer

  var description: String {
    switch self {
    case .pointer:
      "pointer"
    case .mutablePointer:
      "mutablePointer"
    case .buffer:
      "buffer"
    case .mutableBuffer:
      "mutableBuffer"
    case .nilPointer:
      "nilPointer"
    case .nilMutablePointer:
      "nilMutablePointer"
    }
  }

  func expectedElements(from elements: [Int]) -> [Int] {
    switch self {
    case .nilPointer, .nilMutablePointer:
      []
    case .pointer, .mutablePointer, .buffer, .mutableBuffer:
      elements
    }
  }

  func encode<Key: CodingKey>(
    elements: [Int],
    into container: inout KeyedEncodingContainer<Key>,
    forKey key: Key
  ) throws {
    switch self {
    case .pointer:
      try elements.withUnsafeBufferPointer { buffer in
        try container.efficientlyEncodeElements(
          buffer.baseAddress,
          count: buffer.count,
          forKey: key
        )
      }
    case .mutablePointer:
      var mutableElements = elements
      try mutableElements.withUnsafeMutableBufferPointer { buffer in
        try container.efficientlyEncodeElements(
          buffer.baseAddress,
          count: buffer.count,
          forKey: key
        )
      }
    case .buffer:
      try elements.withUnsafeBufferPointer { buffer in
        try container.efficientlyEncodeElements(buffer, forKey: key)
      }
    case .mutableBuffer:
      var mutableElements = elements
      try mutableElements.withUnsafeMutableBufferPointer { buffer in
        try container.efficientlyEncodeElements(buffer, forKey: key)
      }
    case .nilPointer:
      let pointer: UnsafePointer<Int>? = nil
      try container.efficientlyEncodeElements(pointer, count: 0, forKey: key)
    case .nilMutablePointer:
      let pointer: UnsafeMutablePointer<Int>? = nil
      try container.efficientlyEncodeElements(pointer, count: 0, forKey: key)
    }
  }

  func encode(
    elements: [Int],
    into container: inout any UnkeyedEncodingContainer
  ) throws {
    switch self {
    case .pointer:
      try elements.withUnsafeBufferPointer { buffer in
        try container.efficientlyEncodeElements(buffer.baseAddress, count: buffer.count)
      }
    case .mutablePointer:
      var mutableElements = elements
      try mutableElements.withUnsafeMutableBufferPointer { buffer in
        try container.efficientlyEncodeElements(buffer.baseAddress, count: buffer.count)
      }
    case .buffer:
      try elements.withUnsafeBufferPointer { buffer in
        try container.efficientlyEncodeElements(buffer)
      }
    case .mutableBuffer:
      var mutableElements = elements
      try mutableElements.withUnsafeMutableBufferPointer { buffer in
        try container.efficientlyEncodeElements(buffer)
      }
    case .nilPointer:
      let pointer: UnsafePointer<Int>? = nil
      try container.efficientlyEncodeElements(pointer, count: 0)
    case .nilMutablePointer:
      let pointer: UnsafeMutablePointer<Int>? = nil
      try container.efficientlyEncodeElements(pointer, count: 0)
    }
  }
}

private struct KeyedElementPayload: Encodable {
  let elements: [Int]
  let mode: ElementEncodingMode

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: BinaryCodingKeys.self)
    try mode.encode(elements: elements, into: &container, forKey: .elements)
  }
}

private struct UnkeyedElementPayload: Encodable {
  let elements: [Int]
  let mode: ElementEncodingMode

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    try mode.encode(elements: elements, into: &container)
  }
}

private struct KeyedElementValue: Decodable, Equatable {
  let elements: [Int]
}

// MARK: - Binary Wrapper Invocations

private enum BinaryWrapperInvocation: CaseIterable {
  case rawPointer
  case mutableRawPointer
  case rawBuffer
  case mutableRawBuffer
  case nilRawPointer
  case nilMutableRawPointer
  case emptyRawBuffer
  case emptyMutableRawBuffer

  func expectedData(for bytes: [UInt8]) -> Data {
    switch self {
    case .rawPointer, .mutableRawPointer, .rawBuffer, .mutableRawBuffer:
      Data(bytes)
    case .nilRawPointer, .nilMutableRawPointer, .emptyRawBuffer, .emptyMutableRawBuffer:
      Data()
    }
  }

  func encode<Container: SingleValueEncodingContainer>(
    bytes: [UInt8],
    into container: inout Container
  ) throws {
    switch self {
    case .rawPointer:
      try bytes.withUnsafeBytes { buffer in
        try container.efficientlyEncodeBinaryData(
          buffer.baseAddress,
          count: buffer.count
        )
      }
    case .mutableRawPointer:
      var mutableBytes = bytes
      try mutableBytes.withUnsafeMutableBytes { buffer in
        try container.efficientlyEncodeBinaryData(
          buffer.baseAddress,
          count: buffer.count
        )
      }
    case .rawBuffer:
      try bytes.withUnsafeBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer)
      }
    case .mutableRawBuffer:
      var mutableBytes = bytes
      try mutableBytes.withUnsafeMutableBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer)
      }
    case .nilRawPointer:
      let pointer: UnsafeRawPointer? = nil
      try container.efficientlyEncodeBinaryData(pointer, count: 0)
    case .nilMutableRawPointer:
      let pointer: UnsafeMutableRawPointer? = nil
      try container.efficientlyEncodeBinaryData(pointer, count: 0)
    case .emptyRawBuffer:
      try container.efficientlyEncodeBinaryData(
        UnsafeRawBufferPointer(start: nil, count: 0)
      )
    case .emptyMutableRawBuffer:
      try container.efficientlyEncodeBinaryData(
        UnsafeMutableRawBufferPointer(start: nil, count: 0)
      )
    }
  }

  func encode<Container: UnkeyedEncodingContainer>(
    bytes: [UInt8],
    into container: inout Container
  ) throws {
    switch self {
    case .rawPointer:
      try bytes.withUnsafeBytes { buffer in
        try container.efficientlyEncodeBinaryData(
          buffer.baseAddress,
          count: buffer.count
        )
      }
    case .mutableRawPointer:
      var mutableBytes = bytes
      try mutableBytes.withUnsafeMutableBytes { buffer in
        try container.efficientlyEncodeBinaryData(
          buffer.baseAddress,
          count: buffer.count
        )
      }
    case .rawBuffer:
      try bytes.withUnsafeBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer)
      }
    case .mutableRawBuffer:
      var mutableBytes = bytes
      try mutableBytes.withUnsafeMutableBytes { buffer in
        try container.efficientlyEncodeBinaryData(buffer)
      }
    case .nilRawPointer:
      let pointer: UnsafeRawPointer? = nil
      try container.efficientlyEncodeBinaryData(pointer, count: 0)
    case .nilMutableRawPointer:
      let pointer: UnsafeMutableRawPointer? = nil
      try container.efficientlyEncodeBinaryData(pointer, count: 0)
    case .emptyRawBuffer:
      try container.efficientlyEncodeBinaryData(
        UnsafeRawBufferPointer(start: nil, count: 0)
      )
    case .emptyMutableRawBuffer:
      try container.efficientlyEncodeBinaryData(
        UnsafeMutableRawBufferPointer(start: nil, count: 0)
      )
    }
  }
}

// MARK: - Recording Enhanced Containers

private struct RecordingEnhancedSingleValueContainer: XPCEnhancedSingleValueEncodingContainer {
  var codingPath: [any CodingKey] = []
  var recordedData = Data()
  var directCallCount = 0

  mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeMutableRawPointer?,
    count: Int
  ) throws {
    recordedData = data(from: unsafePointer, count: count)
    directCallCount += 1
  }

  mutating func encodeNil() throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Bool) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: String) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Double) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Float) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Int) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Int8) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Int16) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Int32) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Int64) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Int128) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: UInt) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: UInt8) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: UInt16) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: UInt32) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: UInt64) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: UInt128) throws { throw UnexpectedEncodingPathError() }
  mutating func encode<T: Encodable>(_ value: T) throws { throw UnexpectedEncodingPathError() }
}

private struct RecordingEnhancedUnkeyedContainer: XPCEnhancedUnkeyedEncodingContainer {
  var codingPath: [any CodingKey] = []
  var recordedData: [Data] = []
  var count: Int { recordedData.count }

  mutating func directlyEncodeXPCData(
    _ unsafePointer: UnsafeMutableRawPointer?,
    count: Int
  ) throws {
    recordedData.append(data(from: unsafePointer, count: count))
  }

  mutating func encodeNil() throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Bool) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: String) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Double) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Float) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Int) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Int8) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Int16) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Int32) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Int64) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: Int128) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: UInt) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: UInt8) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: UInt16) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: UInt32) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: UInt64) throws { throw UnexpectedEncodingPathError() }
  mutating func encode(_ value: UInt128) throws { throw UnexpectedEncodingPathError() }
  mutating func encode<T: Encodable>(_ value: T) throws { throw UnexpectedEncodingPathError() }

  mutating func nestedContainer<NestedKey>(
    keyedBy keyType: NestedKey.Type
  ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
    fatalError("Not used by these tests.")
  }

  mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
    fatalError("Not used by these tests.")
  }

  mutating func superEncoder() -> any Encoder {
    fatalError("Not used by these tests.")
  }
}

private final class ReferenceRecordingEnhancedSingleValueContainer:
  XPCEnhancedSingleValueEncodingContainer
{
  var codingPath: [any CodingKey] = []
  var recordedData = Data()
  var directCallCount = 0

  func directlyEncodeXPCData(
    _ unsafePointer: UnsafeMutableRawPointer?,
    count: Int
  ) throws {
    recordedData = data(from: unsafePointer, count: count)
    directCallCount += 1
  }

  func encodeNil() throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: Bool) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: String) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: Double) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: Float) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: Int) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: Int8) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: Int16) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: Int32) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: Int64) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: Int128) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: UInt) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: UInt8) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: UInt16) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: UInt32) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: UInt64) throws { throw UnexpectedEncodingPathError() }
  func encode(_ value: UInt128) throws { throw UnexpectedEncodingPathError() }
  func encode<T: Encodable>(_ value: T) throws { throw UnexpectedEncodingPathError() }
}

private struct UnexpectedEncodingPathError: Error {}

private func data(from unsafePointer: UnsafeMutableRawPointer?, count: Int) -> Data {
  guard
    let unsafePointer,
    count > 0
  else {
    return Data()
  }

  return Data(bytes: unsafePointer, count: count)
}

private func extractData(
  fromXPCData object: xpc_object_t,
  sourceLocation: SourceLocation = #_sourceLocation
) throws -> Data {
  try #require(
    xpc_get_type(object) == XPC_TYPE_DATA,
    "Expected XPC data, but got \(object.typeDescription).",
    sourceLocation: sourceLocation
  )

  let length = xpc_data_get_length(object)
  guard length > 0 else {
    return Data()
  }

  var result = Data(repeating: 0, count: length)
  let copiedOK = result.withUnsafeMutableBytes { unsafeMutableBytes in
    guard let baseAddress = unsafeMutableBytes.baseAddress else {
      return false
    }

    let copiedCount = xpc_data_get_bytes(object, baseAddress, 0, length)
    return copiedCount == length
  }

  try #require(
    copiedOK,
    "Unable to copy \(length) bytes from XPC data.",
    sourceLocation: sourceLocation
  )

  return result
}

// MARK: - Generated Payloads

private struct SeededGenerator: RandomNumberGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

private func generatedBytePayloads(count: Int, maximumLength: Int) -> [[UInt8]] {
  var generator = SeededGenerator(state: 0x5eed_1234_abcd_9876)
  var result: [[UInt8]] = [[]]
  result.reserveCapacity(count + 1)

  for _ in 0..<count {
    let length = Int(generator.next() % UInt64(maximumLength + 1))
    let payload = (0..<length).map { _ in
      UInt8(truncatingIfNeeded: generator.next())
    }
    result.append(payload)
  }

  return result
}

private struct InlineArrayProbe<let N: Int> {
  let inlineArray: InlineArray<N, UInt8>
  let expectedData: Data
}

private func generatedInlineArrayPayloads() -> [InlineArrayProbe<8>] {
  var generator = SeededGenerator(state: 0x1a11_1eaa_5eed)
  return (0..<32).map { _ in
    let bytes = (0..<8).map { _ in UInt8(truncatingIfNeeded: generator.next()) }
    let inlineArray: InlineArray<8, UInt8> = [
      bytes[0],
      bytes[1],
      bytes[2],
      bytes[3],
      bytes[4],
      bytes[5],
      bytes[6],
      bytes[7],
    ]
    return InlineArrayProbe(
      inlineArray: inlineArray,
      expectedData: Data(bytes)
    )
  }
}

private func generatedIntPayloads(count: Int, maximumLength: Int) -> [[Int]] {
  var generator = SeededGenerator(state: 0xc0de_9876_1234_5eed)
  var result: [[Int]] = [[]]
  result.reserveCapacity(count + 1)

  for _ in 0..<count {
    let length = Int(generator.next() % UInt64(maximumLength + 1))
    let payload = (0..<length).map { _ in
      Int(truncatingIfNeeded: generator.next()) % 1_000_000
    }
    result.append(payload)
  }

  return result
}
