import Darwin
import Foundation
@preconcurrency import XPC
import XPCCoding
import XPCCodingXPCIntegrationProtocol

do {
  try runIntegration()
} catch {
  let message = "XPC integration failed: \(String(reflecting: error))\n"
  FileHandle.standardError.write(
    Data(message.utf8)
  )
  exit(EXIT_FAILURE)
}

private func runIntegration() throws {
  guard
    Bundle.main.bundleIdentifier
      == XPCIntegrationProtocol.clientBundleIdentifier
  else {
    throw ClientFailure.invalidClientBundle(
      Bundle.main.bundleIdentifier
    )
  }
  let iteration = try integrationIteration()
  let connection = makeConnection()
  defer {
    xpc_connection_cancel(connection.xpc)
  }

  let values = exerciseValues(
    iteration: iteration
  )
  let exerciseReply = try sendWithTimeout(
    makeExerciseRequest(values),
    over: connection,
    operation: XPCIntegrationProtocol.Operation.exercise
  )
  let servicePID = try validateExerciseReply(
    exerciseReply,
    over: connection.xpc,
    original: values
  )

  let missingOperationReply = try sendWithTimeout(
    makeMissingOperationRequest(),
    over: connection,
    operation: "missing-operation-negative-control"
  )
  try validateApplicationErrorReply(
    missingOperationReply,
    context: "missing operation",
    expectedServicePID: servicePID
  )

  let wrongShapeReply = try sendWithTimeout(
    makeWrongShapeRequest(),
    over: connection,
    operation: "wrong-shape-negative-control"
  )
  try validateApplicationErrorReply(
    wrongShapeReply,
    context: "wrong scalar shape",
    expectedServicePID: servicePID
  )

  let remoteError = try sendWithTimeout(
    makeTerminateRequest(),
    over: connection,
    operation: XPCIntegrationProtocol.Operation.terminateWithoutReply
  )
  guard
    xpc_get_type(remoteError) == XPC_TYPE_ERROR,
    xpc_equal(
      remoteError,
      XPC_ERROR_CONNECTION_INTERRUPTED
    )
  else {
    throw ClientFailure.unexpectedRemoteError(
      String(describing: remoteError)
    )
  }

  print(
    """
    XPC integration iteration \(iteration) passed: \
    client PID \(getpid()), service PID \(servicePID), \
    \(values.data.count) data bytes.
    """
  )
}

private func makeConnection() -> ClientConnection {
  let queue = DispatchQueue(
    label: "com.plx.hdxl-xpc-coding.integration.connection"
  )
  let connection =
    XPCIntegrationProtocol.serviceBundleIdentifier.withCString {
      xpc_connection_create(
        $0,
        queue
      )
    }
  let eventRecorder = ConnectionEventRecorder()
  xpc_connection_set_event_handler(connection) { event in
    eventRecorder.record(event)
  }
  xpc_connection_activate(connection)
  return ClientConnection(
    xpc: connection,
    eventRecorder: eventRecorder
  )
}

private func makeExerciseRequest(
  _ values: ExerciseValues
) throws -> xpc_object_t {
  let message = xpc_dictionary_create_empty()
  setString(
    XPCIntegrationProtocol.Operation.exercise,
    in: message,
    forKey: XPCIntegrationProtocol.Key.operation
  )
  setInt64(
    Int64(getpid()),
    in: message,
    forKey: XPCIntegrationProtocol.Key.clientPID
  )

  let encoder = XPCEncoder(
    configuration: integrationConfiguration()
  )
  try setEncoded(
    values.scalar,
    in: message,
    forKey: XPCIntegrationProtocol.Key.scalar,
    using: encoder
  )
  try setEncoded(
    values.array,
    in: message,
    forKey: XPCIntegrationProtocol.Key.array,
    using: encoder
  )
  try setEncoded(
    values.keyed,
    in: message,
    forKey: XPCIntegrationProtocol.Key.keyed,
    using: encoder
  )
  try setEncoded(
    values.nested,
    in: message,
    forKey: XPCIntegrationProtocol.Key.nested,
    using: encoder
  )
  try setEncoded(
    values.repairedString,
    in: message,
    forKey: XPCIntegrationProtocol.Key.repairedString,
    using: encoder
  )
  try setEncoded(
    values.signedNarrow,
    in: message,
    forKey: XPCIntegrationProtocol.Key.signedNarrow,
    using: encoder
  )
  try setEncoded(
    values.unsignedNarrow,
    in: message,
    forKey: XPCIntegrationProtocol.Key.unsignedNarrow,
    using: encoder
  )
  try setEncoded(
    values.floatingPoint,
    in: message,
    forKey: XPCIntegrationProtocol.Key.floatingPoint,
    using: encoder
  )
  try setEncoded(
    values.integer128,
    in: message,
    forKey: XPCIntegrationProtocol.Key.integer128,
    using: encoder
  )
  try setEncoded(
    values.data,
    in: message,
    forKey: XPCIntegrationProtocol.Key.data,
    using: encoder
  )
  return message
}

