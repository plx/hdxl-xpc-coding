import Darwin
import Foundation
@preconcurrency import XPC
import XPCCoding
import XPCCodingXPCIntegrationProtocol

xpc_main(acceptPeer)

private nonisolated func acceptPeer(
  _ peer: xpc_connection_t
) {
  xpc_connection_set_event_handler(peer) { event in
    guard xpc_get_type(event) == XPC_TYPE_DICTIONARY else {
      return
    }
    handleApplicationMessage(
      event,
      from: peer
    )
  }
  xpc_connection_activate(peer)
}

private func handleApplicationMessage(
  _ message: xpc_object_t,
  from peer: xpc_connection_t
) {
  do {
    let operation = try requiredApplicationString(
      in: message,
      forKey: XPCIntegrationProtocol.Key.operation
    )
    switch operation {
    case XPCIntegrationProtocol.Operation.exercise:
      try handleExercise(
        message,
        from: peer
      )
    case XPCIntegrationProtocol.Operation.terminateWithoutReply:
      _exit(73)
    default:
      throw ServiceMessageError.invalidOperation(operation)
    }
  } catch {
    sendErrorReply(
      to: message,
      over: peer,
      error: error
    )
  }
}

private func handleExercise(
  _ message: xpc_object_t,
  from peer: xpc_connection_t
) throws {
  let clientPID = try requiredInt64(
    in: message,
    forKey: XPCIntegrationProtocol.Key.clientPID
  )
  let actualClientPID = xpc_connection_get_pid(peer)
  guard
    clientPID > 0,
    clientPID == Int64(actualClientPID),
    clientPID != Int64(getpid())
  else {
    throw ServiceMessageError.clientPIDMismatch(
      declared: clientPID,
      observed: actualClientPID,
      service: getpid()
    )
  }

  let observations = xpc_dictionary_create_empty()
  let payloads = try validatePayloadShapes(
    in: message,
    observations: observations
  )
  let configuration = integrationConfiguration()
  let decoder = XPCDecoder(configuration: configuration)

  let scalar = try decoder.decode(
    Int.self,
    from: payloads.scalar
  )
  let array = try decoder.decode(
    [Int].self,
    from: payloads.array
  )
  let keyed = try decoder.decode(
    IntegrationKeyedPayload.self,
    from: payloads.keyed
  )
  let nested = try decoder.decode(
    IntegrationNestedPayload.self,
    from: payloads.nested
  )
  let repairedString = try decoder.decode(
    String.self,
    from: payloads.repairedString
  )
  let signedNarrow = try decoder.decode(
    Int16.self,
    from: payloads.signedNarrow
  )
  let unsignedNarrow = try decoder.decode(
    UInt32.self,
    from: payloads.unsignedNarrow
  )
  let floatingPoint = try decoder.decode(
    Float.self,
    from: payloads.floatingPoint
  )
  let integer128 = try decoder.decode(
    Int128.self,
    from: payloads.integer128
  )
  let data = try decoder.decode(
    Data.self,
    from: payloads.data
  )

  let transformedScalar = try addingOne(scalar)
  let transformedKeyed = IntegrationKeyedPayload(
    label: keyed.label.uppercased(),
    count: try addingOne(keyed.count)
  )
  let transformedNested = IntegrationNestedPayload(
    name: "\(nested.name)-service",
    child: .init(
      enabled: !nested.child.enabled,
      values: Array(nested.child.values.reversed())
    )
  )
  let transformedSignedNarrow = try addingOne(signedNarrow)
  let transformedUnsignedNarrow = try addingOne(unsignedNarrow)
  let transformedInteger128 = try addingOne(integer128)

  guard let reply = xpc_dictionary_create_reply(message) else {
    throw ServiceMessageError.replyContextUnavailable
  }
  setString(
    XPCIntegrationProtocol.Status.success,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.status
  )
  setInt64(
    Int64(getpid()),
    in: reply,
    forKey: XPCIntegrationProtocol.Key.servicePID
  )
  setUInt64(
    integrationDataChecksum(data),
    in: reply,
    forKey: XPCIntegrationProtocol.Key.dataChecksum
  )
  setValue(
    observations,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.observations
  )

  let encoder = XPCEncoder(configuration: configuration)
  try setEncoded(
    transformedScalar,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.scalar,
    using: encoder
  )
  try setEncoded(
    Array(array.reversed()),
    in: reply,
    forKey: XPCIntegrationProtocol.Key.array,
    using: encoder
  )
  try setEncoded(
    transformedKeyed,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.keyed,
    using: encoder
  )
  try setEncoded(
    transformedNested,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.nested,
    using: encoder
  )
  try setEncoded(
    "\(repairedString)|service\0%",
    in: reply,
    forKey: XPCIntegrationProtocol.Key.repairedString,
    using: encoder
  )
  try setEncoded(
    transformedSignedNarrow,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.signedNarrow,
    using: encoder
  )
  try setEncoded(
    transformedUnsignedNarrow,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.unsignedNarrow,
    using: encoder
  )
  try setEncoded(
    floatingPoint * 2,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.floatingPoint,
    using: encoder
  )
  try setEncoded(
    transformedInteger128,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.integer128,
    using: encoder
  )
  try setEncoded(
    data,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.data,
    using: encoder
  )

  xpc_connection_send_message(
    peer,
    reply
  )
}

