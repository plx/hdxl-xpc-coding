
/// An empty struct for testing empty keyed containers.
struct EmptyStruct: Codable, Equatable {}

/// An empty class for testing empty keyed containers.
final class EmptyClass: Codable, Equatable {
  static func == (lhs: EmptyClass, rhs: EmptyClass) -> Bool { true }
}
