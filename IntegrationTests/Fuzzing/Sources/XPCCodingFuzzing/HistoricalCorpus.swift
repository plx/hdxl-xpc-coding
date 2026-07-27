import Foundation

// MARK: - Historical String Atoms

/// The exact string, key, and byte atoms that historically produced defects.
///
/// These are reviewed expectations, not samples: every atom below corresponds to
/// a concrete corruption, collision, truncation, or rejection failure recorded
/// during the audit. Generated cases mix them in so a random draw can never lose
/// them.
enum HistoricalStrings {

  /// The audit's required string corpus, verbatim.
  static let auditCorpus: [String] = [
    "",
    "plain",
    "%",
    "%0",
    "%00",
    "%25",
    "%41",
    "%GG",
    "100%",
    "a%20b",
    "a%00b",
    "a\0b",
    "%\u{301}",
    "x%\u{301}41",
  ]

  /// Literal percent signs in every position that historically mis-escaped.
  static let literalPercentGroup: [String] = [
    "%",
    "%%",
    "%25",
    "%2525",
    "100%",
    "%at%start",
    "at%end%",
    "a%20b",
    "%41",
    "%GG",
    "%0",
    "50%%50",
  ]

  /// Embedded nulls in every position, including the pairs that aliased.
  static let nullGroup: [String] = [
    "\0",
    "\0\0",
    "\0lead",
    "trail\0",
    "a\0b",
    "a\0\0b",
    "a",
    "",
    "%00",
    "a%00b",
  ]

  /// Combining marks, including the sequences that follow a percent sign.
  static let combiningMarkGroup: [String] = [
    "e\u{301}",
    "é",
    "\u{301}",
    "%\u{301}",
    "x%\u{301}41",
    "a\u{301}\u{327}",
    "q\u{0308}\u{0304}",
    "\0\u{301}",
  ]

  /// One representative from each Unicode region the contract mentions.
  static let unicodePlaneGroup: [String] = [
    "plain",
    "ASCII~!@#",
    "中文",
    "Ωμέγα",
    "🚀",
    "𝄞",
    "🇺🇳",
    "e\u{301}",
    "é",
  ]

  /// Key sets whose members historically collapsed onto one XPC key.
  ///
  /// The last two were discovered by this harness's own mutation campaign. They
  /// pin down that an XPC dictionary key is identified by its *bytes*: after
  /// null truncation, `"e\u{301}"` and `"é"` are one Swift key by canonical
  /// equivalence but two distinct XPC keys.
  static let collisionKeySets: [[String]] = [
    ["a\0b", "a"],
    ["\0", ""],
    ["%00", "\0"],
    ["a%00b", "a\0b"],
    ["%25", "%"],
    ["%2500", "%00"],
    ["trail\0", "trail"],
    ["\0lead", ""],
    ["a\0b", "a\0c", "a"],
    ["e\u{301}", "é\0\u{301}"],
    ["é", "e\u{301}\0x"],
  ]

  /// Byte sequences that are not well-formed UTF-8.
  ///
  /// None contains a null byte, because libxpc's C-string APIs would truncate
  /// the fixture and make the case vacuous rather than hostile.
  static let invalidUTF8Sequences: [[UInt8]] = [
    [0x80],
    [0xc3],
    [0xc3, 0x28],
    [0xc0, 0xaf],
    [0xe0, 0x80, 0x80],
    [0xe2, 0x82],
    [0xed, 0xa0, 0x80],
    [0xf0, 0x28, 0x8c, 0x28],
    [0xf5, 0x80, 0x80, 0x80],
    [0xfe],
    [0xff],
    [0x61, 0xff, 0x62],
  ]

  /// Percent-escape fragments the grammar must accept or reject exactly.
  static let escapeFragments: [[UInt8]] = [
    Array("%".utf8),
    Array("%0".utf8),
    Array("%00".utf8),
    Array("%25".utf8),
    Array("%41".utf8),
    Array("%GG".utf8),
    Array("%2500".utf8),
    Array("%\u{301}".utf8),
  ]

  /// The scalars generated strings are drawn from.
  static let scalarAlphabet: [Unicode.Scalar] = [
    "\0", "%", "A", "z", "0", "é", "\u{301}", "🚀", "中", "\u{FE0F}",
  ]

  /// The atoms every generated string set is seeded with.
  static let generatorAtoms: [String] = [
    "",
    "%",
    "%00",
    "%25",
    "%41",
    "\0",
    "a\0b",
    "e\u{301}",
    "é",
    "%\u{301}",
    "🚀",
  ]

}

