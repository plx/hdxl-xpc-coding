import Darwin
import Dispatch
import Foundation
import Testing
import XPC
import XPCCoding

// MARK: - Decoder Resource Limit Tests

@Suite("Decoder Resource Limits", .tags(.decoding, .edgeCases))
struct DecoderResourceLimitTests {

  // MARK: Public Configuration

  @Test
  func `standard limits are finite and documented`() {
    let standard = XPCDecoder.ResourceLimits.standard

    #expect(standard.maximumNestingDepth == 128)
    #expect(standard.maximumContainerElementCount == 65_536)
    #expect(standard.maximumTotalNodeCount == 262_144)
    #expect(standard.maximumStringByteCount == 8 * 1_024 * 1_024)
    #expect(standard.maximumDataByteCount == 32 * 1_024 * 1_024)
    #expect(standard.maximumCumulativeByteCount == 64 * 1_024 * 1_024)
    #expect(standard.description.contains("depth"))
    #expect(standard.debugDescription.contains("maximumTotalNodeCount"))
  }

  @Test
  func `configuration initializer accepts explicit decoder-local limits`() {
    let limits = resourceLimits(maximumNestingDepth: 7)
    let configuration = XPCCodec.Configuration(
      stringKeyStrategy: .percentEscape,
      stringValueStrategy: .percentEscape
    )
    let decoder = XPCDecoder(
      configuration: configuration,
      resourceLimits: limits
    )

    #expect(decoder.stringKeyStrategy == .percentEscape)
    #expect(decoder.stringValueStrategy == .percentEscape)
    #expect(decoder.resourceLimits == limits)
  }

  @Test
  func `limits are isolated between top-level decode operations`() throws {
    let twoValues = createXPCArray([xpcInt64(1), xpcInt64(2)])
    let decoder = XPCDecoder(
      resourceLimits: resourceLimits(maximumTotalNodeCount: 2)
    )

    try requireResourceLimit(
      named: "maximumTotalNodeCount",
      codingPath: ["1"]
    ) {
      _ = try decoder.decode([Int].self, from: twoValues)
    }

    #expect(try decoder.decode(Int.self, from: xpcInt64(7)) == 7)

    decoder.resourceLimits = resourceLimits(maximumTotalNodeCount: 3)
    #expect(try decoder.decode([Int].self, from: twoValues) == [1, 2])
  }

  // MARK: Nesting And Cycles

  @Test
  func `nesting at the limit succeeds and one level over throws`() throws {
    let decoder = XPCDecoder(
      resourceLimits: resourceLimits(maximumNestingDepth: 4)
    )

    _ = try decoder.decode(
      RecursiveArray.self,
      from: nestedXPCArray(edgeCount: 4)
    )

    try requireResourceLimit(
      named: "maximumNestingDepth",
      codingPath: Array(repeating: "0", count: 5)
    ) {
      _ = try decoder.decode(
        RecursiveArray.self,
        from: nestedXPCArray(edgeCount: 5)
      )
    }
  }

  @Test
  func `self and two-object cycles throw typed depth errors`() throws {
    let decoder = XPCDecoder(
      resourceLimits: resourceLimits(maximumNestingDepth: 8)
    )

    try requireResourceLimit(named: "maximumNestingDepth") {
      _ = try decoder.decode(
        RecursiveArray.self,
        from: selfReferentialXPCArray()
      )
    }
    try requireResourceLimit(named: "maximumNestingDepth") {
      _ = try decoder.decode(
        RecursiveArray.self,
        from: twoObjectXPCArrayCycle()
      )
    }
  }

