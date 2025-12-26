
/// A simple struct with multiple primitive fields.
struct SimpleStruct: Codable, Equatable {
  let stringField: String
  let intField: Int
  let doubleField: Double
  let boolField: Bool
  
  static var testValue: SimpleStruct {
    SimpleStruct(
      stringField: "hello",
      intField: 42,
      doubleField: 3.14159,
      boolField: true
    )
  }
}