// MARK: - Corpus Theme

struct CorpusTheme: Sendable {
  let name: String
  let descriptors: [ProbeDescriptor]
}

// MARK: - Historical Corpus

/// The checked-in, replayable inventory of every historical reproducer.
///
/// This typed Swift source is the reviewed origin; `Corpus/*.json` is its
/// durable replay form. `corpus verify` fails when the two disagree, so the JSON
/// is never silently regenerated to match new behavior.
enum HistoricalCorpus {

  static func themes() -> [CorpusTheme] {
    [
      CorpusTheme(name: "strings", descriptors: stringDescriptors()),
      CorpusTheme(name: "keys", descriptors: keyDescriptors()),
      CorpusTheme(name: "raw-text", descriptors: rawTextDescriptors()),
      CorpusTheme(name: "binary128", descriptors: binary128Descriptors()),
      CorpusTheme(name: "budgets", descriptors: budgetDescriptors()),
      CorpusTheme(name: "cycles", descriptors: cycleDescriptors()),
      CorpusTheme(name: "pointer-count", descriptors: pointerCountDescriptors()),
      CorpusTheme(name: "representation", descriptors: representationDescriptors()),
      CorpusTheme(name: "models", descriptors: modelDescriptors()),
      CorpusTheme(name: "deliberate-hang", descriptors: [deliberateHangDescriptor]),
    ]
  }

  /// Every case except the deliberate hanger, which only the timeout control
  /// may run.
  static func runnableDescriptors() -> [ProbeDescriptor] {
    themes().flatMap(\.descriptors).filter { $0.probe != .deliberateHang }
  }

  static let deliberateHangDescriptor = descriptor(
    id: "hang/never-returns",
    probe: .deliberateHang
  )

  // MARK: Strings

  private static func stringDescriptors() -> [ProbeDescriptor] {
    var descriptors: [ProbeDescriptor] = []
    let groups: [(String, [String])] = [
      ("audit-corpus", HistoricalStrings.auditCorpus),
      ("literal-percent", HistoricalStrings.literalPercentGroup),
      ("embedded-null", HistoricalStrings.nullGroup),
      ("combining-marks", HistoricalStrings.combiningMarkGroup),
      ("unicode-planes", HistoricalStrings.unicodePlaneGroup),
    ]
    for (groupName, strings) in groups {
      for strategy in StringStrategy.allCases {
        descriptors.append(
          descriptor(
            id: "strings/\(groupName)/\(strategy.rawValue)",
            probe: .distinctStrings(
              DistinctStringsProbe(strategy: strategy, strings: strings)
            )
          )
        )
      }
    }
    return descriptors
  }

  // MARK: Keys

  private static func keyDescriptors() -> [ProbeDescriptor] {
    var descriptors: [ProbeDescriptor] = []
    for (index, keys) in HistoricalStrings.collisionKeySets.enumerated() {
      for strategy in KeyStrategy.allCases {
        descriptors.append(
          descriptor(
            id: "keys/collision-\(index)/\(strategy.rawValue)",
            probe: .keyCollision(
              KeyCollisionProbe(strategy: strategy, keys: keys)
            )
          )
        )
      }
    }
    let broadGroups: [(String, [String])] = [
      ("audit-corpus", HistoricalStrings.auditCorpus),
      ("combining-marks", HistoricalStrings.combiningMarkGroup),
      ("unicode-planes", HistoricalStrings.unicodePlaneGroup),
      ("literal-percent", HistoricalStrings.literalPercentGroup),
    ]
    for (groupName, keys) in broadGroups {
      descriptors.append(
        descriptor(
          id: "keys/\(groupName)/percentEscape",
          probe: .keyCollision(
            KeyCollisionProbe(strategy: .percentEscape, keys: keys)
          )
        )
      )
    }
    return descriptors
  }

  // MARK: Raw External Text

