
/// A simple timestamp type that encodes as a single Double value.
struct Timestamp : Codable, Equatable {
  let value: Double
  
  init(_ value: Double) {
    self.value = value
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    value = try container.decode(Double.self)
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(value)
  }
  
  static func ==(lhs: Self, rhs: Self) -> Bool {
    equivalentFloats(lhs.value, rhs.value)
  }
}
