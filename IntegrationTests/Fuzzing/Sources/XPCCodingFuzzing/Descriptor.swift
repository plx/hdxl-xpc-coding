import Foundation

// MARK: - Probe Descriptor

/// One completely reproducible fuzzing case.
///
/// A descriptor is the only thing a child process receives. It is pure data:
/// replaying a descriptor cannot depend on the parent's memory, the wall clock,
/// or the order in which other cases ran.
struct ProbeDescriptor: Codable, Equatable, Sendable {
  var id: String
  var origin: String
  var seed: UInt64
  var probe: Probe

  var seedHex: String {
    String(format: "0x%016llx", seed)
  }
}

// MARK: - Probe

enum Probe: Codable, Equatable, Sendable {
  case model(ModelProbe)
  case distinctStrings(DistinctStringsProbe)
  case keyCollision(KeyCollisionProbe)
  case graph(GraphProbe)
  case cycle(CycleProbe)
  case binary128(Binary128Probe)
  case resourceBoundary(ResourceBoundaryProbe)
  case rawText(RawTextProbe)
  case pointerCount(PointerCountProbe)
  case representation(RepresentationProbe)
  case deliberateHang

  /// The exact expectation implied by this probe's own content.
  ///
  /// Mutation rewrites stored expectations with this value so that a mutated
  /// case can never fail merely because it inherited its ancestor's verdict.
  var derivedExpectation: Expectation {
    switch self {
    case .binary128(let probe):
      probe.derivedExpectation
    case .resourceBoundary(let probe):
      probe.derivedExpectation
    case .pointerCount(let probe):
      probe.derivedExpectation
    case .cycle(let probe):
      probe.derivedExpectation
    case .model, .distinctStrings, .keyCollision, .graph, .representation:
      .pass
    case .rawText:
      .tolerant
    case .deliberateHang:
      .tolerant
    }
  }

  var kindName: String {
    switch self {
    case .model: "model"
    case .distinctStrings: "distinct-strings"
    case .keyCollision: "key-collision"
    case .graph: "graph"
    case .cycle: "cycle"
    case .binary128: "binary128"
    case .resourceBoundary: "resource-boundary"
    case .rawText: "raw-text"
    case .pointerCount: "pointer-count"
    case .representation: "representation"
    case .deliberateHang: "deliberate-hang"
    }
  }
}

// MARK: - Expectation

enum Expectation: String, Codable, Equatable, Sendable {
  /// The operation must complete successfully and satisfy every assertion.
  case pass

  /// The operation must throw a public `DecodingError` or `EncodingError`.
  case reject

  /// The operation must either succeed or throw a public coding error.
  ///
  /// This is the "arbitrary supported input" contract: never a crash, a trap, a
  /// hang, an internal error type, or a breached resource bound.
  case tolerant
}

// MARK: - String Strategies

/// The string strategies exercised by string-bearing probes.
///
/// Every listed strategy is total over Swift `String`, so a round-trip failure
/// is always a defect rather than documented lossiness. `.assumeAbsent` is
/// deliberately excluded here and is exercised by ``KeyCollisionProbe`` against
/// its exact documented truncation behavior.
enum StringStrategy: String, Codable, Equatable, Sendable, CaseIterable {
  case percentEscape
  case dataUTF8
  case dataUTF16
  case dataUTF32
}

// MARK: - Model Probe

struct ModelProbe: Codable, Equatable, Sendable {
  var strategy: StringStrategy
  var value: FuzzModel
}

struct FuzzModel: Codable, Equatable, Sendable {
  var string: String
  var dictionary: [String: Int64]
  var signed: Int64
  var unsigned: UInt64
  var floatingPoint: Double
  var data: Data
  var numbers: [Int32]
  var child: FuzzChild?
}

struct FuzzChild: Codable, Equatable, Sendable {
  var label: String
  var enabled: Bool
}

// MARK: - Distinct Strings Probe

