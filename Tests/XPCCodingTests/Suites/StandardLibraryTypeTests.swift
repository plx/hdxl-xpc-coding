import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Standard Library Types Test Suite

@Suite("Standard Library Types", .tags(.standardLibrary))
struct StandardLibraryTypeTests {

  @Test(
    .tags(.roundTrip, .urls),
    arguments: XPCCodec.Configuration.allCases, URL.testExamples
  )
  func `URLs`(
    configuration: XPCCodec.Configuration,
    probe: URL
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .urls),
    arguments: XPCCodec.Configuration.allCases, URL.optionalTestExamples
  )
  func `URL?s`(
    configuration: XPCCodec.Configuration,
    probe: URL?
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .uuids),
    arguments: XPCCodec.Configuration.allCases, UUID.testExamples
  )
  func `UUIDs`(
    configuration: XPCCodec.Configuration,
    probe: UUID
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .uuids),
    arguments: XPCCodec.Configuration.allCases, UUID.optionalTestExamples
  )
  func `UUID?s`(
    configuration: XPCCodec.Configuration,
    probe: UUID?
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .dates),
    arguments: XPCCodec.Configuration.allCases, Date.testExamples
  )
  func `Dates`(
    configuration: XPCCodec.Configuration,
    probe: Date
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .dates),
    arguments: XPCCodec.Configuration.allCases, Date.optionalTestExamples
  )
  func `Dates`(
    configuration: XPCCodec.Configuration,
    probe: Date?
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .decimals),
    arguments: XPCCodec.Configuration.allCases, Decimal.testExamples
  )
  func `Decimals`(
    configuration: XPCCodec.Configuration,
    probe: Decimal
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip, .decimals),
    arguments: XPCCodec.Configuration.allCases, Decimal.optionalTestExamples
  )
  func `Decimal?s`(
    configuration: XPCCodec.Configuration,
    probe: Decimal?
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

}
