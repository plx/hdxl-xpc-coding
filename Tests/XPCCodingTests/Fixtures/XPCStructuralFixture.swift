import Foundation
import XPC

/// A deterministic, test-only description of the XPC object kinds and values
/// in XPCCoding's active same-build representation.
///
/// This is deliberately not `Codable`, persisted, versioned, or exposed by the
/// library. Fixture values are reviewed Swift source. They describe XPC object
/// trees for the co-built target and never libxpc's opaque serialized bytes.
indirect enum XPCStructuralFixture: Equatable {

  case null
  case bool(Bool)
  case int64(Int64)
  case uint64(UInt64)
  case double(XPCStructuralDouble)
  case string(String)
  case data([UInt8])
  case array([Self])
  case dictionary(entries: [XPCStructuralDictionaryEntry])

  static func double(_ value: Double) -> Self {
    .double(XPCStructuralDouble(value))
  }

  /// Creates a dictionary fixture with its entries sorted by physical XPC key.
  static func dictionary(_ values: [String: Self]) -> Self {
    .dictionary(
      entries:
        values
        .map(XPCStructuralDictionaryEntry.init)
        .sorted { lhs, rhs in
          lhs.key < rhs.key
        }
    )
  }

  /// Reads a complete supported XPC object tree without using `XPCDecoder`.
  init(inspecting object: xpc_object_t) throws {
    switch xpc_get_type(object) {
    case XPC_TYPE_NULL:
      self = .null
    case XPC_TYPE_BOOL:
      self = .bool(xpc_bool_get_value(object))
    case XPC_TYPE_INT64:
      self = .int64(xpc_int64_get_value(object))
    case XPC_TYPE_UINT64:
      self = .uint64(xpc_uint64_get_value(object))
    case XPC_TYPE_DOUBLE:
      self = .double(XPCStructuralDouble(xpc_double_get_value(object)))
    case XPC_TYPE_STRING:
      guard
        let pointer = xpc_string_get_string_ptr(object),
        let value = String(
          validatingCString: pointer
        )
      else {
        throw XPCStructuralFixtureError.invalidUTF8String
      }
      self = .string(value)
    case XPC_TYPE_DATA:
      self = .data(try Self.copyDataBytes(from: object))
    case XPC_TYPE_ARRAY:
      var elements: [Self] = []
      let count = xpc_array_get_count(object)
      elements.reserveCapacity(count)
      for index in 0..<count {
        elements.append(
          try Self(
            inspecting: xpc_array_get_value(
              object,
              index
            )
          )
        )
      }
      self = .array(elements)
    case XPC_TYPE_DICTIONARY:
      var entries: [XPCStructuralDictionaryEntry] = []
      entries.reserveCapacity(xpc_dictionary_get_count(object))
      var inspectionError: (any Error)?
      xpc_dictionary_apply(object) { keyPointer, value in
        guard inspectionError == nil else {
          return false
        }
        guard
          let key = String(
            validatingCString: keyPointer
          )
        else {
          inspectionError = XPCStructuralFixtureError.invalidUTF8DictionaryKey
          return false
        }
        do {
          entries.append(
            XPCStructuralDictionaryEntry(
              key: key,
              value: try Self(inspecting: value)
            )
          )
          return true
        } catch {
          inspectionError = error
          return false
        }
      }
      if let inspectionError {
        throw inspectionError
      }
      entries.sort { lhs, rhs in
        lhs.key < rhs.key
      }
      self = .dictionary(entries: entries)
    default:
      throw XPCStructuralFixtureError.unsupportedXPCObjectType
    }
  }

  /// Constructs a fresh XPC object tree without using `XPCEncoder`.
  func makeXPCObject() throws -> xpc_object_t {
    switch self {
    case .null:
      return xpc_null_create()
    case .bool(let value):
      return xpc_bool_create(value)
    case .int64(let value):
      return xpc_int64_create(value)
    case .uint64(let value):
      return xpc_uint64_create(value)
    case .double(let value):
      return xpc_double_create(value.representativeValue)
    case .string(let value):
      return try Self.makeXPCString(value)
    case .data(let bytes):
      return bytes.withUnsafeBytes { buffer in
        xpc_data_create(
          buffer.baseAddress,
          buffer.count
        )
      }
    case .array(let elements):
      let array = xpc_array_create_empty()
      for element in elements {
        xpc_array_append_value(
          array,
          try element.makeXPCObject()
        )
      }
      return array
    case .dictionary(let entries):
      let dictionary = xpc_dictionary_create_empty()
      for entry in entries {
        guard !entry.key.utf8.contains(0) else {
          throw XPCStructuralFixtureError.embeddedNullDictionaryKey
        }
        let value = try entry.value.makeXPCObject()
        entry.key.withCString { keyPointer in
          xpc_dictionary_set_value(
            dictionary,
            keyPointer,
            value
          )
        }
      }
      return dictionary
    }
  }

  private static func copyDataBytes(
    from object: xpc_object_t
  ) throws -> [UInt8] {
    let count = xpc_data_get_length(object)
    guard count > 0 else {
      return []
    }
    var bytes = [UInt8](repeating: 0, count: count)
    let copiedCount = bytes.withUnsafeMutableBytes { buffer in
      guard let baseAddress = buffer.baseAddress else {
        return 0
      }
      return xpc_data_get_bytes(
        object,
        baseAddress,
        0,
        count
      )
    }
    guard copiedCount == count else {
      throw XPCStructuralFixtureError.incompleteDataCopy(
        expected: count,
        actual: copiedCount
      )
    }
    return bytes
  }

  private static func makeXPCString(
    _ value: String
  ) throws -> xpc_object_t {
    guard !value.utf8.contains(0) else {
      throw XPCStructuralFixtureError.embeddedNullString
    }
    return value.withCString { pointer in
      xpc_string_create(pointer)
    }
  }

}

