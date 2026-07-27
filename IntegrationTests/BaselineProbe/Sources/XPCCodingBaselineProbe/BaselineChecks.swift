import Dispatch
import Foundation
@preconcurrency import XPC
import XPCCoding

// MARK: - Inventory

/// The historical defects this probe demonstrates.
///
/// Every check drives only public API that existed at the baseline revision, so
/// these sources compile and link against either revision without a conditional
/// or a shim. The revision changes; the experiment does not.
///
/// Coverage is bounded on purpose. A defect earns a check when it can be
/// demonstrated deterministically and safely through the baseline's own public
/// API. Defects whose observable difference is a coding path, an error's
/// identity, or a concurrency property are left to the current-revision test
/// suites, which can name the corrected behavior directly.
enum BaselineChecks {

  static let all: [BaselineCheck] =
    percentEscapeChecks
    + keyInjectivityChecks
    + externalUTF8Checks
    + representationChecks
    + crashProneChecks
    + controlChecks

  static func check(id: String) throws -> BaselineCheck {
    guard let match = all.first(where: { $0.id == id }) else {
      throw BaselineError("No check has the identifier `\(id)`.")
    }
    return match
  }

  /// Confirms the inventory is capable of being evidence at all.
  ///
  /// A defect check whose two expectation sets overlap would pass at both
  /// revisions and prove nothing; a control whose sets differ is not a control.
  /// Both mistakes are silent at run time, so they are checked before any child
  /// starts.
  static func validateInventory() throws {
    var problems: [String] = []
    var seen: Set<String> = []
    for check in all {
      if !seen.insert(check.id).inserted {
        problems.append("duplicate check identifier `\(check.id)`")
      }
      if check.atBaseline.isEmpty || check.atCurrent.isEmpty {
        problems.append("`\(check.id)` has an empty expectation set")
      }
      switch check.isControl {
      case false where !check.atBaseline.isDisjoint(with: check.atCurrent):
        problems.append(
          """
          `\(check.id)` expects overlapping outcomes at both revisions, so it \
          cannot distinguish them
          """
        )
      case true where check.atBaseline != check.atCurrent:
        problems.append(
          "control `\(check.id)` expects different outcomes at each revision"
        )
      default:
        break
      }
    }
    guard problems.isEmpty else {
      throw BaselineError(
        """
        The baseline check inventory is not valid evidence:
          - \(problems.joined(separator: "\n  - "))
        """
      )
    }
  }

  // MARK: Percent Escaping

  /// Issue #7: `.percentEscape` escaped only when a null byte was present but
  /// unescaped unconditionally, so every literal percent sequence decoded as
  /// though it had been escaped.
  private static let percentEscapeChecks: [BaselineCheck] = [
    roundTripCheck(
      id: "percent-escape/escaped-null-literal",
      value: "%00",
      baseline: .violatedContract
    ),
    roundTripCheck(
      id: "percent-escape/escaped-percent-literal",
      value: "%25",
      baseline: .violatedContract
    ),
    roundTripCheck(
      id: "percent-escape/uppercase-a-escape",
      value: "%41",
      baseline: .violatedContract
    ),
    roundTripCheck(
      id: "percent-escape/double-escaped-null",
      value: "%2500",
      baseline: .violatedContract
    ),
    roundTripCheck(
      id: "percent-escape/space-escape",
      value: "a%20b",
      baseline: .violatedContract
    ),
    roundTripCheck(
      id: "percent-escape/bare-percent",
      value: "%",
      baseline: .typedRejection
    ),
    roundTripCheck(
      id: "percent-escape/trailing-percent",
      value: "100%",
      baseline: .typedRejection
    ),
    roundTripCheck(
      id: "percent-escape/percent-combining-mark",
      value: "%\u{301}",
      baseline: .typedRejection
    ),
  ]

  private static func roundTripCheck(
    id: String,
    value: String,
    baseline: CheckOutcome
  ) -> BaselineCheck {
    BaselineCheck(
      id: id,
      summary: "round-trips \(scalarList(value)) under .percentEscape",
      defect: "#7 percent escaping was not bijective",
      atBaseline: [baseline],
      atCurrent: [.matchedContract],
      body: {
        let object = try percentEscapeEncoder().encode(value)
        let decoded = try percentEscapeDecoder().decode(String.self, from: object)
        let exact = Array(decoded.unicodeScalars) == Array(value.unicodeScalars)
        return CheckObservation(
          exact ? .matchedContract : .violatedContract,
          "\(scalarList(value)) decoded as \(scalarList(decoded))"
        )
      }
    )
  }

