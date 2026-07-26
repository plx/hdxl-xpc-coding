import Foundation
import Testing
import XPC
@testable import XPCCoding

@Suite("Decoding Error Taxonomy")
struct DecodingErrorTaxonomyTests {

  @Test
  func `explicit null uses value-not-found at every value placement`() throws {
    for attempt in valueAttempts(
      decoding: Int.self,
      from: xpc_null_create()
    ) {
      let error = try requireDecodingError(attempt)
      expectValueNotFound(
        error,
        requestedType: Int.self,
        path: attempt.expectedPath,
        placement: attempt.placement
      )
    }

    for attempt in valueAttempts(
      decoding: String.self,
      from: xpc_null_create()
    ) {
      let error = try requireDecodingError(attempt)
      expectValueNotFound(
        error,
        requestedType: String.self,
        path: attempt.expectedPath,
        placement: "\(attempt.placement) String"
      )
    }

    let dataAttempt = TaxonomyAttempt(
      placement: "root Data",
      expectedPath: []
    ) {
      _ = try XPCDecoder.standard.decode(
        Data.self,
        from: xpc_null_create()
      )
    }
    expectValueNotFound(
      try requireDecodingError(dataAttempt),
      requestedType: Data.self,
      path: dataAttempt.expectedPath,
      placement: dataAttempt.placement
    )

    let keyedContainer = TaxonomyAttempt(
      placement: "root keyed container from null",
      expectedPath: []
    ) {
      _ = try XPCDecoder.standard.decode(
        KeyedContainerProbe.self,
        from: xpc_null_create()
      )
    }
    expectValueNotFound(
      try requireDecodingError(keyedContainer),
      requestedType: [String: Any].self,
      path: keyedContainer.expectedPath,
      placement: keyedContainer.placement
    )

    let unkeyedContainer = TaxonomyAttempt(
      placement: "root unkeyed container from null",
      expectedPath: []
    ) {
      _ = try XPCDecoder.standard.decode(
        UnkeyedContainerProbe.self,
        from: xpc_null_create()
      )
    }
    expectValueNotFound(
      try requireDecodingError(unkeyedContainer),
      requestedType: [Any].self,
      path: unkeyedContainer.expectedPath,
      placement: unkeyedContainer.placement
    )
  }

  @Test
  func `wrong value kinds use type-mismatch at every value placement`() throws {
    for attempt in valueAttempts(
      decoding: String.self,
      from: xpc_int64_create(17)
    ) {
      let error = try requireDecodingError(attempt)
      expectTypeMismatch(
        error,
        requestedType: String.self,
        path: attempt.expectedPath,
        placement: attempt.placement
      )
    }

    let narrowIntegerFromHistoricalData = TaxonomyAttempt(
      placement: "root Int16 from XPC data",
      expectedPath: []
    ) {
      _ = try XPCDecoder.standard.decode(
        Int16.self,
        from: xpcData([0, 0])
      )
    }
    expectTypeMismatch(
      try requireDecodingError(narrowIntegerFromHistoricalData),
      requestedType: Int16.self,
      path: [],
      placement: narrowIntegerFromHistoricalData.placement
    )
  }