private func makeMissingOperationRequest() -> xpc_object_t {
  let message = xpc_dictionary_create_empty()
  setInt64(
    Int64(getpid()),
    in: message,
    forKey: XPCIntegrationProtocol.Key.clientPID
  )
  return message
}

private func makeWrongShapeRequest() -> xpc_object_t {
  let message = xpc_dictionary_create_empty()
  setString(
    XPCIntegrationProtocol.Operation.exercise,
    in: message,
    forKey: XPCIntegrationProtocol.Key.operation
  )
  setInt64(
    Int64(getpid()),
    in: message,
    forKey: XPCIntegrationProtocol.Key.clientPID
  )
  setString(
    "not-an-int64",
    in: message,
    forKey: XPCIntegrationProtocol.Key.scalar
  )
  return message
}

private func makeTerminateRequest() -> xpc_object_t {
  let message = xpc_dictionary_create_empty()
  setString(
    XPCIntegrationProtocol.Operation.terminateWithoutReply,
    in: message,
    forKey: XPCIntegrationProtocol.Key.operation
  )
  return message
}

private func validateExerciseReply(
  _ reply: xpc_object_t,
  over connection: xpc_connection_t,
  original: ExerciseValues
) throws -> pid_t {
  guard xpc_get_type(reply) == XPC_TYPE_DICTIONARY else {
    throw ClientFailure.unexpectedReplyType(
      String(describing: reply)
    )
  }
  try requireApplicationString(
    XPCIntegrationProtocol.Status.success,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.status
  )
  let servicePID = try requiredInt64(
    in: reply,
    forKey: XPCIntegrationProtocol.Key.servicePID
  )
  let observedRemotePID = xpc_connection_get_pid(connection)
  guard
    servicePID > 0,
    servicePID == Int64(observedRemotePID),
    servicePID != Int64(getpid())
  else {
    throw ClientFailure.servicePIDMismatch(
      declared: servicePID,
      observed: observedRemotePID,
      client: getpid()
    )
  }

  let observations = try requiredValue(
    in: reply,
    forKey: XPCIntegrationProtocol.Key.observations
  )
  guard xpc_get_type(observations) == XPC_TYPE_DICTIONARY else {
    throw ClientFailure.invalidObservationDictionary
  }
  let expectedObservations = [
    XPCIntegrationProtocol.Key.scalar:
      XPCIntegrationProtocol.Shape.int64,
    XPCIntegrationProtocol.Key.array:
      XPCIntegrationProtocol.Shape.array,
    XPCIntegrationProtocol.Key.keyed:
      XPCIntegrationProtocol.Shape.dictionary,
    XPCIntegrationProtocol.Key.nested:
      XPCIntegrationProtocol.Shape.dictionary,
    XPCIntegrationProtocol.Key.repairedString:
      XPCIntegrationProtocol.Shape.string,
    XPCIntegrationProtocol.Key.signedNarrow:
      XPCIntegrationProtocol.Shape.int64,
    XPCIntegrationProtocol.Key.unsignedNarrow:
      XPCIntegrationProtocol.Shape.uint64,
    XPCIntegrationProtocol.Key.floatingPoint:
      XPCIntegrationProtocol.Shape.double,
    XPCIntegrationProtocol.Key.integer128:
      XPCIntegrationProtocol.Shape.data,
    XPCIntegrationProtocol.Key.data:
      XPCIntegrationProtocol.Shape.data,
  ]
  for (key, expectedShape) in expectedObservations {
    try requireApplicationString(
      expectedShape,
      in: observations,
      forKey: key
    )
  }

  let expectedReplyShapes:
    [(
      key: String,
      type: xpc_type_t,
      name: String
    )] = [
      (
        XPCIntegrationProtocol.Key.scalar,
        XPC_TYPE_INT64,
        XPCIntegrationProtocol.Shape.int64
      ),
      (
        XPCIntegrationProtocol.Key.array,
        XPC_TYPE_ARRAY,
        XPCIntegrationProtocol.Shape.array
      ),
      (
        XPCIntegrationProtocol.Key.keyed,
        XPC_TYPE_DICTIONARY,
        XPCIntegrationProtocol.Shape.dictionary
      ),
      (
        XPCIntegrationProtocol.Key.nested,
        XPC_TYPE_DICTIONARY,
        XPCIntegrationProtocol.Shape.dictionary
      ),
      (
        XPCIntegrationProtocol.Key.repairedString,
        XPC_TYPE_STRING,
        XPCIntegrationProtocol.Shape.string
      ),
      (
        XPCIntegrationProtocol.Key.signedNarrow,
        XPC_TYPE_INT64,
        XPCIntegrationProtocol.Shape.int64
      ),
      (
        XPCIntegrationProtocol.Key.unsignedNarrow,
        XPC_TYPE_UINT64,
        XPCIntegrationProtocol.Shape.uint64
      ),
      (
        XPCIntegrationProtocol.Key.floatingPoint,
        XPC_TYPE_DOUBLE,
        XPCIntegrationProtocol.Shape.double
      ),
      (
        XPCIntegrationProtocol.Key.integer128,
        XPC_TYPE_DATA,
        XPCIntegrationProtocol.Shape.data
      ),
      (
        XPCIntegrationProtocol.Key.data,
        XPC_TYPE_DATA,
        XPCIntegrationProtocol.Shape.data
      ),
    ]
  for expectedReplyShape in expectedReplyShapes {
    try requireXPCShape(
      expectedReplyShape.type,
      in: reply,
      forKey: expectedReplyShape.key,
      expectedName: expectedReplyShape.name
    )
  }
  try requireDataLength(
    16,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.integer128
  )
  try requireDataLength(
    XPCIntegrationProtocol.largeDataCount,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.data
  )

  let decoder = XPCDecoder(
    configuration: integrationConfiguration()
  )
  let scalar = try decode(
    Int.self,
    from: reply,
    forKey: XPCIntegrationProtocol.Key.scalar,
    using: decoder
  )
  let array = try decode(
    [Int].self,
    from: reply,
    forKey: XPCIntegrationProtocol.Key.array,
    using: decoder
  )
  let keyed = try decode(
    IntegrationKeyedPayload.self,
    from: reply,
    forKey: XPCIntegrationProtocol.Key.keyed,
    using: decoder
  )
  let nested = try decode(
    IntegrationNestedPayload.self,
    from: reply,
    forKey: XPCIntegrationProtocol.Key.nested,
    using: decoder
  )
  let repairedString = try decode(
    String.self,
    from: reply,
    forKey: XPCIntegrationProtocol.Key.repairedString,
    using: decoder
  )
  let signedNarrow = try decode(
    Int16.self,
    from: reply,
    forKey: XPCIntegrationProtocol.Key.signedNarrow,
    using: decoder
  )
  let unsignedNarrow = try decode(
    UInt32.self,
    from: reply,
    forKey: XPCIntegrationProtocol.Key.unsignedNarrow,
    using: decoder
  )
  let floatingPoint = try decode(
    Float.self,
    from: reply,
    forKey: XPCIntegrationProtocol.Key.floatingPoint,
    using: decoder
  )
  let integer128 = try decode(
    Int128.self,
    from: reply,
    forKey: XPCIntegrationProtocol.Key.integer128,
    using: decoder
  )
  let data = try decode(
    Data.self,
    from: reply,
    forKey: XPCIntegrationProtocol.Key.data,
    using: decoder
  )

  try requireEqual(
    scalar,
    original.scalar + 1,
    context: XPCIntegrationProtocol.Key.scalar
  )
  try requireEqual(
    array,
    Array(original.array.reversed()),
    context: XPCIntegrationProtocol.Key.array
  )
  try requireEqual(
    keyed,
    IntegrationKeyedPayload(
      label: original.keyed.label.uppercased(),
      count: original.keyed.count + 1
    ),
    context: XPCIntegrationProtocol.Key.keyed
  )
  try requireEqual(
    nested,
    IntegrationNestedPayload(
      name: "\(original.nested.name)-service",
      child: .init(
        enabled: !original.nested.child.enabled,
        values: Array(original.nested.child.values.reversed())
      )
    ),
    context: XPCIntegrationProtocol.Key.nested
  )
  try requireEqual(
    repairedString,
    "\(original.repairedString)|service\0%",
    context: XPCIntegrationProtocol.Key.repairedString
  )
  try requireEqual(
    signedNarrow,
    original.signedNarrow + 1,
    context: XPCIntegrationProtocol.Key.signedNarrow
  )
  try requireEqual(
    unsignedNarrow,
    original.unsignedNarrow + 1,
    context: XPCIntegrationProtocol.Key.unsignedNarrow
  )
  try requireEqual(
    floatingPoint,
    original.floatingPoint * 2,
    context: XPCIntegrationProtocol.Key.floatingPoint
  )
  try requireEqual(
    integer128,
    original.integer128 + 1,
    context: XPCIntegrationProtocol.Key.integer128
  )
  try requireEqual(
    data,
    original.data,
    context: XPCIntegrationProtocol.Key.data
  )

  let remoteChecksum = try requiredUInt64(
    in: reply,
    forKey: XPCIntegrationProtocol.Key.dataChecksum
  )
  try requireEqual(
    remoteChecksum,
    integrationDataChecksum(original.data),
    context: XPCIntegrationProtocol.Key.dataChecksum
  )
  return observedRemotePID
}