  private static func rawTextDescriptors() -> [ProbeDescriptor] {
    var descriptors: [ProbeDescriptor] = []

    // Malformed UTF-8 must be rejected in both positions under both strategies,
    // never repaired with U+FFFD.
    for (index, bytes) in HistoricalStrings.invalidUTF8Sequences.enumerated() {
      for location in RawTextLocation.allCases {
        for strategy in RawTextStrategy.allCases {
          descriptors.append(
            descriptor(
              id: "raw-text/invalid-utf8-\(index)/\(location.rawValue)/\(strategy.rawValue)",
              probe: .rawText(
                RawTextProbe(
                  location: location,
                  strategy: strategy,
                  bytes: bytes,
                  expectation: .reject,
                  expectedScalars: nil
                )
              )
            )
          )
        }
      }
    }

    // The percent-escape grammar accepts only `%00` and `%25` and is not
    // recursive; `.passthrough` applies no escape grammar at all.
    for (index, escapeCase) in escapeGrammarCases.enumerated() {
      for location in RawTextLocation.allCases {
        descriptors.append(
          descriptor(
            id: "raw-text/escape-\(index)/percentEscape/\(location.rawValue)",
            probe: .rawText(
              RawTextProbe(
                location: location,
                strategy: .percentEscape,
                bytes: Array(escapeCase.raw.utf8),
                expectation: escapeCase.escaped == nil ? .reject : .pass,
                expectedScalars: escapeCase.escaped.map(scalarValues)
              )
            )
          )
        )
        descriptors.append(
          descriptor(
            id: "raw-text/escape-\(index)/passthrough/\(location.rawValue)",
            probe: .rawText(
              RawTextProbe(
                location: location,
                strategy: .passthrough,
                bytes: Array(escapeCase.raw.utf8),
                expectation: .pass,
                expectedScalars: scalarValues(escapeCase.raw)
              )
            )
          )
        )
      }
    }
    return descriptors
  }

  /// Raw XPC text and the text `.percentEscape` must produce, or `nil` when the
  /// grammar must reject it.
  private static let escapeGrammarCases: [(raw: String, escaped: String?)] = [
    (raw: "plain", escaped: "plain"),
    (raw: "%00", escaped: "\0"),
    (raw: "%25", escaped: "%"),
    (raw: "%2500", escaped: "%00"),
    (raw: "%0025", escaped: "\u{0}25"),
    (raw: "a%00b", escaped: "a\0b"),
    (raw: "%00%00", escaped: "\0\0"),
    (raw: "%25%00", escaped: "%\0"),
    (raw: "e\u{301}%25", escaped: "e\u{301}%"),
    (raw: "%", escaped: nil),
    (raw: "%0", escaped: nil),
    (raw: "%41", escaped: nil),
    (raw: "%GG", escaped: nil),
    (raw: "%%", escaped: nil),
    (raw: "100%", escaped: nil),
    (raw: "a%20b", escaped: nil),
    (raw: "%\u{301}", escaped: nil),
    (raw: "x%\u{301}41", escaped: nil),
    (raw: "%0G", escaped: nil),
    (raw: "%2", escaped: nil),
  ]

  private static func scalarValues(_ string: String) -> [UInt32] {
    string.unicodeScalars.map(\.value)
  }

  // MARK: 128-Bit Integers

  private static func binary128Descriptors() -> [ProbeDescriptor] {
    var descriptors: [ProbeDescriptor] = []
    let byteCounts = [0, 1, 8, 15, 16, 17, 24, 32]
    for type in Binary128Type.allCases {
      for byteCount in byteCounts {
        for unaligned in [false, true] {
          let probe = Binary128Probe(
            type: type,
            bytes: Data(
              (0..<byteCount).map { UInt8(truncatingIfNeeded: 0x11 &* ($0 &+ 1)) }
            ),
            unaligned: unaligned,
            expectation: .pass
          )
          descriptors.append(
            descriptor(
              id: """
                binary128/\(type.rawValue)/\(byteCount)-bytes/\
                \(unaligned ? "offset" : "aligned")
                """,
              probe: .binary128(
                Binary128Probe(
                  type: probe.type,
                  bytes: probe.bytes,
                  unaligned: probe.unaligned,
                  expectation: probe.derivedExpectation
                )
              )
            )
          )
        }
      }
    }
    return descriptors
  }

  // MARK: Budgets