  @Test
  func `wrong container kinds use type-mismatch at exact paths`() throws {
    let rootKeyed = TaxonomyAttempt(
      placement: "root keyed container",
      expectedPath: []
    ) {
      _ = try XPCDecoder.standard.decode(
        KeyedContainerProbe.self,
        from: xpc_array_create_empty()
      )
    }
    expectTypeMismatch(
      try requireDecodingError(rootKeyed),
      requestedType: [String: Any].self,
      path: rootKeyed.expectedPath,
      placement: rootKeyed.placement
    )

    let rootUnkeyed = TaxonomyAttempt(
      placement: "root unkeyed container",
      expectedPath: []
    ) {
      _ = try XPCDecoder.standard.decode(
        UnkeyedContainerProbe.self,
        from: xpc_dictionary_create_empty()
      )
    }
    expectTypeMismatch(
      try requireDecodingError(rootUnkeyed),
      requestedType: [Any].self,
      path: rootUnkeyed.expectedPath,
      placement: rootUnkeyed.placement
    )

    let keyedNestedKeyed = TaxonomyAttempt(
      placement: "keyed nested keyed container",
      expectedPath: ["outer"]
    ) {
      _ = try XPCDecoder.standard.decode(
        NestedKeyedContainerProbe.self,
        from: xpcDictionary(
          xpc_array_create_empty(),
          forKey: TaxonomyKey.outer.stringValue
        )
      )
    }
    expectTypeMismatch(
      try requireDecodingError(keyedNestedKeyed),
      requestedType: [String: Any].self,
      path: keyedNestedKeyed.expectedPath,
      placement: keyedNestedKeyed.placement
    )

    let keyedNestedUnkeyed = TaxonomyAttempt(
      placement: "keyed nested unkeyed container",
      expectedPath: ["outer"]
    ) {
      _ = try XPCDecoder.standard.decode(
        NestedUnkeyedContainerProbe.self,
        from: xpcDictionary(
          xpc_dictionary_create_empty(),
          forKey: TaxonomyKey.outer.stringValue
        )
      )
    }
    expectTypeMismatch(
      try requireDecodingError(keyedNestedUnkeyed),
      requestedType: [Any].self,
      path: keyedNestedUnkeyed.expectedPath,
      placement: keyedNestedUnkeyed.placement
    )

    let unkeyedNestedKeyed = TaxonomyAttempt(
      placement: "unkeyed nested keyed container",
      expectedPath: ["0"]
    ) {
      _ = try XPCDecoder.standard.decode(
        UnkeyedNestedKeyedContainerProbe.self,
        from: xpcArray(xpc_array_create_empty())
      )
    }
    expectTypeMismatch(
      try requireDecodingError(unkeyedNestedKeyed),
      requestedType: [String: Any].self,
      path: unkeyedNestedKeyed.expectedPath,
      placement: unkeyedNestedKeyed.placement
    )

    let unkeyedNestedUnkeyed = TaxonomyAttempt(
      placement: "unkeyed nested unkeyed container",
      expectedPath: ["0"]
    ) {
      _ = try XPCDecoder.standard.decode(
        UnkeyedNestedUnkeyedContainerProbe.self,
        from: xpcArray(xpc_dictionary_create_empty())
      )
    }
    expectTypeMismatch(
      try requireDecodingError(unkeyedNestedUnkeyed),
      requestedType: [Any].self,
      path: unkeyedNestedUnkeyed.expectedPath,
      placement: unkeyedNestedUnkeyed.placement
    )

    let keyedSuper = TaxonomyAttempt(
      placement: "keyed super decoder",
      expectedPath: [XPCCodingKey.superKey.stringValue]
    ) {
      _ = try XPCDecoder.standard.decode(
        KeyedSuperKeyedContainerProbe.self,
        from: xpcDictionary(
          xpc_array_create_empty(),
          forKey: XPCCodingKey.superKey.stringValue
        )
      )
    }
    expectTypeMismatch(
      try requireDecodingError(keyedSuper),
      requestedType: [String: Any].self,
      path: keyedSuper.expectedPath,
      placement: keyedSuper.placement
    )

    let unkeyedSuper = TaxonomyAttempt(
      placement: "unkeyed super decoder",
      expectedPath: ["0"]
    ) {
      _ = try XPCDecoder.standard.decode(
        UnkeyedSuperUnkeyedContainerProbe.self,
        from: xpcArray(xpc_dictionary_create_empty())
      )
    }
    expectTypeMismatch(
      try requireDecodingError(unkeyedSuper),
      requestedType: [Any].self,
      path: unkeyedSuper.expectedPath,
      placement: unkeyedSuper.placement
    )
  }