  @Test
  func `shared acyclic child is permitted and each traversal consumes one node`() throws {
    let sharedChild = createXPCArray([])
    let root = createXPCArray([sharedChild, sharedChild])
    let decoder = XPCDecoder(
      resourceLimits: resourceLimits(maximumTotalNodeCount: 3)
    )

    _ = try decoder.decode(SharedArrayPair.self, from: root)

    let oneNodeTooFew = XPCDecoder(
      resourceLimits: resourceLimits(maximumTotalNodeCount: 2)
    )
    try requireResourceLimit(
      named: "maximumTotalNodeCount",
      codingPath: ["1"]
    ) {
      _ = try oneNodeTooFew.decode(SharedArrayPair.self, from: root)
    }
  }

  /// Retains the exact class of baseline reproducer that terminated its child
  /// with `SIGBUS` before shared depth accounting existed.
  @Test(
    .enabled(
      if: resourceLimitSubprocessIsolationIsSupported,
      resourceLimitSubprocessIsolationRequirement
    )
  )
  func `extreme depth and cyclic graphs return typed errors in a subprocess`() async {
    await #expect(processExitsWith: .success) {
      let decoder = XPCDecoder.standard
      try requireTypedResourceRejection(
        decoder: decoder,
        object: nestedXPCArray(edgeCount: 5_000),
        limitName: "maximumNestingDepth"
      )
      try requireTypedResourceRejection(
        decoder: decoder,
        object: selfReferentialXPCArray(),
        limitName: "maximumNestingDepth"
      )
      try requireTypedResourceRejection(
        decoder: decoder,
        object: twoObjectXPCArrayCycle(),
        limitName: "maximumNestingDepth"
      )
    }
  }

  // MARK: Containers And Nodes

  @Test
  func `per-container element boundary is enforced before traversal`() throws {
    let decoder = XPCDecoder(
      resourceLimits: resourceLimits(maximumContainerElementCount: 2)
    )

    #expect(
      try decoder.decode(
        [Int].self,
        from: createXPCArray([xpcInt64(1), xpcInt64(2)])
      ) == [1, 2]
    )

    try requireResourceLimit(
      named: "maximumContainerElementCount",
      codingPath: []
    ) {
      _ = try decoder.decode(
        [Int].self,
        from: createXPCArray([xpcInt64(1), xpcInt64(2), xpcInt64(3)])
      )
    }
  }

  @Test
  func `dictionary element boundary is enforced before key enumeration`() throws {
    let decoder = XPCDecoder(
      resourceLimits: resourceLimits(maximumContainerElementCount: 2)
    )

    #expect(
      try decoder.decode(
        AllKeysProbe.self,
        from: createXPCDictionary([
          ("a", xpcNull()),
          ("b", xpcNull()),
        ])
      ).keys.sorted() == ["a", "b"]
    )

    try requireResourceLimit(
      named: "maximumContainerElementCount",
      codingPath: []
    ) {
      _ = try decoder.decode(
        AllKeysProbe.self,
        from: createXPCDictionary([
          ("a", xpcNull()),
          ("b", xpcNull()),
          ("c", xpcNull()),
        ])
      )
    }
  }

  @Test
  func `total-node boundary includes the root and repeated visits`() throws {
    let object = createXPCArray([xpcInt64(1), xpcInt64(2)])

    #expect(
      try XPCDecoder(
        resourceLimits: resourceLimits(maximumTotalNodeCount: 3)
      ).decode([Int].self, from: object) == [1, 2]
    )

    try requireResourceLimit(
      named: "maximumTotalNodeCount",
      codingPath: ["1"]
    ) {
      _ = try XPCDecoder(
        resourceLimits: resourceLimits(maximumTotalNodeCount: 2)
      ).decode([Int].self, from: object)
    }
  }

  // MARK: Strings And Dictionary Keys

  @Test
  func `XPC-string byte boundary is enforced`() throws {
    let decoder = XPCDecoder(
      resourceLimits: resourceLimits(
        maximumStringByteCount: 4,
        maximumCumulativeByteCount: 4
      )
    )

    #expect(try decoder.decode(String.self, from: xpcString("abcd")) == "abcd")
    try requireResourceLimit(
      named: "maximumStringByteCount",
      codingPath: []
    ) {
      _ = try decoder.decode(String.self, from: xpcString("abcde"))
    }
  }

  @Test
  func `data-backed string byte boundary is enforced before copying`() throws {
    let decoder = XPCDecoder(
      stringValueStrategy: .useDataRepresentation(.utf8),
      resourceLimits: resourceLimits(
        maximumStringByteCount: 4,
        maximumCumulativeByteCount: 4
      )
    )

    #expect(
      try decoder.decode(
        String.self,
        from: xpcData(Data("abcd".utf8))
      ) == "abcd"
    )
    try requireResourceLimit(
      named: "maximumStringByteCount",
      codingPath: []
    ) {
      _ = try decoder.decode(
        String.self,
        from: xpcData(Data("abcde".utf8))
      )
    }
  }

  @Test
  func `dictionary keys are checked before allKeys allocates them`() throws {
    let decoder = XPCDecoder(
      resourceLimits: resourceLimits(
        maximumStringByteCount: 3,
        maximumCumulativeByteCount: 3
      )
    )

    #expect(
      try decoder.decode(
        AllKeysProbe.self,
        from: createXPCDictionary([("abc", xpcNull())])
      ).keys == ["abc"]
    )
    try requireResourceLimit(
      named: "maximumStringByteCount",
      codingPath: []
    ) {
      _ = try decoder.decode(
        AllKeysProbe.self,
        from: createXPCDictionary([("abcd", xpcNull())])
      )
    }
  }

  @Test
  func `cumulative string-byte boundary is shared by siblings`() throws {
    let strings = createXPCArray([xpcString("abcd"), xpcString("efgh")])

    #expect(
      try XPCDecoder(
        resourceLimits: resourceLimits(
          maximumStringByteCount: 4,
          maximumCumulativeByteCount: 8
        )
      ).decode([String].self, from: strings) == ["abcd", "efgh"]
    )

    try requireResourceLimit(
      named: "maximumCumulativeByteCount",
      codingPath: ["1"]
    ) {
      _ = try XPCDecoder(
        resourceLimits: resourceLimits(
          maximumStringByteCount: 4,
          maximumCumulativeByteCount: 7
        )
      ).decode([String].self, from: strings)
    }
  }

  // MARK: Data

  @Test
  func `per-value and cumulative data-byte boundaries are enforced`() throws {
    let fourBytes = xpcData(Data([0, 1, 2, 3]))
    let fiveBytes = xpcData(Data([0, 1, 2, 3, 4]))

    #expect(
      try XPCDecoder(
        resourceLimits: resourceLimits(
          maximumDataByteCount: 4,
          maximumCumulativeByteCount: 4
        )
      ).decode([Data].self, from: createXPCArray([fourBytes])) == [
        Data([0, 1, 2, 3])
      ]
    )

    try requireResourceLimit(
      named: "maximumDataByteCount",
      codingPath: ["0"]
    ) {
      _ = try XPCDecoder(
        resourceLimits: resourceLimits(
          maximumDataByteCount: 4,
          maximumCumulativeByteCount: 8
        )
      ).decode([Data].self, from: createXPCArray([fiveBytes]))
    }

    let siblings = createXPCArray([fourBytes, fourBytes])
    #expect(
      try XPCDecoder(
        resourceLimits: resourceLimits(
          maximumDataByteCount: 4,
          maximumCumulativeByteCount: 8
        )
      ).decode([Data].self, from: siblings) == [
        Data([0, 1, 2, 3]),
        Data([0, 1, 2, 3]),
      ]
    )
    try requireResourceLimit(
      named: "maximumCumulativeByteCount",
      codingPath: ["1"]
    ) {
      _ = try XPCDecoder(
        resourceLimits: resourceLimits(
          maximumDataByteCount: 4,
          maximumCumulativeByteCount: 7
        )
      ).decode([Data].self, from: siblings)
    }
  }

  @Test(
    .enabled(
      if: resourceLimitSubprocessIsolationIsSupported,
      resourceLimitSubprocessIsolationRequirement
    )
  )
  func `oversized data is rejected without touching inaccessible payload bytes`() async {
    await #expect(processExitsWith: .success) {
      try withInaccessibleXPCData { inaccessibleData in
        let decoder = XPCDecoder(
          resourceLimits: resourceLimits(
            maximumDataByteCount: 0,
            maximumCumulativeByteCount: 0
          )
        )
        try requireTypedResourceRejection(
          decoder: decoder,
          object: createXPCArray([inaccessibleData]),
          valueType: [Data].self,
          limitName: "maximumDataByteCount"
        )
      }
    }
  }

  // MARK: Coding Paths

  @Test
  func `resource errors retain the complete nested coding path`() throws {
    let object = createXPCDictionary([
      ("outer", createXPCArray([xpcString("too long")]))
    ])
    let decoder = XPCDecoder(
      resourceLimits: resourceLimits(maximumStringByteCount: 5)
    )

    try requireResourceLimit(
      named: "maximumStringByteCount",
      codingPath: ["outer", "0"]
    ) {
      _ = try decoder.decode(NestedStringProbe.self, from: object)
    }
  }

}