  // MARK: Key Injectivity

  /// Issue #7, in its data-loss form: two distinct Swift keys collapsed onto one
  /// XPC dictionary key, silently discarding an entry.
  private static let keyInjectivityChecks: [BaselineCheck] = [
    keyInjectivityCheck(
      id: "percent-escape/key-collision-escaped-null",
      keys: ["%00", "\0"]
    ),
    keyInjectivityCheck(
      id: "percent-escape/key-collision-embedded-null",
      keys: ["a%00b", "a\0b"]
    ),
  ]

  private static func keyInjectivityCheck(
    id: String,
    keys: [String]
  ) -> BaselineCheck {
    BaselineCheck(
      id: id,
      summary: "keeps \(keys.map(scalarList).joined(separator: " and ")) distinct",
      defect: "#7 distinct keys aliased under .percentEscape",
      atBaseline: [.violatedContract],
      atCurrent: [.matchedContract],
      body: {
        let source = Dictionary(
          uniqueKeysWithValues: keys.enumerated().map { ($0.element, $0.offset) }
        )
        let object = try percentEscapeEncoder().encode(source)
        let observed = xpc_dictionary_get_count(object)
        return CheckObservation(
          observed == source.count ? .matchedContract : .violatedContract,
          "\(source.count) distinct keys encoded to \(observed) XPC entries"
        )
      }
    )
  }

  // MARK: External UTF-8

  /// Issue #16: XPC string extraction discarded the known length and used a
  /// lossy `String(cString:)`, repairing malformed UTF-8 into U+FFFD instead of
  /// rejecting it.
  ///
  /// Any completion at all is a violation here: these bytes are not well-formed
  /// UTF-8, so the only correct outcome is a typed rejection.
  private static let externalUTF8Checks: [BaselineCheck] = [
    externalUTF8Check(
      id: "external-utf8/lone-continuation-value",
      bytes: [0x80],
      isKey: false
    ),
    externalUTF8Check(
      id: "external-utf8/surrogate-value",
      bytes: [0xed, 0xa0, 0x80],
      isKey: false
    ),
    externalUTF8Check(
      id: "external-utf8/interior-invalid-value",
      bytes: [0x61, 0xff, 0x62],
      isKey: false
    ),
    externalUTF8Check(
      id: "external-utf8/truncated-sequence-key",
      bytes: [0xc3, 0x28],
      isKey: true
    ),
  ]

  private static func externalUTF8Check(
    id: String,
    bytes: [UInt8],
    isKey: Bool
  ) -> BaselineCheck {
    BaselineCheck(
      id: id,
      summary: """
        rejects the malformed UTF-8 \(byteList(bytes)) as a dictionary \
        \(isKey ? "key" : "value")
        """,
      defect: "#16 malformed external UTF-8 was repaired instead of rejected",
      atBaseline: [.violatedContract],
      atCurrent: [.typedRejection],
      body: {
        let decoded: String
        switch isKey {
        case true:
          let keys = try percentEscapeDecoder().decode(
            AllKeysProbe.self,
            from: xpcDictionary(key: bytes, value: xpc_int64_create(1))
          ).keys
          guard let first = keys.first, keys.count == 1 else {
            throw BaselineError(
              "One XPC dictionary key decoded to \(keys.count) coding keys."
            )
          }
          decoded = first
        case false:
          decoded = try percentEscapeDecoder().decode(
            String.self,
            from: xpcString(bytes: bytes)
          )
        }
        return CheckObservation(
          .violatedContract,
          "\(byteList(bytes)) was accepted as \(scalarList(decoded))"
        )
      }
    )
  }

  // MARK: Representation

