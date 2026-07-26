import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: Nested Values

/// Tests verifying correct behavior under concurrency.
@Suite(.tags(.concurrency))
struct `Concurrency Tests` {

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Concurrent encode/decode`(
    configuration: XPCCodec.Configuration
  ) async throws {

    let values = (0..<100).map { i in
      SimpleStruct(
        stringField: "test\(i)",
        intField: i,
        doubleField: Double(i) * 3.14,
        boolField: i % 2 == 0
      )
    }
    let codec = XPCCodec(configuration: configuration)

    // Encode and decode all values concurrently, verifying round-trip
    try await withThrowingTaskGroup(of: (Int, Bool).self) { group in
      for (index, value) in values.enumerated() {
        group.addTask {
          // Keep each xpc_object_t within the task that produced it.
          let encoded = try codec.encode(value)
          let decoded = try codec.decode(SimpleStruct.self, from: encoded)
          let isEqual = (decoded == value)
          return (index, isEqual)
        }
      }

      // Verify all operations succeeded
      var successCount = 0
      for try await (_, isEqual) in group {
        #expect(isEqual)
        successCount += 1
      }

      // Verify we completed all tasks
      #expect(successCount == 100)
    }
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Concurrent encode/decode (Complex)`(
    configuration: XPCCodec.Configuration
  ) async throws {
    let complexValues = (0..<50).map { i in
      ComplexNestedStruct(
        name: "test\(i)",
        values: Array(0..<i),
        mapping: ["key\(i)": i, "double": i * 2, "triple": i * 3],
        nested: NestedData(
          id: i,
          tags: ["tag\(i)", "test", "concurrent"],
          metadata: ["index": "\(i)", "type": "test"]
        )
      )
    }
    let codec = XPCCodec(configuration: configuration)

    try await withThrowingTaskGroup(of: Bool.self) { group in
      for value in complexValues {
        group.addTask {
          let encoded = try codec.encode(value)
          let decoded = try codec.decode(ComplexNestedStruct.self, from: encoded)
          return decoded == value
        }
      }

      // Verify all succeeded
      var successCount = 0
      for try await isEqual in group {
        #expect(isEqual)
        successCount += 1
      }

      #expect(successCount == 50)
    }
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Concurrent encode/decode (Heterogeneous)`(
    configuration: XPCCodec.Configuration
  ) async throws {
    // Create different types of values to encode concurrently
    let intValues = (0..<25)
    let stringValues = (0..<25).map { "string\($0)" }
    let doubleValues = (0..<25).map { Double($0) * 3.14 }
    let boolValues = (0..<25).map { $0 % 2 == 0 }
    let codec = XPCCodec(configuration: configuration)

    try await withThrowingTaskGroup(of: Bool.self) { group in
      // Encode integers
      for value in intValues {
        group.addTask {
          let encoded = try codec.encode(value)
          let decoded = try codec.decode(Int.self, from: encoded)
          return decoded == value
        }
      }

      // Encode strings
      for value in stringValues {
        group.addTask {
          let encoded = try codec.encode(value)
          let decoded = try codec.decode(String.self, from: encoded)
          return decoded == value
        }
      }

      // Encode doubles
      for value in doubleValues {
        group.addTask {
          let encoded = try codec.encode(value)
          let decoded = try codec.decode(Double.self, from: encoded)
          return decoded == value
        }
      }

      // Encode bools
      for value in boolValues {
        group.addTask {
          let encoded = try codec.encode(value)
          let decoded = try codec.decode(Bool.self, from: encoded)
          return decoded == value
        }
      }

      // Verify all succeeded
      var successCount = 0
      for try await isEqual in group {
        #expect(isEqual)
        successCount += 1
      }

      #expect(successCount == 100)
    }
  }
}