// MARK: - Limit Fixtures

private func resourceLimits(
  maximumNestingDepth: Int = 16,
  maximumContainerElementCount: Int = 16,
  maximumTotalNodeCount: Int = 64,
  maximumStringByteCount: Int = 64,
  maximumDataByteCount: Int = 64,
  maximumCumulativeByteCount: Int = 256
) -> XPCDecoder.ResourceLimits {
  XPCDecoder.ResourceLimits(
    maximumNestingDepth: maximumNestingDepth,
    maximumContainerElementCount: maximumContainerElementCount,
    maximumTotalNodeCount: maximumTotalNodeCount,
    maximumStringByteCount: maximumStringByteCount,
    maximumDataByteCount: maximumDataByteCount,
    maximumCumulativeByteCount: maximumCumulativeByteCount
  )
}

private indirect enum RecursiveArray: Decodable {
  case leaf
  case branch(RecursiveArray)

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    if container.isAtEnd {
      self = .leaf
    } else {
      self = try .branch(container.decode(Self.self))
    }
  }
}

private struct SharedArrayPair: Decodable {
  let first: RecursiveArray
  let second: RecursiveArray

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    self.first = try container.decode(RecursiveArray.self)
    self.second = try container.decode(RecursiveArray.self)
  }
}

private struct AllKeysProbe: Decodable {
  struct Key: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
      self.stringValue = stringValue
      self.intValue = nil
    }

    init?(intValue: Int) {
      self.stringValue = String(intValue)
      self.intValue = intValue
    }
  }

  let keys: [String]

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: Key.self)
    self.keys = container.allKeys.map(\.stringValue)
  }
}