  /// Issues #20, #22, and #23: `Data` became one XPC object per byte, and the
  /// narrow numeric types became raw native bytes in an XPC data object rather
  /// than the XPC scalars the representation contract now names.
  private static let representationChecks: [BaselineCheck] = [
    representationCheck(
      id: "representation/data-single-object",
      summary: "encodes Data as one XPC data object",
      defect: "#20 ordinary Data became one XPC object per byte",
      expected: { XPC_TYPE_DATA },
      encode: { try XPCEncoder.standard.encode(Data([0x01, 0x02, 0x03, 0x04])) }
    ),
    representationCheck(
      id: "representation/int16-scalar",
      summary: "encodes Int16 as an XPC int64",
      defect: "#22 narrow integers were raw native bytes",
      expected: { XPC_TYPE_INT64 },
      encode: { try XPCEncoder.standard.encode(Int16(-3)) }
    ),
    representationCheck(
      id: "representation/uint16-scalar",
      summary: "encodes UInt16 as an XPC uint64",
      defect: "#22 narrow integers were raw native bytes",
      expected: { XPC_TYPE_UINT64 },
      encode: { try XPCEncoder.standard.encode(UInt16(7)) }
    ),
    representationCheck(
      id: "representation/float-scalar",
      summary: "encodes Float as an XPC double",
      defect: "#23 binary floating point was raw native bytes",
      expected: { XPC_TYPE_DOUBLE },
      encode: { try XPCEncoder.standard.encode(Float(1.5)) }
    ),
  ]

  /// Builds a check that requires an encoded value to have one XPC kind.
  ///
  /// The required kind arrives as a closure because `xpc_type_t` is an
  /// `OpaquePointer`, which the `Sendable` check body cannot capture.
  private static func representationCheck(
    id: String,
    summary: String,
    defect: String,
    expected: @escaping @Sendable () -> xpc_type_t,
    encode: @escaping @Sendable () throws -> xpc_object_t
  ) -> BaselineCheck {
    BaselineCheck(
      id: id,
      summary: summary,
      defect: defect,
      atBaseline: [.violatedContract],
      atCurrent: [.matchedContract],
      body: {
        let object = try encode()
        let expectedType = expected()
        let matched = xpc_get_type(object) == expectedType
        return CheckObservation(
          matched ? .matchedContract : .violatedContract,
          """
          encoded as XPC \(typeName(of: object)), expected \
          \(String(cString: xpc_type_get_name(expectedType)))
          """
        )
      }
    )
  }

  // MARK: Crash-Prone

  /// The three defects whose baseline manifestation is a dead process.
  ///
  /// Each of these runs only inside a supervised, bounded child, which is why
  /// this probe never executes a check in its own process.
  private static let crashProneChecks: [BaselineCheck] = [
    BaselineCheck(
      id: "alignment/offset-narrow-integer",
      summary: "decodes a narrow integer from offset XPC data storage",
      defect: "#8 binary numeric decoding loaded from an unaligned address",
      // The load is undefined behavior, not a guaranteed fault: on this
      // architecture an optimized build may complete it silently. The checked
      // build that `Scripts/run-baseline-evidence.sh` produces is what turns it
      // into the observable trap the audit recorded.
      atBaseline: [.crashed],
      // Today an Int16 is an XPC int64, so data of any alignment is a typed
      // type mismatch. Either safe answer satisfies the property under test,
      // which is that hostile storage never traps the process.
      atCurrent: [.typedRejection, .matchedContract],
      body: {
        let object = offsetXPCData(Data([0x34, 0x12]))
        guard let remainder = alignmentRemainder(of: object, modulo: 2) else {
          throw BaselineError("The offset XPC data object exposed no pointer.")
        }
        guard remainder != 0 else {
          throw BaselineError(
            """
            libxpc realigned the offset storage, so this check cannot \
            demonstrate an unaligned load on this host.
            """
          )
        }
        let value = try XPCDecoder.standard.decode(Int16.self, from: object)
        return CheckObservation(
          value == 0x1234 ? .matchedContract : .violatedContract,
          "decoded \(value) from storage at a 2-byte remainder of \(remainder)"
        )
      }
    ),
    BaselineCheck(
      id: "pointer-count/nil-pointer-positive-count",
      summary: "refuses a nil pointer with a positive count",
      defect: "#11 unsafe pointer/count pairs reached libxpc unvalidated",
      atBaseline: [.crashed],
      atCurrent: [.typedRejection],
      body: {
        // No allocation is involved and no extent is overrun: the pair is
        // exactly the documented misuse, `nil` with a count of one.
        let object = try XPCEncoder.standard.encode(
          RawPointerPayload(suppliesPointer: false, count: 1)
        )
        return CheckObservation(
          .violatedContract,
          """
          a nil pointer with a count of 1 was accepted as XPC \
          \(typeName(of: object)) of \(xpc_data_get_length(object)) bytes
          """
        )
      }
    ),
    BaselineCheck(
      id: "budgets/self-referential-array",
      summary: "refuses a self-referential XPC array",
      defect: "#9 the decoder recursed with no depth budget",
      atBaseline: CheckOutcome.terminated,
      atCurrent: [.typedRejection],
      body: {
        let array = xpc_array_create_empty()
        xpc_array_append_value(array, array)
        _ = try XPCDecoder.standard.decode(RecursiveArray.self, from: array)
        return CheckObservation(
          .violatedContract,
          "a self-referential array decoded to completion"
        )
      }
    ),
    BaselineCheck(
      id: "budgets/deep-nesting",
      summary: "refuses \(deepNestingEdgeCount) nested XPC arrays",
      defect: "#9 the decoder recursed with no depth budget",
      atBaseline: CheckOutcome.terminated,
      atCurrent: [.typedRejection],
      body: {
        var root = xpc_array_create_empty()
        for _ in 0..<deepNestingEdgeCount {
          let parent = xpc_array_create_empty()
          xpc_array_append_value(parent, root)
          root = parent
        }
        _ = try XPCDecoder.standard.decode(RecursiveArray.self, from: root)
        return CheckObservation(
          .violatedContract,
          "\(deepNestingEdgeCount) nested arrays decoded to completion"
        )
      }
    ),
  ]

