import Benchmark
import Foundation
import XPCCoding

// MARK: - Benchmark Entry Point

let benchmarks: @Sendable () -> Void = {
  // Simple struct benchmarks
  simpleStructBenchmarks()

  // Many fields benchmarks
  manyFieldsBenchmarks()

  // Binary data benchmarks
  binaryDataBenchmarks()

  // Nested structure benchmarks
  nestedBenchmarks()

  // Collection benchmarks
  collectionBenchmarks()

  // Complex message benchmarks
  complexMessageBenchmarks()

  // Enum benchmarks
  enumBenchmarks()
}

// MARK: - Simple Struct Benchmarks

private func simpleStructBenchmarks() {
  let value = SimpleStruct.example

  Benchmark("SimpleStruct.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(value))
  }

  Benchmark("SimpleStruct.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(value))
  }

  Benchmark("SimpleStruct.decode.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(SimpleStruct.self, from: encoded))
  }

  Benchmark("SimpleStruct.decode.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(SimpleStruct.self, from: encoded))
  }

  Benchmark("SimpleStruct.roundtrip.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(SimpleStruct.self, from: encoded))
  }

  Benchmark("SimpleStruct.roundtrip.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(SimpleStruct.self, from: encoded))
  }
}

// MARK: - Many Fields Benchmarks

private func manyFieldsBenchmarks() {
  let value = ManyFieldsStruct.example

  Benchmark("ManyFields.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(value))
  }

  Benchmark("ManyFields.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(value))
  }

  Benchmark("ManyFields.decode.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(ManyFieldsStruct.self, from: encoded))
  }

  Benchmark("ManyFields.decode.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(ManyFieldsStruct.self, from: encoded))
  }

  Benchmark("ManyFields.roundtrip.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(ManyFieldsStruct.self, from: encoded))
  }

  Benchmark("ManyFields.roundtrip.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(ManyFieldsStruct.self, from: encoded))
  }
}

// MARK: - Binary Data Benchmarks

private func binaryDataBenchmarks() {
  // Small binary data (100 bytes)
  let small = PureBinaryStruct.ofSize(100)

  Benchmark("BinaryData.100B.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(small))
  }

  Benchmark("BinaryData.100B.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(small))
  }

  // Medium binary data (10KB)
  let medium = PureBinaryStruct.ofSize(10_000)

  Benchmark("BinaryData.10KB.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(medium))
  }

  Benchmark("BinaryData.10KB.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(medium))
  }

  // Large binary data (100KB)
  let large = PureBinaryStruct.ofSize(100_000)

  Benchmark("BinaryData.100KB.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(large))
  }

  Benchmark("BinaryData.100KB.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(large))
  }

  // Binary roundtrip benchmarks
  Benchmark("BinaryData.100B.roundtrip.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(small)
    blackHole(try decoder.decode(PureBinaryStruct.self, from: encoded))
  }

  Benchmark("BinaryData.100B.roundtrip.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(small)
    blackHole(try decoder.decode(PureBinaryStruct.self, from: encoded))
  }

  Benchmark("BinaryData.10KB.roundtrip.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(medium)
    blackHole(try decoder.decode(PureBinaryStruct.self, from: encoded))
  }

  Benchmark("BinaryData.10KB.roundtrip.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(medium)
    blackHole(try decoder.decode(PureBinaryStruct.self, from: encoded))
  }

  Benchmark("BinaryData.100KB.roundtrip.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(large)
    blackHole(try decoder.decode(PureBinaryStruct.self, from: encoded))
  }

  Benchmark("BinaryData.100KB.roundtrip.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(large)
    blackHole(try decoder.decode(PureBinaryStruct.self, from: encoded))
  }

  // Mixed binary data struct
  let mixed = BinaryDataStruct.example

  Benchmark("BinaryData.mixed.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(mixed))
  }

  Benchmark("BinaryData.mixed.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(mixed))
  }

  Benchmark("BinaryData.mixed.roundtrip.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(mixed)
    blackHole(try decoder.decode(BinaryDataStruct.self, from: encoded))
  }

  Benchmark("BinaryData.mixed.roundtrip.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(mixed)
    blackHole(try decoder.decode(BinaryDataStruct.self, from: encoded))
  }
}

// MARK: - Nested Structure Benchmarks