  @Test
  func `correct-kind malformed content uses data-corrupted at every placement`() throws {
    for attempt in valueAttempts(
      decoding: Int8.self,
      from: xpc_int64_create(128)
    ) {
      let error = try requireDecodingError(attempt)
      expectDataCorrupted(
        error,
        path: attempt.expectedPath,
        placement: "\(attempt.placement) out-of-range Int8"
      )
    }

    for attempt in valueAttempts(
      decoding: Int128.self,
      from: xpcData([UInt8](repeating: 0, count: 15))
    ) {
      let error = try requireDecodingError(attempt)
      expectDataCorrupted(
        error,
        path: attempt.expectedPath,
        placement: attempt.placement
      )
    }

    let percentDecoder = XPCDecoder(
      stringValueStrategy: .percentEscape
    )
    for attempt in valueAttempts(
      decoding: String.self,
      from: xpcString("%GG"),
      using: percentDecoder
    ) {
      let error = try requireDecodingError(attempt)
      let context = expectDataCorrupted(
        error,
        path: attempt.expectedPath,
        placement: attempt.placement
      )
      guard
        let extractionError = context?.underlyingError
          as? XPCStringExtractionError,
        case .unableToRemovePercentEscapes = extractionError
      else {
        Issue.record(
          "Expected the percent-grammar cause at \(attempt.placement)."
        )
        continue
      }
    }

    for attempt in valueAttempts(
      decoding: String.self,
      from: malformedUTF8XPCString()
    ) {
      let error = try requireDecodingError(attempt)
      let context = expectDataCorrupted(
        error,
        path: attempt.expectedPath,
        placement: attempt.placement
      )
      guard
        let extractionError = context?.underlyingError
          as? XPCStringExtractionError,
        case .unableToDecode = extractionError
      else {
        Issue.record(
          "Expected the malformed-UTF-8 cause at \(attempt.placement)."
        )
        continue
      }
    }

    let limits = XPCDecoder.ResourceLimits(
      maximumNestingDepth: 128,
      maximumContainerElementCount: 65_536,
      maximumTotalNodeCount: 262_144,
      maximumStringByteCount: 0,
      maximumDataByteCount: 32 * 1_024 * 1_024,
      maximumCumulativeByteCount: 64 * 1_024 * 1_024
    )
    let resourceAttempt = TaxonomyAttempt(
      placement: "root string resource limit",
      expectedPath: []
    ) {
      _ = try XPCDecoder(
        resourceLimits: limits
      ).decode(
        String.self,
        from: xpcString("x")
      )
    }
    expectDataCorrupted(
      try requireDecodingError(resourceAttempt),
      path: resourceAttempt.expectedPath,
      placement: resourceAttempt.placement
    )
  }

  @Test
  func `absent keyed values use key-not-found at their parent path`() throws {
    let rootAttempt = TaxonomyAttempt(
      placement: "root keyed lookup",
      expectedPath: []
    ) {
      _ = try XPCDecoder.standard.decode(
        KeyedValueProbe<Int>.self,
        from: xpc_dictionary_create_empty()
      )
    }
    expectKeyNotFound(
      try requireDecodingError(rootAttempt),
      key: TaxonomyKey.value,
      path: rootAttempt.expectedPath,
      placement: rootAttempt.placement
    )

    let nestedAttempt = TaxonomyAttempt(
      placement: "nested keyed lookup",
      expectedPath: ["outer"]
    ) {
      _ = try XPCDecoder.standard.decode(
        NestedValueProbe<Int>.self,
        from: xpcDictionary(
          xpc_dictionary_create_empty(),
          forKey: TaxonomyKey.outer.stringValue
        )
      )
    }
    expectKeyNotFound(
      try requireDecodingError(nestedAttempt),
      key: TaxonomyKey.value,
      path: nestedAttempt.expectedPath,
      placement: nestedAttempt.placement
    )
  }

}

private struct TaxonomyAttempt {

  let placement: String
  let expectedPath: [String]
  let operation: () throws -> Void

}

private enum TaxonomyKey: String, CodingKey {
  case value
  case outer
}

private struct KeyedValueProbe<Value: Decodable>: Decodable {
  let value: Value
}

private struct NestedValueProbe<Value: Decodable>: Decodable {
  let outer: KeyedValueProbe<Value>
}

private struct KeyedSuperValueProbe<Value: Decodable>: Decodable {

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: TaxonomyKey.self)
    _ = try Value(from: container.superDecoder())
  }

}

private struct UnkeyedSuperValueProbe<Value: Decodable>: Decodable {

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    _ = try Value(from: container.superDecoder())
  }

}

private struct KeyedContainerProbe: Decodable {

  init(from decoder: any Decoder) throws {
    _ = try decoder.container(keyedBy: TaxonomyKey.self)
  }

}

private struct UnkeyedContainerProbe: Decodable {

  init(from decoder: any Decoder) throws {
    _ = try decoder.unkeyedContainer()
  }

}

private struct NestedKeyedContainerProbe: Decodable {

  init(from decoder: any Decoder) throws {
    let root = try decoder.container(keyedBy: TaxonomyKey.self)
    _ = try root.nestedContainer(
      keyedBy: TaxonomyKey.self,
      forKey: .outer
    )
  }

}