struct XPCStructuralDictionaryEntry: Equatable {

  let key: String
  let value: XPCStructuralFixture

  init(
    key: String,
    value: XPCStructuralFixture
  ) {
    self.key = key
    self.value = value
  }

  init(_ keyAndValue: (key: String, value: XPCStructuralFixture)) {
    self.init(
      key: keyAndValue.key,
      value: keyAndValue.value
    )
  }

}

enum XPCStructuralDouble: Equatable {

  case exact(bitPattern: UInt64)
  case nan

  init(_ value: Double) {
    self =
      value.isNaN
      ? .nan
      : .exact(bitPattern: value.bitPattern)
  }

  var representativeValue: Double {
    switch self {
    case .exact(let bitPattern):
      Double(bitPattern: bitPattern)
    case .nan:
      .nan
    }
  }

}

enum XPCStructuralFixtureError: Error, Equatable {

  case embeddedNullDictionaryKey
  case embeddedNullString
  case incompleteDataCopy(expected: Int, actual: Int)
  case invalidUTF8DictionaryKey
  case invalidUTF8String
  case unsupportedXPCObjectType

}

extension XPCStructuralFixture: CustomStringConvertible {

  var description: String {
    render(indentation: 0)
  }

  private func render(indentation: Int) -> String {
    switch self {
    case .null:
      "null"
    case .bool(let value):
      "bool(\(value))"
    case .int64(let value):
      "int64(\(value))"
    case .uint64(let value):
      "uint64(\(value))"
    case .double(.nan):
      "double(nan)"
    case .double(.exact(let bitPattern)):
      "double(bitPattern: \(Self.hex(bitPattern)))"
    case .string(let value):
      "string(\(String(reflecting: value)))"
    case .data(let bytes):
      "data([\(bytes.map(Self.hex).joined(separator: " "))])"
    case .array(let elements):
      renderCollection(
        opening: "array[",
        values: elements.map {
          $0.render(indentation: indentation + 2)
        },
        closing: "]",
        indentation: indentation
      )
    case .dictionary(let entries):
      renderCollection(
        opening: "dictionary{",
        values: entries.map {
          "\(String(reflecting: $0.key)): \($0.value.render(indentation: indentation + 2))"
        },
        closing: "}",
        indentation: indentation
      )
    }
  }

  private func renderCollection(
    opening: String,
    values: [String],
    closing: String,
    indentation: Int
  ) -> String {
    guard !values.isEmpty else {
      return "\(opening)\(closing)"
    }
    let childIndentation = String(
      repeating: " ",
      count: indentation + 2
    )
    let closingIndentation = String(
      repeating: " ",
      count: indentation
    )
    return """
      \(opening)
      \(childIndentation)\(values.joined(separator: ",\n\(childIndentation)"))
      \(closingIndentation)\(closing)
      """
  }

  private static func hex(_ byte: UInt8) -> String {
    String(
      format: "%02x",
      byte
    )
  }

  private static func hex(_ value: UInt64) -> String {
    String(
      format: "0x%016llx",
      value
    )
  }

}
