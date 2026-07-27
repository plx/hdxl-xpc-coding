/// A type that always throws during encoding.
struct ThrowsOnEncode: Encodable {
  struct EncodingFailure: Error {
    let message: String
  }

  let message: String

  init(message: String = "Encoding failed") {
    self.message = message
  }

  func encode(to encoder: Encoder) throws {
    throw EncodingFailure(message: message)
  }
}

/// A type that always throws during decoding.
struct ThrowsOnDecode: Decodable {
  struct DecodingFailure: Error {
    let message: String
  }

  init(from decoder: Decoder) throws {
    throw DecodingFailure(message: "Decoding failed")
  }
}
