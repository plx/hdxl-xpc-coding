struct DoubleNestedEmpty: Codable, Equatable {
  let emptyDict: [String: Int]
  let emptyArray: [Int]
}

struct NestedEmptyContainers: Codable, Equatable {
  let emptyDict: [String: Int]
  let emptyArray: [Int]
  let doubleNested: DoubleNestedEmpty
}

struct EmptyContainerStruct: Codable, Equatable {
  let emptyDict: [String: Int]
  let emptyArray: [Int]
  let nestedEmpty: NestedEmptyContainers

  static let testValues: [Self] = [testValue]
  static let testValue: Self = EmptyContainerStruct(
    emptyDict: [:],
    emptyArray: [],
    nestedEmpty: NestedEmptyContainers(
      emptyDict: [:],
      emptyArray: [],
      doubleNested: DoubleNestedEmpty(
        emptyDict: [:],
        emptyArray: []
      )
    )
  )

}

struct NestedData: Codable, Equatable {
  let id: Int
  let tags: [String]
  let metadata: [String: String]
}

struct ComplexNestedStruct: Codable, Equatable {
  let name: String
  let values: [Int]
  let mapping: [String: Int]
  let nested: NestedData
}
