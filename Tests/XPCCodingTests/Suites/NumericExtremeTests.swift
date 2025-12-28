import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Edge Cases Test Suite

@Suite(.tags(.edgeCases))
struct `Numeric Extremes` {
  
  
  // MARK: - Signed Integers
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, Int8.extremeValues
  )
  func `min/max (Int8)`(
    configuration: XPCCodec.Configuration,
    probe: Int8
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, Int16.extremeValues
  )
  func `min/max (Int16)`(
    configuration: XPCCodec.Configuration,
    probe: Int16
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, Int32.extremeValues
  )
  func `min/max (Int32)`(
    configuration: XPCCodec.Configuration,
    probe: Int32
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, Int64.extremeValues
  )
  func `min/max (Int64)`(
    configuration: XPCCodec.Configuration,
    probe: Int64
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, Int128.extremeValues
  )
  func `min/max (Int128)`(
    configuration: XPCCodec.Configuration,
    probe: Int128
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, Int.extremeValues
  )
  func `min/max (Int)`(
    configuration: XPCCodec.Configuration,
    probe: Int
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  // MARK: - Unsigned Integers
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, UInt8.extremeValues
  )
  func `min/max (UInt8)`(
    configuration: XPCCodec.Configuration,
    probe: UInt8
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, UInt16.extremeValues
  )
  func `min/max (UInt16)`(
    configuration: XPCCodec.Configuration,
    probe: UInt16
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, UInt32.extremeValues
  )
  func `min/max (UInt32)`(
    configuration: XPCCodec.Configuration,
    probe: UInt32
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, UInt64.extremeValues
  )
  func `min/max (UInt64)`(
    configuration: XPCCodec.Configuration,
    probe: UInt64
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, UInt128.extremeValues
  )
  func `min/max (UInt128)`(
    configuration: XPCCodec.Configuration,
    probe: UInt128
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, UInt.extremeValues
  )
  func `min/max (UInt)`(
    configuration: XPCCodec.Configuration,
    probe: UInt
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    )
  }
  
  // MARK: - Floating-Point
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, Float16.extremeValues
  )
  func `extremes (Float16)`(
    configuration: XPCCodec.Configuration,
    probe: Float16
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    ) { lhs, rhs in
      equivalentFloats(lhs, rhs)
    }
  }
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, Float.extremeValues
  )
  func `extremes (Float)`(
    configuration: XPCCodec.Configuration,
    probe: Float
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    ) { lhs, rhs in
      equivalentFloats(lhs, rhs)
    }
  }
  
  @Test(
    .tags(.roundTrip, .primitives),
    arguments: XPCCodec.Configuration.allCases, Double.extremeValues
  )
  func `extremes (Double)`(
    configuration: XPCCodec.Configuration,
    probe: Double
  ) throws {
    try verifyRoundTrip(
      of: probe,
      configuration: configuration
    ) { lhs, rhs in
      equivalentFloats(lhs, rhs)
    }
  }
}

extension FixedWidthInteger {
  
  static var extremeValues: [Self] {
    [
      .min,
      .max
    ]
  }
}

extension BinaryFloatingPoint {
  
  static var extremeValues: [Self] {
    [
      .greatestFiniteMagnitude,
      -.greatestFiniteMagnitude,
      .leastNormalMagnitude,
      -.leastNormalMagnitude,
      .leastNonzeroMagnitude,
      -.leastNonzeroMagnitude,
      .infinity,
      -.infinity,
      .ulpOfOne,
      -.ulpOfOne,
      .nan,
      .signalingNaN
    ]
  }
}