private func validateApplicationErrorReply(
  _ reply: xpc_object_t,
  context: String,
  expectedServicePID: pid_t
) throws {
  guard xpc_get_type(reply) == XPC_TYPE_DICTIONARY else {
    throw ClientFailure.unexpectedReplyType(
      String(describing: reply)
    )
  }
  try requireApplicationString(
    XPCIntegrationProtocol.Status.error,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.status
  )
  try requireApplicationString(
    XPCIntegrationProtocol.ErrorCode.invalidApplicationMessage,
    in: reply,
    forKey: XPCIntegrationProtocol.Key.errorCode
  )
  let detail = try requiredApplicationString(
    in: reply,
    forKey: XPCIntegrationProtocol.Key.errorDetail
  )
  guard !detail.isEmpty else {
    throw ClientFailure.emptyErrorDetail(context)
  }
  let servicePID = try requiredInt64(
    in: reply,
    forKey: XPCIntegrationProtocol.Key.servicePID
  )
  guard servicePID == Int64(expectedServicePID) else {
    throw ClientFailure.invalidErrorServicePID(
      servicePID,
      expected: expectedServicePID,
      context: context
    )
  }
}

private func sendWithTimeout(
  _ message: xpc_object_t,
  over connection: ClientConnection,
  operation: String
) throws -> xpc_object_t {
  let replySlot = ReplySlot()
  let completion = DispatchSemaphore(value: 0)
  let replyQueue = DispatchQueue(
    label: "com.plx.hdxl-xpc-coding.integration.reply"
  )
  xpc_connection_send_message_with_reply(
    connection.xpc,
    message,
    replyQueue
  ) { reply in
    replySlot.store(reply)
    completion.signal()
  }

  let result = completion.wait(
    timeout: .now() + .seconds(5)
  )
  guard result == .success else {
    xpc_connection_cancel(connection.xpc)
    throw ClientFailure.replyTimeout(
      operation,
      mostRecentConnectionError:
        connection.eventRecorder.mostRecentErrorDescription()
    )
  }
  guard let reply = replySlot.load() else {
    throw ClientFailure.missingReply(operation)
  }
  return reply
}

