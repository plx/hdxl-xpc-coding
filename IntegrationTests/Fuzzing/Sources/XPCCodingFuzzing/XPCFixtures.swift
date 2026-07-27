import Darwin
import Dispatch
import Foundation
@preconcurrency import XPC

// MARK: - XPC Construction

/// Creates an XPC string from raw bytes.
///
/// - Precondition: `bytes` contains no null byte. libxpc's C-string APIs cannot
///   carry one, so a null would silently truncate the fixture and make the case
///   vacuous rather than hostile.
func xpcString(bytes: [UInt8]) -> xpc_object_t {
  precondition(
    !bytes.contains(0),
    "Raw XPC string bytes cannot contain a null byte."
  )
  return withNullTerminatedBytes(bytes) {
    xpc_string_create($0)
  }
}

func xpcArray(_ values: [xpc_object_t]) -> xpc_object_t {
  let result = xpc_array_create_empty()
  for value in values {
    xpc_array_append_value(result, value)
  }
  return result
}

func xpcDictionary(
  _ entries: [(key: [UInt8], value: xpc_object_t)]
) -> xpc_object_t {
  let result = xpc_dictionary_create_empty()
  for entry in entries {
    withNullTerminatedBytes(entry.key) { key in
      xpc_dictionary_set_value(result, key, entry.value)
    }
  }
  return result
}

/// Creates XPC data, optionally from storage that starts at a one-byte offset.
///
/// The offset request is best-effort: libxpc may copy or coalesce the source
/// into aligned storage. Callers therefore treat the observed alignment as an
/// observation to record, never as a precondition. Use
/// ``xpcDataAlignmentRemainder(_:)`` to record what actually happened.
func makeXPCData(
  _ data: Data,
  unaligned: Bool
) -> xpc_object_t {
  guard unaligned else {
    return data.withUnsafeBytes {
      xpc_data_create($0.baseAddress, $0.count)
    }
  }

  var prefixed = Data([0x7f])
  prefixed.append(data)
  let dispatchData = prefixed.withUnsafeBytes {
    DispatchData(bytes: $0)
  }
  let slice = dispatchData.subdata(in: 1..<prefixed.count)
  return xpc_data_create_with_dispatch_data(slice as dispatch_data_t)
}

/// The address remainder of an XPC data object's visible bytes for a 16-byte
/// alignment requirement, or `nil` when the object exposes no pointer.
func xpcDataAlignmentRemainder(_ object: xpc_object_t) -> Int? {
  guard let bytes = xpc_data_get_bytes_ptr(object) else {
    return nil
  }
  return Int(bitPattern: bytes) % 16
}

func dataBytes(_ object: xpc_object_t) -> Data {
  let count = xpc_data_get_length(object)
  guard count > 0, let bytes = xpc_data_get_bytes_ptr(object) else {
    return Data()
  }
  return Data(bytes: bytes, count: count)
}

func withNullTerminatedBytes<Result>(
  _ bytes: [UInt8],
  _ body: (UnsafePointer<CChar>) throws -> Result
) rethrows -> Result {
  var terminated = bytes.map { CChar(bitPattern: $0) }
  terminated.append(0)
  return try terminated.withUnsafeBufferPointer { buffer in
    guard let baseAddress = buffer.baseAddress else {
      preconditionFailure("A null-terminated array always has a base address.")
    }
    return try body(baseAddress)
  }
}

// MARK: - Graph Construction

/// Materializes a descriptor's node list as a real XPC object graph.
func makeGraph(_ graph: GraphProbe) throws -> xpc_object_t {
  guard !graph.nodes.isEmpty, graph.nodes.indices.contains(graph.root) else {
    throw ProbeFailure.invalidDescriptor("graph root is out of bounds")
  }

  let objects: [xpc_object_t] = graph.nodes.map { node in
    switch node {
    case .null:
      xpc_null_create()
    case .bool(let value):
      xpc_bool_create(value)
    case .signed(let value):
      xpc_int64_create(value)
    case .unsigned(let value):
      xpc_uint64_create(value)
    case .double(let value):
      xpc_double_create(value)
    case .data(let value):
      makeXPCData(value, unaligned: false)
    case .string(let bytes):
      xpcString(bytes: bytes)
    case .array:
      xpc_array_create_empty()
    case .dictionary:
      xpc_dictionary_create_empty()
    }
  }

  for (index, node) in graph.nodes.enumerated() {
    switch node {
    case .array(let children):
      for child in children {
        guard objects.indices.contains(child) else {
          throw ProbeFailure.invalidDescriptor("array edge is out of bounds")
        }
        xpc_array_append_value(objects[index], objects[child])
      }
    case .dictionary(let entries):
      for entry in entries {
        guard objects.indices.contains(entry.target) else {
          throw ProbeFailure.invalidDescriptor("dictionary edge is out of bounds")
        }
        guard !entry.key.contains(0) else {
          throw ProbeFailure.invalidDescriptor("dictionary key contains a null byte")
        }
        withNullTerminatedBytes(entry.key) { key in
          xpc_dictionary_set_value(objects[index], key, objects[entry.target])
        }
      }
    case .null, .bool, .signed, .unsigned, .double, .data, .string:
      break
    }
  }

  return objects[graph.root]
}

