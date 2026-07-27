import XPCCoding

struct Greeting: Codable, Equatable {
  let text: String
}

func verifyGreetingRoundTrip() throws {
  let greeting = Greeting(text: "hello from another process")
  let codec = XPCCodec.standard

  let root = try codec.encode(greeting)
  let decoded = try codec.decode(Greeting.self, from: root)

  precondition(decoded == greeting)
}