  /// Deep enough to exhaust the baseline's stack, small enough to build and
  /// reject well inside the child's ceilings.
  private static let deepNestingEdgeCount = 5_000

  // MARK: Controls

  /// Behavior both revisions must share.
  ///
  /// Without these, a probe that broke every operation — or one linked against
  /// the wrong revision — would still look like a clean sweep of defects.
  private static let controlChecks: [BaselineCheck] = [
    BaselineCheck(
      id: "control/plain-string-round-trip",
      summary: "round-trips a string with no percent sign and no null",
      defect: nil,
      atBaseline: [.matchedContract],
      atCurrent: [.matchedContract],
      body: {
        let value = "plain"
        let object = try percentEscapeEncoder().encode(value)
        let decoded = try percentEscapeDecoder().decode(String.self, from: object)
        return CheckObservation(
          decoded == value ? .matchedContract : .violatedContract,
          "\(scalarList(value)) decoded as \(scalarList(decoded))"
        )
      }
    ),
    BaselineCheck(
      id: "control/embedded-null-string-round-trip",
      summary: "round-trips an embedded null, which .percentEscape always did",
      defect: nil,
      atBaseline: [.matchedContract],
      atCurrent: [.matchedContract],
      body: {
        let value = "a\0b"
        let object = try percentEscapeEncoder().encode(value)
        let decoded = try percentEscapeDecoder().decode(String.self, from: object)
        let exact = Array(decoded.unicodeScalars) == Array(value.unicodeScalars)
        return CheckObservation(
          exact ? .matchedContract : .violatedContract,
          "\(scalarList(value)) decoded as \(scalarList(decoded))"
        )
      }
    ),
    pointerCountControl(
      id: "control/pointer-count-nil-zero-count",
      suppliesPointer: false,
      count: 0
    ),
    pointerCountControl(
      id: "control/pointer-count-full-extent",
      suppliesPointer: true,
      count: rawPointerProbeBytes.count
    ),
  ]

  private static func pointerCountControl(
    id: String,
    suppliesPointer: Bool,
    count: Int
  ) -> BaselineCheck {
    BaselineCheck(
      id: id,
      summary: """
        encodes a \(suppliesPointer ? "non-nil" : "nil") pointer with a count \
        of \(count)
        """,
      defect: nil,
      atBaseline: [.matchedContract],
      atCurrent: [.matchedContract],
      body: {
        let object = try XPCEncoder.standard.encode(
          RawPointerPayload(suppliesPointer: suppliesPointer, count: count)
        )
        let expected = Data(rawPointerProbeBytes.prefix(count))
        let matched =
          xpc_get_type(object) == XPC_TYPE_DATA && dataBytes(of: object) == expected
        return CheckObservation(
          matched ? .matchedContract : .violatedContract,
          """
          emitted XPC \(typeName(of: object)) of \
          \(xpc_data_get_length(object)) bytes, expected \(count)
          """
        )
      }
    )
  }

}

// MARK: - Coders

private func percentEscapeEncoder() -> XPCEncoder {
  XPCEncoder(
    stringKeyStrategy: .percentEscape,
    stringValueStrategy: .percentEscape
  )
}