/// Builds the exact cycle or shared-reference topology named by a shape.
func makeCycleGraph(_ shape: CycleShape) -> xpc_object_t {
  switch shape {
  case .emptySelfArray:
    let array = xpc_array_create_empty()
    xpc_array_append_value(array, array)
    return array

  case .valueBearingSelfArray:
    let array = xpc_array_create_empty()
    xpc_array_append_value(array, array)
    xpc_array_append_value(array, xpc_int64_create(42))
    xpc_array_append_value(array, xpcString(bytes: Array("payload".utf8)))
    return array

  case .mutualArrays:
    let first = xpc_array_create_empty()
    let second = xpc_array_create_empty()
    xpc_array_append_value(first, second)
    xpc_array_append_value(second, first)
    return first

  case .selfDictionary:
    let dictionary = xpc_dictionary_create_empty()
    withNullTerminatedBytes(Array("self".utf8)) { key in
      xpc_dictionary_set_value(dictionary, key, dictionary)
    }
    return dictionary

  case .mutualDictionaries:
    let first = xpc_dictionary_create_empty()
    let second = xpc_dictionary_create_empty()
    withNullTerminatedBytes(Array("other".utf8)) { key in
      xpc_dictionary_set_value(first, key, second)
      xpc_dictionary_set_value(second, key, first)
    }
    return first

  case .sharedAcyclicArray:
    let child = xpc_array_create_empty()
    return xpcArray([child, child])

  case .sharedAcyclicDictionary:
    let child = xpc_dictionary_create_empty()
    return xpcDictionary([
      (Array("a".utf8), child),
      (Array("b".utf8), child),
    ])
  }
}

/// A chain of `edgeCount` nested XPC arrays below the root.
func nestedXPCArray(edgeCount: Int) -> xpc_object_t {
  var result = xpc_array_create_empty()
  for _ in 0..<max(0, edgeCount) {
    result = xpcArray([result])
  }
  return result
}

// MARK: - Decodable Fixtures

/// Decodes any supported XPC object without knowing its kind in advance.
indirect enum AnyXPCValue: Decodable {
  case null
  case bool(Bool)
  case signed(Int64)
  case unsigned(UInt64)
  case double(Double)
  case string(String)
  case data(Data)
  case array([AnyXPCValue])
  case dictionary([String: AnyXPCValue])

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int64.self) {
      self = .signed(value)
    } else if let value = try? container.decode(UInt64.self) {
      self = .unsigned(value)
    } else if let value = try? container.decode(Double.self) {
      self = .double(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode(Data.self) {
      self = .data(value)
    } else if let value = try? container.decode([Self].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: Self].self) {
      self = .dictionary(value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "No supported generic XPC interpretation succeeded."
      )
    }
  }
}

/// Recurses through element zero of nested XPC arrays.
indirect enum RecursiveArray: Decodable {
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

/// Recurses through the first key of nested XPC dictionaries.
indirect enum RecursiveDictionary: Decodable {
  case leaf
  case branch(RecursiveDictionary)

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: FuzzingCodingKey.self)
    guard let key = container.allKeys.first else {
      self = .leaf
      return
    }
    self = try .branch(container.decode(Self.self, forKey: key))
  }
}

/// Decodes two sibling arrays so a shared acyclic child is traversed twice.
struct SharedArrayPair: Decodable {
  let first: RecursiveArray
  let second: RecursiveArray

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    self.first = try container.decode(RecursiveArray.self)
    self.second = try container.decode(RecursiveArray.self)
  }
}

/// Decodes two sibling dictionaries so a shared acyclic child is traversed twice.
struct SharedDictionaryPair: Decodable {
  let first: RecursiveDictionary
  let second: RecursiveDictionary

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: FuzzingCodingKey.self)
    self.first = try container.decode(
      RecursiveDictionary.self,
      forKey: FuzzingCodingKey(stringValue: "a")
    )
    self.second = try container.decode(
      RecursiveDictionary.self,
      forKey: FuzzingCodingKey(stringValue: "b")
    )
  }
}

/// Reports the dictionary keys a decoder exposes, without filtering any of them.
struct AllKeysProbe: Decodable {
  let keys: [String]

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: FuzzingCodingKey.self)
    self.keys = container.allKeys.map(\.stringValue)
  }
}

/// A coding key that can represent every decoded XPC dictionary key.
struct FuzzingCodingKey: CodingKey {
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
