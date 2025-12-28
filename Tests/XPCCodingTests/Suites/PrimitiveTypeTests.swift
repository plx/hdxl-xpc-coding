import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Primitive Types Test Suite

/// Verifies that types with directly-associated "xpc types" round-trip when encoded as top-level values.
@Suite("Primitive Types", .tags(.primitives))
struct PrimitiveTypeTests {

  // MARK: - Ints
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Int8 round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in Int8.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Int16 round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in Int16.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Int32 round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in Int32.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Int64 round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in Int64.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Int128 round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in Int128.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Int round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in Int.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }

  // MARK: - UInts
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `UInt8 round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in UInt8.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `UInt16 round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in UInt16.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `UInt32 round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in UInt32.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `UInt64 round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in UInt64.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `UInt128 round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in UInt128.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `UInt round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in UInt.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }
  
  // MARK: - Floating-Point

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Float16 round-trip`(configuration: XPCCodec.Configuration) throws {
    // need `equivalentFloats` to detect NaN round-trips
    for probe in Float16.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      ) { equivalentFloats($0, $1) }
    }
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Float round-trip`(configuration: XPCCodec.Configuration) throws {
    // need `equivalentFloats` to detect NaN round-trips
    for probe in Float.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      ) { equivalentFloats($0, $1) }
    }
  }

  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Double round-trip`(configuration: XPCCodec.Configuration) throws {
    // need `equivalentFloats` to detect NaN round-trips
    for probe in Double.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      ) { equivalentFloats($0, $1) }
    }
  }

  // MARK: - Others
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Bool round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in Bool.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `Data round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in Data.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }
  
  @Test(arguments: XPCCodec.Configuration.allCases)
  func `String round-trip`(configuration: XPCCodec.Configuration) throws {
    for probe in String.exampleValues {
      try verifyRoundTrip(
        of: probe,
        configuration: configuration
      )
    }
  }

}