private func validatePayloadShapes(
  in message: xpc_object_t,
  observations: xpc_object_t
) throws -> ValidatedPayloads {
  let scalar = try requireShape(
    .int64,
    forKey: XPCIntegrationProtocol.Key.scalar,
    in: message,
    observations: observations
  )
  let array = try requireShape(
    .array,
    forKey: XPCIntegrationProtocol.Key.array,
    in: message,
    observations: observations
  )
  let keyed = try requireShape(
    .dictionary,
    forKey: XPCIntegrationProtocol.Key.keyed,
    in: message,
    observations: observations
  )
  let nested = try requireShape(
    .dictionary,
    forKey: XPCIntegrationProtocol.Key.nested,
    in: message,
    observations: observations
  )
  let repairedString = try requireShape(
    .string,
    forKey: XPCIntegrationProtocol.Key.repairedString,
    in: message,
    observations: observations
  )
  let signedNarrow = try requireShape(
    .int64,
    forKey: XPCIntegrationProtocol.Key.signedNarrow,
    in: message,
    observations: observations
  )
  let unsignedNarrow = try requireShape(
    .uint64,
    forKey: XPCIntegrationProtocol.Key.unsignedNarrow,
    in: message,
    observations: observations
  )
  let floatingPoint = try requireShape(
    .double,
    forKey: XPCIntegrationProtocol.Key.floatingPoint,
    in: message,
    observations: observations
  )
  let integer128 = try requireShape(
    .data,
    forKey: XPCIntegrationProtocol.Key.integer128,
    in: message,
    observations: observations
  )
  let data = try requireShape(
    .data,
    forKey: XPCIntegrationProtocol.Key.data,
    in: message,
    observations: observations
  )

  guard xpc_data_get_length(integer128) == 16 else {
    throw ServiceMessageError.invalidDataLength(
      key: XPCIntegrationProtocol.Key.integer128,
      expected: 16,
      actual: xpc_data_get_length(integer128)
    )
  }
  guard
    xpc_data_get_length(data) == XPCIntegrationProtocol.largeDataCount
  else {
    throw ServiceMessageError.invalidDataLength(
      key: XPCIntegrationProtocol.Key.data,
      expected: XPCIntegrationProtocol.largeDataCount,
      actual: xpc_data_get_length(data)
    )
  }

  return ValidatedPayloads(
    scalar: scalar,
    array: array,
    keyed: keyed,
    nested: nested,
    repairedString: repairedString,
    signedNarrow: signedNarrow,
    unsignedNarrow: unsignedNarrow,
    floatingPoint: floatingPoint,
    integer128: integer128,
    data: data
  )
}

private func requireShape(
  _ shape: ExpectedXPCShape,
  forKey key: String,
  in message: xpc_object_t,
  observations: xpc_object_t
) throws -> xpc_object_t {
  let value = try requiredValue(
    in: message,
    forKey: key
  )
  guard xpc_get_type(value) == shape.xpcType else {
    throw ServiceMessageError.invalidShape(
      key: key,
      expected: shape.name
    )
  }
  setString(
    shape.name,
    in: observations,
    forKey: key
  )
  return value
}

private func sendErrorReply(
  to message: xpc_object_t,
  over peer: xpc_connection_t,
  error: any Error
) {
  guard let reply = xpc_dictionary_create_reply(message) else {
    xpc_connection_cancel(peer)
    return
  }
  setString(
    XPCIntegrationProtocol.Status.error,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.status
  )
  setString(
    XPCIntegrationProtocol.ErrorCode.invalidApplicationMessage,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.errorCode
  )
  setString(
    String(reflecting: error),
    in: reply,
    forKey: XPCIntegrationProtocol.Key.errorDetail
  )
  setInt64(
    Int64(getpid()),
    in: reply,
    forKey: XPCIntegrationProtocol.Key.servicePID
  )
  xpc_connection_send_message(
    peer,
    reply
  )
}

private func integrationConfiguration() -> XPCCodec.Configuration {
  XPCCodec.Configuration(
    stringKeyStrategy: .percentEscape,
    stringValueStrategy: .percentEscape
  )
}

private func setEncoded<Value: Encodable>(
  _ value: Value,
  in dictionary: xpc_object_t,
  forKey key: String,
  using encoder: XPCEncoder
) throws {
  setValue(
    try encoder.encode(value),
    in: dictionary,
    forKey: key
  )
}

private func requiredValue(
  in dictionary: xpc_object_t,
  forKey key: String
) throws -> xpc_object_t {
  guard
    let value = key.withCString({
      xpc_dictionary_get_value(
        dictionary,
        $0
      )
    })
  else {
    throw ServiceMessageError.missingKey(key)
  }
  return value
}