private func exerciseValues(
  iteration: Int
) -> ExerciseValues {
  let data = Data(
    (0..<XPCIntegrationProtocol.largeDataCount).map { index in
      UInt8(
        truncatingIfNeeded:
          index &* 31
          &+ iteration &* 17
      )
    }
  )
  return ExerciseValues(
    scalar: 40 + iteration,
    array: [iteration, 2, 3, 5, 8],
    keyed: IntegrationKeyedPayload(
      label: "package-\(iteration)",
      count: 6 + iteration
    ),
    nested: IntegrationNestedPayload(
      name: "root-\(iteration)",
      child: .init(
        enabled: iteration.isMultiple(of: 2),
        values: [13, 21, 34, iteration]
      )
    ),
    repairedString: "literal-%00-\0-iteration-\(iteration)",
    signedNarrow: Int16(-1_234 + iteration),
    unsignedNarrow: UInt32(4_000_000_000 + iteration),
    floatingPoint: Float(iteration) + 1.5,
    integer128: Int128(9_223_372_036_854_775_807) + Int128(iteration),
    data: data
  )
}

private func integrationIteration() throws -> Int {
  guard
    let rawValue = ProcessInfo.processInfo.environment[
      "XPCCODING_XPC_INTEGRATION_ITERATION"
    ],
    let value = Int(rawValue),
    1...3 ~= value
  else {
    throw ClientFailure.invalidIteration
  }
  return value
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

private func decode<Value: Decodable>(
  _ type: Value.Type,
  from dictionary: xpc_object_t,
  forKey key: String,
  using decoder: XPCDecoder
) throws -> Value {
  try decoder.decode(
    type,
    from: requiredValue(
      in: dictionary,
      forKey: key
    )
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
    throw ClientFailure.missingKey(key)
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
    throw ClientFailure.invalidApplicationString(key)
  }
  return result
}

private func requireApplicationString(
  _ expected: String,
  in dictionary: xpc_object_t,
  forKey key: String
) throws {
  try requireEqual(
    requiredApplicationString(
      in: dictionary,
      forKey: key
    ),
    expected,
    context: key
  )
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
    throw ClientFailure.invalidInt64(key)
  }
  return xpc_int64_get_value(value)
}