private struct NestedUnkeyedContainerProbe: Decodable {

  init(from decoder: any Decoder) throws {
    let root = try decoder.container(keyedBy: TaxonomyKey.self)
    _ = try root.nestedUnkeyedContainer(forKey: .outer)
  }

}

private struct UnkeyedNestedKeyedContainerProbe: Decodable {

  init(from decoder: any Decoder) throws {
    var root = try decoder.unkeyedContainer()
    _ = try root.nestedContainer(keyedBy: TaxonomyKey.self)
  }

}

private struct UnkeyedNestedUnkeyedContainerProbe: Decodable {

  init(from decoder: any Decoder) throws {
    var root = try decoder.unkeyedContainer()
    _ = try root.nestedUnkeyedContainer()
  }

}

private struct KeyedSuperKeyedContainerProbe: Decodable {

  init(from decoder: any Decoder) throws {
    let root = try decoder.container(keyedBy: TaxonomyKey.self)
    let superDecoder = try root.superDecoder()
    _ = try superDecoder.container(keyedBy: TaxonomyKey.self)
  }

}

private struct UnkeyedSuperUnkeyedContainerProbe: Decodable {

  init(from decoder: any Decoder) throws {
    var root = try decoder.unkeyedContainer()
    let superDecoder = try root.superDecoder()
    _ = try superDecoder.unkeyedContainer()
  }

}

private func valueAttempts<Value: Decodable>(
  decoding valueType: Value.Type,
  from payload: xpc_object_t,
  using decoder: XPCDecoder = .standard
) -> [TaxonomyAttempt] {
  let keyed = xpcDictionary(
    payload,
    forKey: TaxonomyKey.value.stringValue
  )
  let unkeyed = xpcArray(payload)
  let nested = xpcDictionary(
    xpcDictionary(
      payload,
      forKey: TaxonomyKey.value.stringValue
    ),
    forKey: TaxonomyKey.outer.stringValue
  )
  let keyedSuper = xpcDictionary(
    payload,
    forKey: XPCCodingKey.superKey.stringValue
  )
  let unkeyedSuper = xpcArray(payload)

  return [
    TaxonomyAttempt(
      placement: "root",
      expectedPath: []
    ) {
      _ = try decoder.decode(
        valueType,
        from: payload
      )
    },
    TaxonomyAttempt(
      placement: "keyed",
      expectedPath: ["value"]
    ) {
      _ = try decoder.decode(
        KeyedValueProbe<Value>.self,
        from: keyed
      )
    },
    TaxonomyAttempt(
      placement: "unkeyed",
      expectedPath: ["0"]
    ) {
      _ = try decoder.decode(
        [Value].self,
        from: unkeyed
      )
    },
    TaxonomyAttempt(
      placement: "nested",
      expectedPath: ["outer", "value"]
    ) {
      _ = try decoder.decode(
        NestedValueProbe<Value>.self,
        from: nested
      )
    },
    TaxonomyAttempt(
      placement: "keyed super",
      expectedPath: [XPCCodingKey.superKey.stringValue]
    ) {
      _ = try decoder.decode(
        KeyedSuperValueProbe<Value>.self,
        from: keyedSuper
      )
    },
    TaxonomyAttempt(
      placement: "unkeyed super",
      expectedPath: ["0"]
    ) {
      _ = try decoder.decode(
        UnkeyedSuperValueProbe<Value>.self,
        from: unkeyedSuper
      )
    },
  ]
}

private func requireDecodingError(
  _ attempt: TaxonomyAttempt,
  sourceLocation: SourceLocation = #_sourceLocation
) throws -> DecodingError {
  try #require(
    throws: DecodingError.self,
    "Expected a DecodingError at \(attempt.placement).",
    sourceLocation: sourceLocation,
    performing: attempt.operation
  )
}

private func expectValueNotFound(
  _ error: DecodingError,
  requestedType: Any.Type,
  path: [String],
  placement: String,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  guard case .valueNotFound(let actualType, let context) = error else {
    Issue.record(
      """
      Expected valueNotFound at \(placement), received \
      \(String(reflecting: error)).
      """,
      sourceLocation: sourceLocation
    )
    return
  }
  expectSameMetatype(
    actualType,
    requestedType,
    placement: placement,
    sourceLocation: sourceLocation
  )
  expectPath(
    context.codingPath,
    path,
    placement: placement,
    sourceLocation: sourceLocation
  )
  #expect(
    context.underlyingError == nil,
    "valueNotFound exposed an underlying implementation error at \(placement).",
    sourceLocation: sourceLocation
  )
}

