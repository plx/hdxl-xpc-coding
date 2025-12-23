// Tests/XPCCodingTests/Suites/PrimitiveTypeTests.swift
// Comprehensive tests for primitive type encoding/decoding
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Primitive Types Test Suite

/// Verifies that types with directly-associated "xpc types" round-trip when encoded as top-level values.
@Suite("Primitive Types", .tags(.primitives))
struct PrimitiveTypeTests {

  // MARK: - Ints
  
  @Test(arguments: Int8.exampleValues)
  func `Int8 round-trip`(probe: Int8) throws {
    try verifyRoundTrip(of: probe)
  }
  
  @Test(arguments: Int16.exampleValues)
  func `Int16 round-trip`(probe: Int16) throws {
    try verifyRoundTrip(of: probe)
  }
  
  @Test(arguments: Int32.exampleValues)
  func `Int32 round-trip`(probe: Int32) throws {
    try verifyRoundTrip(of: probe)
  }
  
  @Test(arguments: Int64.exampleValues)
  func `Int64 round-trip`(probe: Int64) throws {
    try verifyRoundTrip(of: probe)
  }
  
  @Test(arguments: Int128.exampleValues)
  func `Int128 round-trip`(probe: Int128) throws {
    try verifyRoundTrip(of: probe)
  }
  
  @Test(arguments: Int.exampleValues)
  func `Int round-trip`(probe: Int) throws {
    try verifyRoundTrip(of: probe)
  }

  // MARK: - UInts
  
  @Test(arguments: UInt8.exampleValues)
  func `UInt8 round-trip`(probe: UInt8) throws {
    try verifyRoundTrip(of: probe)
  }

  @Test(arguments: UInt16.exampleValues)
  func `UInt16 round-trip`(probe: UInt16) throws {
    try verifyRoundTrip(of: probe)
  }

  @Test(arguments: UInt32.exampleValues)
  func `UInt32 round-trip`(probe: UInt32) throws {
    try verifyRoundTrip(of: probe)
  }

  @Test(arguments: UInt64.exampleValues)
  func `UInt64 round-trip`(probe: UInt64) throws {
    try verifyRoundTrip(of: probe)
  }

  @Test(arguments: UInt128.exampleValues)
  func `UInt128 round-trip`(probe: UInt128) throws {
    try verifyRoundTrip(of: probe)
  }

  @Test(arguments: UInt.exampleValues)
  func `UInt round-trip`(probe: UInt) throws {
    try verifyRoundTrip(of: probe)
  }
  
  // MARK: - Floating-Point

  @Test(arguments: Float16.exampleValues)
  func `Float16 round-trip`(probe: Float16) throws {
    // need `equivalentFloats` to detect NaN round-trips
    try verifyRoundTrip(of: probe) { equivalentFloats($0, $1) }
  }

  @Test(arguments: Float.exampleValues)
  func `Float round-trip`(probe: Float) throws {
    // need `equivalentFloats` to detect NaN round-trips
    try verifyRoundTrip(of: probe) { equivalentFloats($0, $1) }
  }

  @Test(arguments: Double.exampleValues)
  func `Double round-trip`(probe: Double) throws {
    // need `equivalentFloats` to detect NaN round-trips
    try verifyRoundTrip(of: probe) { equivalentFloats($0, $1) }
  }

  // MARK: - Others
  
  @Test(arguments: Bool.exampleValues)
  func `Bool round-trip`(probe: Bool) throws {
    try verifyRoundTrip(of: probe)
  }
  
  @Test(arguments: Data.exampleValues)
  func `Data round-trip`(probe: Data) throws {
    try verifyRoundTrip(of: probe)
  }
  
  @Test(arguments: String.exampleValues)
  func `String round-trip`(probe: String) throws {
    try verifyRoundTrip(of: probe)
  }

}