private func nestedBenchmarks() {
  let value = DeepNesting.example

  Benchmark("DeepNesting.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(value))
  }

  Benchmark("DeepNesting.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(value))
  }

  Benchmark("DeepNesting.decode.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(DeepNesting.self, from: encoded))
  }

  Benchmark("DeepNesting.decode.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(DeepNesting.self, from: encoded))
  }

  Benchmark("DeepNesting.roundtrip.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(DeepNesting.self, from: encoded))
  }

  Benchmark("DeepNesting.roundtrip.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(DeepNesting.self, from: encoded))
  }
}

// MARK: - Collection Benchmarks

private func collectionBenchmarks() {
  // Array benchmarks at different sizes
  let smallArrays = ArraysStruct.small
  let mediumArrays = ArraysStruct.medium
  let largeArrays = ArraysStruct.large

  Benchmark("Arrays.small.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(smallArrays))
  }

  Benchmark("Arrays.small.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(smallArrays))
  }

  Benchmark("Arrays.medium.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(mediumArrays))
  }

  Benchmark("Arrays.medium.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(mediumArrays))
  }

  Benchmark("Arrays.large.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(largeArrays))
  }

  Benchmark("Arrays.large.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(largeArrays))
  }

  // Array roundtrip
  Benchmark("Arrays.medium.roundtrip.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(mediumArrays)
    blackHole(try decoder.decode(ArraysStruct.self, from: encoded))
  }

  Benchmark("Arrays.medium.roundtrip.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(mediumArrays)
    blackHole(try decoder.decode(ArraysStruct.self, from: encoded))
  }

  // Dictionary benchmarks
  let smallDict = DictionaryStruct.small
  let mediumDict = DictionaryStruct.medium
  let largeDict = DictionaryStruct.large

  Benchmark("Dictionary.small.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(smallDict))
  }

  Benchmark("Dictionary.small.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(smallDict))
  }

  Benchmark("Dictionary.medium.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(mediumDict))
  }

  Benchmark("Dictionary.medium.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(mediumDict))
  }

  Benchmark("Dictionary.large.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(largeDict))
  }

  Benchmark("Dictionary.large.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(largeDict))
  }

  // Dictionary roundtrip
  Benchmark("Dictionary.medium.roundtrip.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(mediumDict)
    blackHole(try decoder.decode(DictionaryStruct.self, from: encoded))
  }

  Benchmark("Dictionary.medium.roundtrip.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(mediumDict)
    blackHole(try decoder.decode(DictionaryStruct.self, from: encoded))
  }
}

// MARK: - Complex Message Benchmarks

private func complexMessageBenchmarks() {
  let value = ComplexMessage.example

  Benchmark("ComplexMessage.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(value))
  }

  Benchmark("ComplexMessage.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(value))
  }

  Benchmark("ComplexMessage.decode.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(ComplexMessage.self, from: encoded))
  }

  Benchmark("ComplexMessage.decode.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(ComplexMessage.self, from: encoded))
  }

  Benchmark("ComplexMessage.roundtrip.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(ComplexMessage.self, from: encoded))
  }

  Benchmark("ComplexMessage.roundtrip.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(ComplexMessage.self, from: encoded))
  }

  // Larger complex message with more attachments
  let largeMessage = ComplexMessage.example(attachmentCount: 10, attachmentSize: 10_000)

  Benchmark("ComplexMessage.large.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(largeMessage))
  }

  Benchmark("ComplexMessage.large.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(largeMessage))
  }

  Benchmark("ComplexMessage.large.roundtrip.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(largeMessage)
    blackHole(try decoder.decode(ComplexMessage.self, from: encoded))
  }

  Benchmark("ComplexMessage.large.roundtrip.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(largeMessage)
    blackHole(try decoder.decode(ComplexMessage.self, from: encoded))
  }
}

// MARK: - Enum Benchmarks

private func enumBenchmarks() {
  let value = StatusContainer.example

  Benchmark("Enums.encode.xpc") { _ in
    let encoder = XPCEncoder()
    blackHole(try encoder.encode(value))
  }

  Benchmark("Enums.encode.json") { _ in
    let encoder = JSONEncoder()
    blackHole(try encoder.encode(value))
  }

  Benchmark("Enums.decode.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(StatusContainer.self, from: encoded))
  }

  Benchmark("Enums.decode.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(StatusContainer.self, from: encoded))
  }

  Benchmark("Enums.roundtrip.xpc") { _ in
    let encoder = XPCEncoder()
    let decoder = XPCDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(StatusContainer.self, from: encoded))
  }

  Benchmark("Enums.roundtrip.json") { _ in
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(value)
    blackHole(try decoder.decode(StatusContainer.self, from: encoded))
  }
}