private func requiredUInt64(
  in dictionary: xpc_object_t,
  forKey key: String
) throws -> UInt64 {
  let value = try requiredValue(
    in: dictionary,
    forKey: key
  )
  guard xpc_get_type(value) == XPC_TYPE_UINT64 else {
    throw ClientFailure.invalidUInt64(key)
  }
  return xpc_uint64_get_value(value)
}

private func requireXPCShape(
  _ expectedType: xpc_type_t,
  in dictionary: xpc_object_t,
  forKey key: String,
  expectedName: String
) throws {
  let value = try requiredValue(
    in: dictionary,
    forKey: key
  )
  guard xpc_get_type(value) == expectedType else {
    throw ClientFailure.invalidReplyShape(
      key: key,
      expected: expectedName
    )
  }
}

private func requireDataLength(
  _ expected: Int,
  in dictionary: xpc_object_t,
  forKey key: String
) throws {
  let value = try requiredValue(
    in: dictionary,
    forKey: key
  )
  let actual = xpc_data_get_length(value)
  guard actual == expected else {
    throw ClientFailure.invalidDataLength(
      key: key,
      expected: expected,
      actual: actual
    )
  }
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

private func requireEqual<Value: Equatable>(
  _ actual: Value,
  _ expected: Value,
  context: String
) throws {
  guard actual == expected else {
    throw ClientFailure.valueMismatch(
      context: context,
      expected: String(reflecting: expected),
      actual: String(reflecting: actual)
    )
  }
}

private struct ExerciseValues {
  let scalar: Int
  let array: [Int]
  let keyed: IntegrationKeyedPayload
  let nested: IntegrationNestedPayload
  let repairedString: String
  let signedNarrow: Int16
  let unsignedNarrow: UInt32
  let floatingPoint: Float
  let integer128: Int128
  let data: Data
}

private struct ClientConnection {
  let xpc: xpc_connection_t
  let eventRecorder: ConnectionEventRecorder
}

private final class ReplySlot: @unchecked Sendable {

  private let lock = NSLock()
  private var reply: xpc_object_t?

  func store(_ reply: xpc_object_t) {
    lock.lock()
    self.reply = reply
    lock.unlock()
  }

  func load() -> xpc_object_t? {
    lock.lock()
    defer {
      lock.unlock()
    }
    return reply
  }

}

private final class ConnectionEventRecorder: @unchecked Sendable {

  private let lock = NSLock()
  private var mostRecentError: xpc_object_t?

  func record(_ event: xpc_object_t) {
    guard xpc_get_type(event) == XPC_TYPE_ERROR else {
      return
    }
    lock.lock()
    mostRecentError = event
    lock.unlock()
  }

  func mostRecentErrorDescription() -> String? {
    lock.lock()
    defer {
      lock.unlock()
    }
    return mostRecentError.map {
      String(describing: $0)
    }
  }

}

private enum ClientFailure: Error, CustomStringConvertible {

  case emptyErrorDetail(String)
  case invalidApplicationString(String)
  case invalidClientBundle(String?)
  case invalidDataLength(key: String, expected: Int, actual: Int)
  case invalidErrorServicePID(Int64, expected: pid_t, context: String)
  case invalidInt64(String)
  case invalidIteration
  case invalidObservationDictionary
  case invalidReplyShape(key: String, expected: String)
  case invalidUInt64(String)
  case missingKey(String)
  case missingReply(String)
  case replyTimeout(
    String,
    mostRecentConnectionError: String?
  )
  case servicePIDMismatch(declared: Int64, observed: pid_t, client: pid_t)
  case unexpectedRemoteError(String)
  case unexpectedReplyType(String)
  case valueMismatch(context: String, expected: String, actual: String)

  var description: String {
    switch self {
    case .emptyErrorDetail(let context):
      "The \(context) reply had an empty error detail."
    case .invalidApplicationString(let key):
      "The application field \(key) was not a valid XPC string."
    case .invalidClientBundle(let identifier):
      "Expected client bundle identifier \(XPCIntegrationProtocol.clientBundleIdentifier), observed \(String(reflecting: identifier))."
    case .invalidDataLength(let key, let expected, let actual):
      "Invalid reply data length for \(key): expected \(expected), observed \(actual)."
    case .invalidErrorServicePID(let pid, let expected, let context):
      "The \(context) error reply carried service PID \(pid), expected \(expected)."
    case .invalidInt64(let key):
      "The application field \(key) was not XPC int64."
    case .invalidIteration:
      "The integration iteration must be an integer from 1 through 3."
    case .invalidObservationDictionary:
      "The service observations field was not an XPC dictionary."
    case .invalidReplyShape(let key, let expected):
      "Invalid reply XPC shape for \(key); expected \(expected)."
    case .invalidUInt64(let key):
      "The application field \(key) was not XPC uint64."
    case .missingKey(let key):
      "The reply omitted application key \(key)."
    case .missingReply(let operation):
      "The \(operation) callback completed without an XPC object."
    case .replyTimeout(let operation, let mostRecentConnectionError):
      """
      Timed out after 5 seconds waiting for \(operation). \
      Most recent connection error: \
      \(mostRecentConnectionError ?? "none observed").
      """
    case .servicePIDMismatch(let declared, let observed, let client):
      "Service PID mismatch: declared \(declared), observed \(observed), client \(client)."
    case .unexpectedRemoteError(let error):
      "Expected XPC_ERROR_CONNECTION_INTERRUPTED, observed \(error)."
    case .unexpectedReplyType(let reply):
      "Expected an XPC dictionary reply, observed \(reply)."
    case .valueMismatch(let context, let expected, let actual):
      "Value mismatch for \(context): expected \(expected), observed \(actual)."
    }
  }

}