  private static func budgetDescriptors() -> [ProbeDescriptor] {
    var descriptors: [ProbeDescriptor] = []
    // A limit above one keeps `limit - 1` meaningful for every resource,
    // including `maximumTotalNodeCount`, whose floor is one.
    let limits: [ResourceKind: Int] = [
      .depth: 8,
      .breadth: 12,
      .totalNodes: 10,
      .stringBytes: 16,
      .dataBytes: 16,
      .cumulativeBytes: 24,
    ]
    for resource in ResourceKind.allCases {
      guard let limit = limits[resource] else {
        continue
      }
      for (offsetName, offset) in [("limit-minus-one", -1), ("limit", 0), ("limit-plus-one", 1)] {
        let probe = ResourceBoundaryProbe(
          resource: resource,
          limit: limit,
          observed: limit + offset,
          expectation: .pass
        )
        descriptors.append(
          descriptor(
            id: "budgets/\(resource.rawValue)/\(offsetName)",
            probe: .resourceBoundary(
              ResourceBoundaryProbe(
                resource: probe.resource,
                limit: probe.limit,
                observed: probe.observed,
                expectation: probe.derivedExpectation
              )
            )
          )
        )
      }
    }

    // A zero ceiling permits no use of the resource at all.
    for resource in ResourceKind.allCases {
      for observed in [0, 1] {
        let probe = ResourceBoundaryProbe(
          resource: resource,
          limit: 0,
          observed: observed,
          expectation: .pass
        )
        descriptors.append(
          descriptor(
            id: "budgets/\(resource.rawValue)/zero-limit-observed-\(observed)",
            probe: .resourceBoundary(
              ResourceBoundaryProbe(
                resource: probe.resource,
                limit: probe.limit,
                observed: probe.observed,
                expectation: probe.derivedExpectation
              )
            )
          )
        )
      }
    }
    return descriptors
  }

  // MARK: Cycles

  private static func cycleDescriptors() -> [ProbeDescriptor] {
    CycleShape.allCases.map { shape in
      descriptor(
        id: "cycles/\(shape.rawValue)",
        probe: .cycle(
          CycleProbe(
            shape: shape,
            expectation: shape.isCyclic ? .reject : .pass
          )
        )
      )
    }
  }

  // MARK: Unsafe Pointer/Count

  private static func pointerCountDescriptors() -> [ProbeDescriptor] {
    var descriptors: [ProbeDescriptor] = []
    // `-1`, `0`, and `1` are the documented contract boundaries; the last is the
    // probe's full initialized extent. Nothing larger is generated, because a
    // raw pointer carries no extent metadata to validate against.
    let counts = [-1, 0, 1, pointerProbeBytes.count]
    for shape in PointerContainerShape.allCases {
      for mutable in [false, true] {
        for suppliesPointer in [false, true] {
          for count in counts {
            let probe = PointerCountProbe(
              shape: shape,
              suppliesPointer: suppliesPointer,
              mutable: mutable,
              count: count,
              expectation: .pass
            )
            descriptors.append(
              descriptor(
                id: """
                  pointer-count/\(shape.rawValue)/\
                  \(mutable ? "mutable" : "immutable")/\
                  \(suppliesPointer ? "nonnil" : "nil")/count-\(count)
                  """,
                probe: .pointerCount(
                  PointerCountProbe(
                    shape: probe.shape,
                    suppliesPointer: probe.suppliesPointer,
                    mutable: probe.mutable,
                    count: probe.count,
                    expectation: probe.derivedExpectation
                  )
                )
              )
            )
          }
        }
      }
    }
    return descriptors
  }

  // MARK: Primitive Representation

  private static func representationDescriptors() -> [ProbeDescriptor] {
    var descriptors: [ProbeDescriptor] = []

    for byteCount in [0, 1, 16, 1_024] {
      descriptors.append(
        representationDescriptor(
          id: "representation/data/\(byteCount)-bytes",
          kind: .data,
          bytes: Data((0..<byteCount).map { UInt8(truncatingIfNeeded: $0) })
        )
      )
    }

    for (name, value) in [
      ("min", Int64(Int16.min)),
      ("negative-one", -1),
      ("zero", 0),
      ("one", 1),
      ("max", Int64(Int16.max)),
    ] {
      descriptors.append(
        representationDescriptor(
          id: "representation/int16/\(name)",
          kind: .signedNarrow,
          signed: value
        )
      )
    }

    for (name, value) in [
      ("min", UInt64(UInt16.min)),
      ("one", 1),
      ("max", UInt64(UInt16.max)),
    ] {
      descriptors.append(
        representationDescriptor(
          id: "representation/uint16/\(name)",
          kind: .unsignedNarrow,
          unsigned: value
        )
      )
    }

    for (name, value) in floatSpecialValues {
      descriptors.append(
        representationDescriptor(
          id: "representation/float32/\(name)",
          kind: .float32,
          floatBits: value.bitPattern
        )
      )
    }

    for (name, value) in float16SpecialValues {
      descriptors.append(
        representationDescriptor(
          id: "representation/float16/\(name)",
          kind: .float16,
          floatBits: UInt32(value.bitPattern)
        )
      )
    }

    for (name, value) in doubleSpecialValues {
      descriptors.append(
        representationDescriptor(
          id: "representation/double/\(name)",
          kind: .doubleValue,
          doubleBits: value.bitPattern
        )
      )
    }
    return descriptors
  }