/// Asserts injectivity and exact round-tripping for a set of Swift strings.
struct DistinctStringsProbe: Codable, Equatable, Sendable {
  var strategy: StringStrategy
  var strings: [String]
}

// MARK: - Key Collision Probe

/// Asserts the exact documented dictionary-key behavior for a key strategy.
struct KeyCollisionProbe: Codable, Equatable, Sendable {
  var strategy: KeyStrategy
  var keys: [String]
}

enum KeyStrategy: String, Codable, Equatable, Sendable, CaseIterable {
  /// Total over Swift `String`; distinct keys must never alias.
  case percentEscape

  /// Deliberately unchecked; keys truncate at their first null scalar.
  case assumeAbsent
}

// MARK: - Graph Probe

/// An arbitrary supported XPC object graph, described as an explicit node list.
///
/// Edges are node indices, so a descriptor can express shared children and
/// cycles without needing a recursive JSON encoding.
struct GraphProbe: Codable, Equatable, Sendable {
  var nodes: [GraphNode]
  var root: Int
}

enum GraphNode: Codable, Equatable, Sendable {
  case null
  case bool(Bool)
  case signed(Int64)
  case unsigned(UInt64)
  case double(Double)
  case data(Data)
  case string([UInt8])
  case array([Int])
  case dictionary([GraphEntry])
}

struct GraphEntry: Codable, Equatable, Sendable {
  var key: [UInt8]
  var target: Int
}

// MARK: - Cycle Probe

struct CycleProbe: Codable, Equatable, Sendable {
  var shape: CycleShape
  var expectation: Expectation

  var derivedExpectation: Expectation {
    shape.isCyclic ? .reject : .pass
  }
}

enum CycleShape: String, Codable, Equatable, Sendable, CaseIterable {
  case emptySelfArray
  case valueBearingSelfArray
  case mutualArrays
  case selfDictionary
  case mutualDictionaries
  case sharedAcyclicArray
  case sharedAcyclicDictionary

  var isCyclic: Bool {
    switch self {
    case .emptySelfArray, .valueBearingSelfArray, .mutualArrays, .selfDictionary,
      .mutualDictionaries:
      true
    case .sharedAcyclicArray, .sharedAcyclicDictionary:
      false
    }
  }
}

// MARK: - 128-Bit Probe

struct Binary128Probe: Codable, Equatable, Sendable {
  var type: Binary128Type
  var bytes: Data
  var unaligned: Bool
  var expectation: Expectation

  var derivedExpectation: Expectation {
    bytes.count == 16 ? .pass : .reject
  }
}

enum Binary128Type: String, Codable, Equatable, Sendable, CaseIterable {
  case signed
  case unsigned
}

// MARK: - Resource Boundary Probe

struct ResourceBoundaryProbe: Codable, Equatable, Sendable {
  var resource: ResourceKind
  var limit: Int
  var observed: Int
  var expectation: Expectation

  /// The limit the decoder is actually configured with.
  ///
  /// `maximumTotalNodeCount` must be at least one because every decode visits
  /// its root object.
  var effectiveLimit: Int {
    resource == .totalNodes ? max(1, limit) : limit
  }

  var derivedExpectation: Expectation {
    observed <= effectiveLimit ? .pass : .reject
  }
}

enum ResourceKind: String, Codable, Equatable, Sendable, CaseIterable {
  case depth
  case breadth
  case totalNodes
  case stringBytes
  case dataBytes
  case cumulativeBytes
}

// MARK: - Raw Text Probe

/// Decodes attacker-supplied bytes as an XPC string value or dictionary key.
///
/// This covers both external UTF-8 validity and the percent-escape grammar. The
/// bytes are the *raw* XPC representation, so they may never contain a null
/// byte: libxpc's C-string APIs cannot carry one.
struct RawTextProbe: Codable, Equatable, Sendable {
  var location: RawTextLocation
  var strategy: RawTextStrategy
  var bytes: [UInt8]
  var expectation: Expectation