private func percentEscapeDecoder() -> XPCDecoder {
  XPCDecoder(
    stringKeyStrategy: .percentEscape,
    stringValueStrategy: .percentEscape
  )
}

// MARK: - Fixtures

/// The initialized, readable storage the pointer/count checks borrow.
///
/// No check ever claims more bytes than this, because a raw pointer carries no
/// extent metadata and a larger count would be undefined behavior rather than a
/// test.
let rawPointerProbeBytes: [UInt8] = [0x2a, 0x63, 0xa5, 0x5a]

/// Encodes a raw pointer and count through the public enhanced-container API.
private struct RawPointerPayload: Encodable {
  let suppliesPointer: Bool
  let count: Int

  func encode(to encoder: any Encoder) throws {
    try rawPointerProbeBytes.withUnsafeBytes { buffer in
      var container = encoder.singleValueContainer()
      try container.efficientlyEncodeBinaryData(
        suppliesPointer ? buffer.baseAddress : nil,
        count: count
      )
    }
  }
}

/// Recurses through element zero of nested XPC arrays.
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

/// Reports the dictionary keys a decoder exposes, without filtering any.
private struct AllKeysProbe: Decodable {
  let keys: [String]

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: ProbeCodingKey.self)
    self.keys = container.allKeys.map(\.stringValue)
  }
}

private struct ProbeCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = Int(stringValue)
  }

  init(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

// MARK: - XPC Construction

/// Creates an XPC string from raw bytes.
///
/// - Precondition: `bytes` contains no null byte, which libxpc's C-string APIs
///   cannot carry.
private func xpcString(bytes: [UInt8]) -> xpc_object_t {
  precondition(
    !bytes.contains(0),
    "Raw XPC string bytes cannot contain a null byte."
  )
  return withNullTerminatedBytes(bytes) { xpc_string_create($0) }
}

private func xpcDictionary(
  key: [UInt8],
  value: xpc_object_t
) -> xpc_object_t {
  let dictionary = xpc_dictionary_create_empty()
  withNullTerminatedBytes(key) { xpc_dictionary_set_value(dictionary, $0, value) }
  return dictionary
}

/// Creates XPC data whose visible bytes start one byte into their storage.
///
/// The offset is a request, not a guarantee: libxpc may copy the source into
/// aligned storage. Callers measure what they actually got with
/// ``alignmentRemainder(of:modulo:)`` rather than assuming.
private func offsetXPCData(_ data: Data) -> xpc_object_t {
  var prefixed = Data([0x7f])
  prefixed.append(data)
  let dispatchData = prefixed.withUnsafeBytes { DispatchData(bytes: $0) }
  let slice = dispatchData.subdata(in: 1..<prefixed.count)
  return xpc_data_create_with_dispatch_data(slice as dispatch_data_t)
}

private func alignmentRemainder(
  of object: xpc_object_t,
  modulo alignment: Int
) -> Int? {
  guard let bytes = xpc_data_get_bytes_ptr(object) else {
    return nil
  }
  return Int(bitPattern: bytes) % alignment
}

private func dataBytes(of object: xpc_object_t) -> Data {
  let count = xpc_data_get_length(object)
  guard count > 0, let bytes = xpc_data_get_bytes_ptr(object) else {
    return Data()
  }
  return Data(bytes: bytes, count: count)
}

private func withNullTerminatedBytes<Result>(
  _ bytes: [UInt8],
  _ body: (UnsafePointer<CChar>) -> Result
) -> Result {
  var terminated = bytes.map { CChar(bitPattern: $0) }
  terminated.append(0)
  return terminated.withUnsafeBufferPointer { buffer in
    guard let baseAddress = buffer.baseAddress else {
      preconditionFailure("A null-terminated array always has a base address.")
    }
    return body(baseAddress)
  }
}

private func typeName(of object: xpc_object_t) -> String {
  String(cString: xpc_type_get_name(xpc_get_type(object)))
}

// MARK: - Descriptions

/// Renders a string as explicit scalar values.
///
/// Null and combining scalars are invisible or misleading in a transcript, and
/// this evidence is read from a log.
private func scalarList(_ value: String) -> String {
  let scalars = value.unicodeScalars.map { String(format: "U+%04X", $0.value) }
  return "[\(scalars.joined(separator: " "))]"
}

private func byteList(_ bytes: [UInt8]) -> String {
  "[\(bytes.map { String(format: "%02x", $0) }.joined(separator: " "))]"
}