  private static let floatSpecialValues: [(String, Float)] = [
    ("zero", 0),
    ("negative-zero", -0.0),
    ("one", 1),
    ("least-nonzero", .leastNonzeroMagnitude),
    ("least-normal", .leastNormalMagnitude),
    ("greatest-finite", .greatestFiniteMagnitude),
    ("infinity", .infinity),
    ("negative-infinity", -.infinity),
    ("nan", .nan),
    ("signaling-nan", .signalingNaN),
  ]

  private static let float16SpecialValues: [(String, Float16)] = [
    ("zero", 0),
    ("negative-zero", -0.0),
    ("one", 1),
    ("least-nonzero", .leastNonzeroMagnitude),
    ("greatest-finite", .greatestFiniteMagnitude),
    ("infinity", .infinity),
    ("nan", .nan),
  ]

  private static let doubleSpecialValues: [(String, Double)] = [
    ("zero", 0),
    ("negative-zero", -0.0),
    ("one", 1),
    ("least-nonzero", .leastNonzeroMagnitude),
    ("greatest-finite", .greatestFiniteMagnitude),
    ("infinity", .infinity),
    ("negative-infinity", -.infinity),
    ("nan", .nan),
    ("signaling-nan", .signalingNaN),
  ]

  private static func representationDescriptor(
    id: String,
    kind: RepresentationKind,
    bytes: Data = Data(),
    signed: Int64 = 0,
    unsigned: UInt64 = 0,
    floatBits: UInt32 = 0,
    doubleBits: UInt64 = 0
  ) -> ProbeDescriptor {
    descriptor(
      id: id,
      probe: .representation(
        RepresentationProbe(
          kind: kind,
          bytes: bytes,
          signed: signed,
          unsigned: unsigned,
          floatBits: floatBits,
          doubleBits: doubleBits
        )
      )
    )
  }

  // MARK: Models

  private static func modelDescriptors() -> [ProbeDescriptor] {
    StringStrategy.allCases.flatMap { strategy in
      [
        ("hostile-strings", hostileModel),
        ("empty", emptyModel),
      ].map { name, value in
        descriptor(
          id: "models/\(name)/\(strategy.rawValue)",
          probe: .model(ModelProbe(strategy: strategy, value: value))
        )
      }
    }
  }

  private static let hostileModel = FuzzModel(
    string: "a\0b%25%\u{301}🚀",
    // Only one of `"e\u{301}"` and `"é"` appears: Swift `String` equality is
    // canonical equivalence, so they are the same dictionary key. Scalar-exact
    // preservation of each form is asserted by the string probes instead.
    dictionary: [
      "a\0b": -1,
      "a": 0,
      "%00": 1,
      "%": 2,
      "e\u{301}": 3,
      "": 5,
    ],
    signed: .min,
    unsigned: .max,
    floatingPoint: -0.5,
    data: Data([0x00, 0xff, 0x25, 0x00]),
    numbers: [.min, -1, 0, 1, .max],
    child: FuzzChild(label: "child\0%", enabled: true)
  )

  private static let emptyModel = FuzzModel(
    string: "",
    dictionary: [:],
    signed: 0,
    unsigned: 0,
    floatingPoint: 0,
    data: Data(),
    numbers: [],
    child: nil
  )

  // MARK: Identity

  private static func descriptor(
    id: String,
    probe: Probe
  ) -> ProbeDescriptor {
    ProbeDescriptor(
      id: id,
      origin: "historical-corpus",
      seed: stableSeed(for: id),
      probe: probe
    )
  }

  /// A stable seed derived from the case identifier.
  ///
  /// Historical cases are not seed-generated, but giving them a seed keeps every
  /// diagnostic, artifact, and replay command uniform.
  static func stableSeed(for id: String) -> UInt64 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in id.utf8 {
      hash ^= UInt64(byte)
      hash &*= 0x0000_0100_0000_01b3
    }
    return hash
  }

}