  /// The exact expected decoded text, as Unicode scalar values.
  ///
  /// Scalar values keep null and other unprintable scalars unambiguous in the
  /// checked-in JSON. Only meaningful when `expectation` is `.pass`.
  var expectedScalars: [UInt32]?

  var expectedString: String? {
    guard let expectedScalars else {
      return nil
    }
    var view = String.UnicodeScalarView()
    for value in expectedScalars {
      guard let scalar = Unicode.Scalar(value) else {
        return nil
      }
      view.append(scalar)
    }
    return String(view)
  }
}

enum RawTextLocation: String, Codable, Equatable, Sendable, CaseIterable {
  case stringValue
  case dictionaryKey
}

enum RawTextStrategy: String, Codable, Equatable, Sendable, CaseIterable {
  case percentEscape
  case passthrough
}

// MARK: - Pointer/Count Probe

/// The initialized, readable backing storage every pointer probe borrows.
///
/// A raw pointer carries no extent metadata, so a positive count larger than
/// this extent would be undefined behavior rather than a test. This is the one
/// definition of that extent: the generator, the mutator, the checked-in
/// corpus, and the probe itself all derive from it.
let pointerProbeBytes: [UInt8] = [0x2a, 0x63, 0xa5, 0x5a]

/// Every count a pointer probe may safely be asked to encode.
///
/// Two negative values, zero, and each positive count up to the full extent.
/// Nothing larger is ever generated; ``PointerCountProbe`` refuses such a
/// descriptor rather than handing it to libxpc.
let pointerProbeCountAlphabet: [Int] = Array(-2...pointerProbeBytes.count)

struct PointerCountProbe: Codable, Equatable, Sendable {
  var shape: PointerContainerShape
  var suppliesPointer: Bool
  var mutable: Bool
  var count: Int
  var expectation: Expectation

  /// The library contract for this pointer/count pair.
  ///
  /// This describes what XPCCoding must do, which is defined for every count.
  /// Whether the *harness* may evaluate the pair is a separate question, and is
  /// answered by ``isEvaluable``.
  var derivedExpectation: Expectation {
    guard count >= 0 else {
      return .reject
    }
    return count == 0 || suppliesPointer ? .pass : .reject
  }

  /// Whether this pair can be handed to libxpc without undefined behavior.
  var isEvaluable: Bool {
    count <= pointerProbeBytes.count
  }
}

enum PointerContainerShape: String, Codable, Equatable, Sendable, CaseIterable {
  case singleValue
  case keyed
  case unkeyed
}

// MARK: - Representation Probe

/// Asserts the documented XPC object kind and exact round-trip for one
/// primitive from the representation contract.
struct RepresentationProbe: Codable, Equatable, Sendable {
  var kind: RepresentationKind
  var bytes: Data
  var signed: Int64
  var unsigned: UInt64
  var floatBits: UInt32
  var doubleBits: UInt64
}

enum RepresentationKind: String, Codable, Equatable, Sendable, CaseIterable {
  case data
  case signedNarrow
  case unsignedNarrow
  case float16
  case float32
  case doubleValue
}

// MARK: - JSON Support

enum FuzzingJSON {

  static func encode<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }

  static func decode<T: Decodable>(
    _ type: T.Type,
    from data: Data
  ) throws -> T {
    try JSONDecoder().decode(type, from: data)
  }

  /// A stable FNV-1a digest of a value's canonical JSON form.
  ///
  /// Determinism evidence compares digests rather than eyeballing large case
  /// lists, and the digest is stable across processes and runs.
  static func digest<T: Encodable>(_ value: T) throws -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in try encode(value) {
      hash ^= UInt64(byte)
      hash &*= 0x0000_0100_0000_01b3
    }
    return String(format: "%016llx", hash)
  }

}