private func expectTypeMismatch(
  _ error: DecodingError,
  requestedType: Any.Type,
  path: [String],
  placement: String,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  guard case .typeMismatch(let actualType, let context) = error else {
    Issue.record(
      """
      Expected typeMismatch at \(placement), received \
      \(String(reflecting: error)).
      """,
      sourceLocation: sourceLocation
    )
    return
  }
  expectSameMetatype(
    actualType,
    requestedType,
    placement: placement,
    sourceLocation: sourceLocation
  )
  expectPath(
    context.codingPath,
    path,
    placement: placement,
    sourceLocation: sourceLocation
  )
  #expect(
    context.underlyingError == nil,
    "typeMismatch exposed an underlying implementation error at \(placement).",
    sourceLocation: sourceLocation
  )
}

@discardableResult
private func expectDataCorrupted(
  _ error: DecodingError,
  path: [String],
  placement: String,
  sourceLocation: SourceLocation = #_sourceLocation
) -> DecodingError.Context? {
  guard case .dataCorrupted(let context) = error else {
    Issue.record(
      """
      Expected dataCorrupted at \(placement), received \
      \(String(reflecting: error)).
      """,
      sourceLocation: sourceLocation
    )
    return nil
  }
  expectPath(
    context.codingPath,
    path,
    placement: placement,
    sourceLocation: sourceLocation
  )
  return context
}

private func expectKeyNotFound(
  _ error: DecodingError,
  key: any CodingKey,
  path: [String],
  placement: String,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  guard case .keyNotFound(let actualKey, let context) = error else {
    Issue.record(
      """
      Expected keyNotFound at \(placement), received \
      \(String(reflecting: error)).
      """,
      sourceLocation: sourceLocation
    )
    return
  }
  #expect(
    actualKey.stringValue == key.stringValue,
    "The missing key changed at \(placement).",
    sourceLocation: sourceLocation
  )
  #expect(
    actualKey.intValue == key.intValue,
    "The missing key's integer value changed at \(placement).",
    sourceLocation: sourceLocation
  )
  expectPath(
    context.codingPath,
    path,
    placement: placement,
    sourceLocation: sourceLocation
  )
  #expect(
    context.underlyingError == nil,
    "keyNotFound exposed an underlying implementation error at \(placement).",
    sourceLocation: sourceLocation
  )
}

private func expectSameMetatype(
  _ actualType: Any.Type,
  _ expectedType: Any.Type,
  placement: String,
  sourceLocation: SourceLocation
) {
  #expect(
    ObjectIdentifier(actualType) == ObjectIdentifier(expectedType),
    """
    The requested type changed at \(placement): expected \
    \(String(reflecting: expectedType)), received \
    \(String(reflecting: actualType)).
    """,
    sourceLocation: sourceLocation
  )
}

private func expectPath(
  _ actualPath: [any CodingKey],
  _ expectedPath: [String],
  placement: String,
  sourceLocation: SourceLocation
) {
  #expect(
    actualPath.map(\.stringValue) == expectedPath,
    "The coding path was incorrect at \(placement).",
    sourceLocation: sourceLocation
  )
}

private func xpcDictionary(
  _ value: xpc_object_t,
  forKey key: String
) -> xpc_object_t {
  let dictionary = xpc_dictionary_create_empty()
  xpc_dictionary_set_value(
    dictionary,
    key,
    value
  )
  return dictionary
}

private func xpcArray(_ value: xpc_object_t) -> xpc_object_t {
  let array = xpc_array_create_empty()
  xpc_array_append_value(
    array,
    value
  )
  return array
}

private func xpcData(_ bytes: [UInt8]) -> xpc_object_t {
  bytes.withUnsafeBytes { buffer in
    xpc_data_create(
      buffer.baseAddress,
      buffer.count
    )
  }
}

private func malformedUTF8XPCString() -> xpc_object_t {
  let bytes: [CChar] = [-1, 0]
  return bytes.withUnsafeBufferPointer { buffer in
    guard let baseAddress = buffer.baseAddress else {
      preconditionFailure("A nonempty test buffer must have a base address.")
    }
    return xpc_string_create(baseAddress)
  }
}