private struct NestedStringProbe: Decodable {
  enum CodingKeys: String, CodingKey {
    case outer
  }

  let outer: [String]
}

// MARK: - Graph Construction

private func nestedXPCArray(edgeCount: Int) -> xpc_object_t {
  var result = createXPCArray([])
  for _ in 0..<edgeCount {
    result = createXPCArray([result])
  }
  return result
}

private func selfReferentialXPCArray() -> xpc_object_t {
  let array = createXPCArray([])
  xpc_array_append_value(array, array)
  return array
}

private func twoObjectXPCArrayCycle() -> xpc_object_t {
  let first = createXPCArray([])
  let second = createXPCArray([])
  xpc_array_append_value(first, second)
  xpc_array_append_value(second, first)
  return first
}

// MARK: - Error Verification

private func requireResourceLimit(
  named limitName: String,
  codingPath expectedCodingPath: [String]? = nil,
  _ operation: () throws -> Void
) throws {
  do {
    try operation()
    Issue.record("Expected the \(limitName) resource limit to reject the input.")
  } catch let error as DecodingError {
    guard case .dataCorrupted(let context) = error else {
      Issue.record(
        "Expected dataCorrupted for \(limitName), but received \(String(reflecting: error))."
      )
      return
    }
    #expect(context.debugDescription.contains(limitName))
    if let expectedCodingPath {
      try verifyCodingPath(
        context.codingPath,
        matches: expectedCodingPath
      )
    }
  } catch {
    Issue.record(
      "Expected DecodingError for \(limitName), but received \(String(reflecting: error))."
    )
  }
}

