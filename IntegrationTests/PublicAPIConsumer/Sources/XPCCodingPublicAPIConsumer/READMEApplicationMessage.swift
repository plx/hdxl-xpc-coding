@preconcurrency import XPC
import XPCCoding

enum ApplicationMessageError: Error {
  case invalidMessage
  case missingPayload
}

struct WorkRequest: Codable, Equatable {
  let identifier: Int
  let input: String
}

let applicationPayloadKey = "payload"

func makeMessage(
  for request: WorkRequest,
  using codec: XPCCodec = .standard
) throws -> xpc_object_t {
  let message = xpc_dictionary_create_empty()
  let root = try codec.encode(request)
  applicationPayloadKey.withCString {
    xpc_dictionary_set_value(message, $0, root)
  }
  return message
}

func decodeRequest(
  from message: xpc_object_t,
  using codec: XPCCodec = .standard
) throws -> WorkRequest {
  guard xpc_get_type(message) == XPC_TYPE_DICTIONARY else {
    throw ApplicationMessageError.invalidMessage
  }
  guard
    let root = applicationPayloadKey.withCString({
      xpc_dictionary_get_value(message, $0)
    })
  else {
    throw ApplicationMessageError.missingPayload
  }
  return try codec.decode(WorkRequest.self, from: root)
}

func send(
  _ request: WorkRequest,
  over connection: xpc_connection_t,
  using codec: XPCCodec = .standard
) throws {
  xpc_connection_send_message(
    connection,
    try makeMessage(for: request, using: codec)
  )
}

func verifyApplicationMessageRoundTrip() throws {
  let request = WorkRequest(
    identifier: 29,
    input: "same-host\u{0}%"
  )
  let message = try makeMessage(for: request)
  let decoded = try decodeRequest(from: message)
  precondition(decoded == request)

  do {
    _ = try decodeRequest(from: xpc_int64_create(29))
    preconditionFailure("A non-dictionary connection event was accepted.")
  } catch ApplicationMessageError.invalidMessage {
    // The application must reject non-dictionary XPC events before lookup.
  }
}