private func requiredApplicationString(
  in dictionary: xpc_object_t,
  forKey key: String
) throws -> String {
  let value = try requiredValue(
    in: dictionary,
    forKey: key
  )
  guard
    xpc_get_type(value) == XPC_TYPE_STRING,
    let pointer = xpc_string_get_string_ptr(value),
    let result = String(
      validatingCString: pointer
    )
  else {
    throw ServiceMessageError.invalidShape(
      key: key,
      expected: XPCIntegrationProtocol.Shape.string
    )
  }
  return result
}

private func requiredInt64(
  in dictionary: xpc_object_t,
  forKey key: String
) throws -> Int64 {
  let value = try requiredValue(
    in: dictionary,
    forKey: key
  )
  guard xpc_get_type(value) == XPC_TYPE_INT64 else {
    throw ServiceMessageError.invalidShape(
      key: key,
      expected: XPCIntegrationProtocol.Shape.int64
    )
  }
  return xpc_int64_get_value(value)
}

private func setValue(
  _ value: xpc_object_t,
  in dictionary: xpc_object_t,
  forKey key: String
) {
  key.withCString {
    xpc_dictionary_set_value(
      dictionary,
      $0,
      value
    )
  }
}

private func setString(
  _ value: String,
  in dictionary: xpc_object_t,
  forKey key: String
) {
  key.withCString { keyPointer in
    value.withCString { valuePointer in
      xpc_dictionary_set_string(
        dictionary,
        keyPointer,
        valuePointer
      )
    }
  }
}

private func setInt64(
  _ value: Int64,
  in dictionary: xpc_object_t,
  forKey key: String
) {
  key.withCString {
    xpc_dictionary_set_int64(
      dictionary,
      $0,
      value
    )
  }
}

private func setUInt64(
  _ value: UInt64,
  in dictionary: xpc_object_t,
  forKey key: String
) {
  key.withCString {
    xpc_dictionary_set_uint64(
      dictionary,
      $0,
      value
    )
  }
}

private func addingOne<Value: FixedWidthInteger>(
  _ value: Value
) throws -> Value {
  let result = value.addingReportingOverflow(1)
  guard !result.overflow else {
    throw ServiceMessageError.numericOverflow
  }
  return result.partialValue
}

private struct ValidatedPayloads {
  let scalar: xpc_object_t
  let array: xpc_object_t
  let keyed: xpc_object_t
  let nested: xpc_object_t
  let repairedString: xpc_object_t
  let signedNarrow: xpc_object_t
  let unsignedNarrow: xpc_object_t
  let floatingPoint: xpc_object_t
  let integer128: xpc_object_t
  let data: xpc_object_t
}

private enum ExpectedXPCShape {

  case int64
  case uint64
  case double
  case string
  case data
  case array
  case dictionary

  var name: String {
    switch self {
    case .int64:
      XPCIntegrationProtocol.Shape.int64
    case .uint64:
      XPCIntegrationProtocol.Shape.uint64
    case .double:
      XPCIntegrationProtocol.Shape.double
    case .string:
      XPCIntegrationProtocol.Shape.string
    case .data:
      XPCIntegrationProtocol.Shape.data
    case .array:
      XPCIntegrationProtocol.Shape.array
    case .dictionary:
      XPCIntegrationProtocol.Shape.dictionary
    }
  }

  var xpcType: xpc_type_t {
    switch self {
    case .int64:
      XPC_TYPE_INT64
    case .uint64:
      XPC_TYPE_UINT64
    case .double:
      XPC_TYPE_DOUBLE
    case .string:
      XPC_TYPE_STRING
    case .data:
      XPC_TYPE_DATA
    case .array:
      XPC_TYPE_ARRAY
    case .dictionary:
      XPC_TYPE_DICTIONARY
    }
  }

}

private enum ServiceMessageError: Error, CustomStringConvertible {

  case clientPIDMismatch(declared: Int64, observed: pid_t, service: pid_t)
  case invalidDataLength(key: String, expected: Int, actual: Int)
  case invalidOperation(String)
  case invalidShape(key: String, expected: String)
  case missingKey(String)
  case numericOverflow
  case replyContextUnavailable

  var description: String {
    switch self {
    case .clientPIDMismatch(let declared, let observed, let service):
      "Client PID mismatch: declared \(declared), observed \(observed), service \(service)."
    case .invalidDataLength(let key, let expected, let actual):
      "Invalid data length for \(key): expected \(expected), observed \(actual)."
    case .invalidOperation(let operation):
      "Invalid operation \(String(reflecting: operation))."
    case .invalidShape(let key, let expected):
      "Invalid XPC shape for \(key); expected \(expected)."
    case .missingKey(let key):
      "Missing application key \(key)."
    case .numericOverflow:
      "The requested integration transform would overflow."
    case .replyContextUnavailable:
      "The request did not carry an XPC reply context."
    }
  }

}
