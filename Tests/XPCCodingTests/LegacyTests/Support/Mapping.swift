import Foundation


/// A type which encodes as a dictionary directly through a single value container.
final class Mapping : Sendable, Codable, Equatable {
  let values: [String : URL]
  
  init(values: [String : URL]) {
    self.values = values
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    values = try container.decode([String : URL].self)
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(values)
  }
  
  static func ==(_ lhs: Mapping, _ rhs: Mapping) -> Bool {
    lhs === rhs || lhs.values == rhs.values
  }
  
  static var testValue: Mapping {
    Mapping(
      values: [
        "Apple": URL(string: "https://apple.com")!,
        "localhost": URL(string: "http://127.0.0.1")!
      ]
    )
  }
  
  static var testValues: [Mapping] { [testValue] }
}
