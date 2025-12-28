import Foundation
import XPC
import Testing
@testable import XPCCoding

@Suite("XPC Conversion Round-Trips")
private struct XPCConversionRoundTrips {

  @Test(arguments: Bool.exampleValues)
  private func `Bool round-trips`(value: Bool) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: UInt8.exampleValues)
  private func `UInt8 round-trips`(value: UInt8) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: UInt16.exampleValues)
  private func `UInt16 round-trips`(value: UInt16) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: UInt32.exampleValues)
  private func `UInt32 round-trips`(value: UInt32) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: UInt64.exampleValues)
  private func `UInt64 round-trips`(value: UInt64) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: UInt128.exampleValues)
  private func `UInt128 round-trips`(value: UInt128) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: UInt.exampleValues)
  private func `UInt round-trips`(value: UInt) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: Int8.exampleValues)
  private func `Int8 round-trips`(value: Int8) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: (0...100 as ClosedRange<Int16>))
  private func `Int16 round-trips`(value: Int16) throws {
    try verifyXPCConversion(of: value)
  }
  
  @Test(arguments: Int32.exampleValues)
  private func `Int32 round-trips`(value: Int32) throws {
    try verifyXPCConversion(of: value)
  }
  
  @Test(arguments: Int64.exampleValues)
  private func `Int64 round-trips`(value: Int64) throws {
    try verifyXPCConversion(of: value)
  }
  
  @Test(arguments: Int128.exampleValues)
  private func `Int128 round-trips`(value: Int128) throws {
    try verifyXPCConversion(of: value)
  }
  
  @Test(arguments: Int.exampleValues)
  private func `Int round-trips`(value: Int) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: Float16.exampleValues)
  private func `Float16 round-trips`(value: Float16) throws {
    try verifyXPCConversion(of: value) { lhs, rhs in
      equivalentFloats(lhs, rhs)
    }
  }

  @Test(arguments: Float.exampleValues)
  private func `Float round-trips`(value: Float) throws {
    try verifyXPCConversion(of: value) { lhs, rhs in
      equivalentFloats(lhs, rhs)
    }
  }

  @Test(arguments: Double.exampleValues)
  private func `Double round-trips`(value: Double) throws {
    try verifyXPCConversion(of: value) { lhs, rhs in
      equivalentFloats(lhs, rhs)
    }
  }

  @Test(arguments: String.nullFreeExampleValues, XPCCodec.StringValueStrategy.allCases)
  private func `String round-trips`(
    probe: String,
    stringValueStrategy: XPCCodec.StringValueStrategy
  ) throws {
    try verifyXPCConversion(
      forStringValueWithoutEmbeddedNullBytes: probe,
      stringValueStrategy: stringValueStrategy
    )
  }

  @Test(arguments: [0, 1, 2, 4, 8, 16, 32, 64, 128, 256, 4096], [0, 1, 2, 254, 255] as [UInt8])
  private func `Data round-trips`(length: Int, value: UInt8) throws {
    try verifyXPCConversion(
      of: Data(
        repeating: value,
        count: length
      )
    )
  }
  
}
