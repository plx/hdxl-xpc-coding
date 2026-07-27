import Testing
import Foundation
import XPC
@testable import XPCCoding

/// Tests exercising deeply-nested values.
@Suite(.tags(.edgeCases))
struct `Nested-Value Tests` {

  @Test(
    .tags(.roundTrip, .nested),
    arguments: XPCCodec.Configuration.allCases, Deep15.exampleValues
  )
  func `Deep Nesting (15 levels)`(
    configuration: XPCCodec.Configuration,
    probe: Deep15
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  // MARK: - Wide Structure

  @Test(
    .tags(.roundTrip, .keyed),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Wide Structure`(
    configuration: XPCCodec.Configuration
  ) throws {
    var dict: [String: Int] = [:]
    for i in 0..<100 {
      dict["key\(i)"] = i
    }

    try verifyRoundTrip(
      ofValueAndWrappers: dict,
      configuration: configuration
    )
  }

  // MARK: - Empty Nested Containers

  @Test(
    .tags(.roundTrip, .nested),
    arguments: XPCCodec.Configuration.allCases, EmptyContainerStruct.testValues
  )
  func `Nested Containers`(
    configuration: XPCCodec.Configuration,
    probe: EmptyContainerStruct
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  // MARK: - Alternating Structures

  @Test(
    .tags(.roundTrip, .nested),
    arguments: XPCCodec.Configuration.allCases
  )
  func `Alternating Structures`(configuration: XPCCodec.Configuration) throws {
    let foo: [Int] = [1, 2, 3]
    let bar: [Int: [Int]] = [
      1: [1],
      2: [2],
      3: [3],
    ]
    let baz: [Int: [[Int: [Int]]]] = [
      0: [],
      1: [
        [
          1: [1]
        ],
        [
          2: [2, 1],
          3: [3, 2, 1],
        ],
      ],
      2: [
        [
          2: [4],
          8: [16],
          7: [15],
          3: [4, 5, 6],
        ],
        [
          32: [64, 128],
          256: [512, 1024, 2048],
        ],
        [
          11: [22, 33, 44, 55]
        ],
      ],
      3: [],
    ]

    let quux: [Int: [[Int: [Int]]]] = [:]
    try verifyRoundTrip(
      ofValueAndWrappers: foo,
      configuration: configuration
    )
    try verifyRoundTrip(
      ofValueAndWrappers: bar,
      configuration: configuration
    )
    try verifyRoundTrip(
      ofValueAndWrappers: baz,
      configuration: configuration
    )
    try verifyRoundTrip(
      ofValueAndWrappers: quux,
      configuration: configuration
    )
  }

}
