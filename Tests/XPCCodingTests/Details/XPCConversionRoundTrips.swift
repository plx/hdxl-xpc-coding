import Foundation
import XPC
import Testing
@testable import XPCCoding

@Suite("XPC Conversion Round-Trips")
private struct XPCConversionRoundTrips {

  @Test(arguments: [true, false])
  private func `Bool round-trips`(value: Bool) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: (0...255 as ClosedRange<UInt8>))
  private func `UInt8 round-trips`(value: UInt8) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: (0...100 as ClosedRange<UInt16>))
  private func `UInt16 round-trips`(value: UInt16) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: (0...100 as ClosedRange<UInt32>))
  private func `UInt32 round-trips`(value: UInt32) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: (0...100 as ClosedRange<UInt64>))
  private func `UInt64 round-trips`(value: UInt64) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: (0...100 as ClosedRange<UInt128>))
  private func `UInt128 round-trips`(value: UInt128) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: (0...100 as ClosedRange<UInt>))
  private func `UInt round-trips`(value: UInt) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: (-128...127 as ClosedRange<Int8>))
  private func `Int8 round-trips`(value: Int8) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: (0...100 as ClosedRange<Int16>))
  private func `Int16 round-trips`(value: Int16) throws {
    try verifyXPCConversion(of: value)
  }
  
  @Test(arguments: (0...100 as ClosedRange<Int32>))
  private func `Int32 round-trips`(value: Int32) throws {
    try verifyXPCConversion(of: value)
  }
  
  @Test(arguments: (0...100 as ClosedRange<Int64>))
  private func `Int64 round-trips`(value: Int64) throws {
    try verifyXPCConversion(of: value)
  }
  
  @Test(arguments: (0...100 as ClosedRange<Int128>))
  private func `Int128 round-trips`(value: Int128) throws {
    try verifyXPCConversion(of: value)
  }
  
  @Test(arguments: (0...100 as ClosedRange<Int>))
  private func `Int round-trips`(value: Int) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: Array(stride(from: -10.0 as Float16, to: 10.0 as Float16, by: 1.0 as Float16)))
  private func `Float16 round-trips`(value: Float16) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: Array(stride(from: -10.0 as Float, to: 10.0 as Float, by: 1.0 as Float)))
  private func `Float round-trips`(value: Float) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: Array(stride(from: -10.0 as Double, to: 10.0 as Double, by: 1.0 as Double)))
  private func `Double round-trips`(value: Double) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: [
    "",
    "a",
    "ab",
    "abc",
    "abcd"
  ])
  private func `String round-trips`(value: String) throws {
    try verifyXPCConversion(of: value)
  }

  @Test(arguments: [0, 1, 2, 4, 8, 16, 32, 64, 128, 256, 4096], [0, 1, 2, 254, 255] as [UInt8])
  private func `String round-trips`(length: Int, value: UInt8) throws {
    try verifyXPCConversion(of: Data(repeating: value, count: length))
  }
  

}

private func verifyXPCConversion<T>(
  of value: T,
  sourceLocation: SourceLocation = #_sourceLocation
) throws where T: Equatable & XPCObjectConvertible & XPCObjectExtractable {
  let xpcObject = try value.makeXPCObjectRepresentation()
  #expect(
    xpc_get_type(xpcObject) == T.associatedXPCObjectType,
    """
    Found mismatch in conversion and extraction types for \(T.self):
    
    - value: \(value)
    - expected-type: \(T.associatedXPCObjectType.typeDescription)
    - observed-type: \(xpcObject.typeDescription)
    """,
    sourceLocation: sourceLocation
  )
  let roundTripped = try #require(
    T.extracting(from: xpcObject),
    """
    Expected successful extraction of \(T.self) value from \(xpcObject) created-from \(value)!
    """,
    sourceLocation: sourceLocation
  )
  #expect(
    value == roundTripped,
    """
    Found mismatch between original and round-tripped values for \(T.self):
    
    - value: \(value)
    - roundTripped: \(roundTripped)
    """
  )
}