private enum ResourceLimitSubprocessFailure: Error {
  case decodedUnexpectedly
  case wrongError(String)
}

private func requireTypedResourceRejection(
  decoder: XPCDecoder,
  object: xpc_object_t,
  limitName: String
) throws {
  try requireTypedResourceRejection(
    decoder: decoder,
    object: object,
    valueType: RecursiveArray.self,
    limitName: limitName
  )
}

private func requireTypedResourceRejection<Value: Decodable>(
  decoder: XPCDecoder,
  object: xpc_object_t,
  valueType: Value.Type,
  limitName: String
) throws {
  do {
    _ = try decoder.decode(valueType, from: object)
    throw ResourceLimitSubprocessFailure.decodedUnexpectedly
  } catch let error as DecodingError {
    guard
      case .dataCorrupted(let context) = error,
      context.debugDescription.contains(limitName)
    else {
      throw ResourceLimitSubprocessFailure.wrongError(
        String(reflecting: error)
      )
    }
  }
}

// MARK: - Inaccessible Data

private func withInaccessibleXPCData<Result>(
  _ body: (xpc_object_t) throws -> Result
) throws -> Result {
  let byteCount = Int(getpagesize())
  let mapping = mmap(
    nil,
    byteCount,
    PROT_READ | PROT_WRITE,
    MAP_PRIVATE | MAP_ANON,
    -1,
    0
  )
  try #require(
    mapping != MAP_FAILED,
    "`mmap` failed with errno \(errno)."
  )
  let bytes = try #require(
    mapping,
    "A successful mmap call must return storage."
  )
  _ = bytes.initializeMemory(as: UInt8.self, repeating: 0xA5, count: byteCount)

  let dispatchData = DispatchData(
    bytesNoCopy: UnsafeRawBufferPointer(start: bytes, count: byteCount),
    deallocator: .custom(nil, {})
  )
  let object = xpc_data_create_with_dispatch_data(dispatchData as dispatch_data_t)
  try #require(xpc_data_get_length(object) == byteCount)
  try #require(
    xpc_data_get_bytes_ptr(object) == UnsafeRawPointer(bytes),
    "libxpc must reference the guarded payload directly, or the test would be vacuous."
  )
  try #require(
    mprotect(bytes, byteCount, PROT_NONE) == 0,
    "`mprotect` failed with errno \(errno)."
  )
  defer {
    _ = mprotect(bytes, byteCount, PROT_READ | PROT_WRITE)
    _ = munmap(bytes, byteCount)
  }

  let result = try body(object)
  withExtendedLifetime((dispatchData, object)) {}
  return result
}

// MARK: - Subprocess Support

private let resourceLimitSubprocessIsolationRequirement: Comment = """
  Subprocess-isolated tests need a test host that can re-launch itself with the \
  sanitizer runtime loaded early enough to install its interceptors.
  """

private let resourceLimitSubprocessIsolationIsSupported: Bool = {
  let interceptingSanitizerSymbols = ["__asan_init", "__tsan_init"]
  let allLoadedImages = UnsafeMutableRawPointer(bitPattern: -2)
  return interceptingSanitizerSymbols.allSatisfy { symbolName in
    symbolName.withCString { symbol in
      dlsym(allLoadedImages, symbol) == nil
    }
  }
}()
