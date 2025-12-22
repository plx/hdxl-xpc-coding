// Tests/XPCCodingTests/Suites/StandardLibraryTypeTests.swift
// Comprehensive tests for standard library type encoding/decoding
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: - Standard Library Types Test Suite

@Suite("Standard Library Types", .tags(.standardLibrary))
struct StandardLibraryTypeTests {

  // MARK: - URL Tests

  @Test("HTTP URL round-trips correctly", .tags(.roundTrip))
  func httpURLRoundTrip() throws {
    let url = URL(string: "http://example.com")!
    try verifyRoundTrip(of: PrimitiveWrapper(url))
  }

  @Test("HTTPS URL with path round-trips correctly", .tags(.roundTrip))
  func httpsURLWithPathRoundTrip() throws {
    let url = URL(string: "https://example.com/path")!
    try verifyRoundTrip(of: PrimitiveWrapper(url))
  }

  @Test("File URL round-trips correctly", .tags(.roundTrip))
  func fileURLRoundTrip() throws {
    let url = URL(fileURLWithPath: "/tmp/test.txt")
    try verifyRoundTrip(of: PrimitiveWrapper(url))
  }

  @Test("URL with query parameters round-trips correctly", .tags(.roundTrip))
  func urlWithQueryRoundTrip() throws {
    let url = URL(string: "https://example.com?foo=bar&baz=qux")!
    try verifyRoundTrip(of: PrimitiveWrapper(url))
  }

  @Test("URL with special characters round-trips correctly", .tags(.roundTrip))
  func urlWithSpecialCharactersRoundTrip() throws {
    // Percent-encoded special characters
    let url = URL(string: "https://example.com/path%20with%20spaces?name=John%20Doe")!
    try verifyRoundTrip(of: PrimitiveWrapper(url))
  }

  @Test("URL with port round-trips correctly", .tags(.roundTrip))
  func urlWithPortRoundTrip() throws {
    let url = URL(string: "https://example.com:8080/path")!
    try verifyRoundTrip(of: PrimitiveWrapper(url))
  }

  @Test("Complex URL with all components round-trips correctly", .tags(.roundTrip))
  func complexURLRoundTrip() throws {
    let url = URL(string: "https://user:pass@example.com:8080/path/to/resource?query=value&foo=bar#fragment")!
    try verifyRoundTrip(of: PrimitiveWrapper(url))
  }

  // MARK: - UUID Tests

  @Test("Random UUID round-trips correctly", .tags(.roundTrip))
  func randomUUIDRoundTrip() throws {
    let uuid = UUID()
    try verifyRoundTrip(of: PrimitiveWrapper(uuid))
  }

  @Test("Nil UUID round-trips correctly", .tags(.roundTrip))
  func nilUUIDRoundTrip() throws {
    let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    try verifyRoundTrip(of: PrimitiveWrapper(uuid))
  }

  @Test("Known UUID round-trips correctly", .tags(.roundTrip))
  func knownUUIDRoundTrip() throws {
    let uuid = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
    try verifyRoundTrip(of: PrimitiveWrapper(uuid))
  }

  @Test("Multiple different UUIDs round-trip correctly", .tags(.roundTrip))
  func multipleUUIDsRoundTrip() throws {
    let uuid1 = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
    let uuid2 = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!

    try verifyRoundTrip(of: PrimitiveWrapper(uuid1))
    try verifyRoundTrip(of: PrimitiveWrapper(uuid2))
  }

  // MARK: - Date Tests

  @Test("Current date round-trips correctly", .tags(.roundTrip))
  func currentDateRoundTrip() throws {
    let date = Date()
    try verifyRoundTrip(of: PrimitiveWrapper(date), areEqual: { a, b in
      // Allow for small floating point differences
      abs(a.value.timeIntervalSince(b.value)) < 0.001
    })
  }

  @Test("Epoch date round-trips correctly", .tags(.roundTrip))
  func epochDateRoundTrip() throws {
    let date = Date(timeIntervalSince1970: 0)
    try verifyRoundTrip(of: PrimitiveWrapper(date), areEqual: { a, b in
      abs(a.value.timeIntervalSince(b.value)) < 0.001
    })
  }

  @Test("Distant past round-trips correctly", .tags(.roundTrip))
  func distantPastRoundTrip() throws {
    let date = Date.distantPast
    try verifyRoundTrip(of: PrimitiveWrapper(date), areEqual: { a, b in
      abs(a.value.timeIntervalSince(b.value)) < 0.001
    })
  }

  @Test("Distant future round-trips correctly", .tags(.roundTrip))
  func distantFutureRoundTrip() throws {
    let date = Date.distantFuture
    try verifyRoundTrip(of: PrimitiveWrapper(date), areEqual: { a, b in
      abs(a.value.timeIntervalSince(b.value)) < 0.001
    })
  }

  @Test("Date with fractional seconds round-trips correctly", .tags(.roundTrip))
  func dateWithFractionalSecondsRoundTrip() throws {
    let date = Date(timeIntervalSince1970: 1234567890.123456)
    try verifyRoundTrip(of: PrimitiveWrapper(date), areEqual: { a, b in
      abs(a.value.timeIntervalSince(b.value)) < 0.001
    })
  }

  @Test("Specific date round-trips correctly", .tags(.roundTrip))
  func specificDateRoundTrip() throws {
    // 2024-01-15 12:30:45 UTC
    let date = Date(timeIntervalSince1970: 1705322445.0)
    try verifyRoundTrip(of: PrimitiveWrapper(date), areEqual: { a, b in
      abs(a.value.timeIntervalSince(b.value)) < 0.001
    })
  }

  // MARK: - Decimal Tests

  @Test("Decimal zero round-trips correctly", .tags(.roundTrip))
  func decimalZeroRoundTrip() throws {
    let decimal = Decimal(0)
    try verifyRoundTrip(of: PrimitiveWrapper(decimal))
  }

  @Test("Positive decimal round-trips correctly", .tags(.roundTrip))
  func positiveDecimalRoundTrip() throws {
    let decimal = Decimal(123.456)
    try verifyRoundTrip(of: PrimitiveWrapper(decimal))
  }

  @Test("Negative decimal round-trips correctly", .tags(.roundTrip))
  func negativeDecimalRoundTrip() throws {
    let decimal = Decimal(-789.012)
    try verifyRoundTrip(of: PrimitiveWrapper(decimal))
  }

  @Test("Large decimal value round-trips correctly", .tags(.roundTrip))
  func largeDecimalRoundTrip() throws {
    let decimal = Decimal(string: "12345678901234567890")!
    try verifyRoundTrip(of: PrimitiveWrapper(decimal))
  }

  @Test("Small decimal value round-trips correctly", .tags(.roundTrip))
  func smallDecimalRoundTrip() throws {
    let decimal = Decimal(string: "0.000000001")!
    try verifyRoundTrip(of: PrimitiveWrapper(decimal))
  }

  @Test("Decimal with many decimal places round-trips correctly", .tags(.roundTrip))
  func decimalWithManyPlacesRoundTrip() throws {
    let decimal = Decimal(string: "3.14159265358979323846")!
    try verifyRoundTrip(of: PrimitiveWrapper(decimal))
  }

  @Test("Negative small decimal round-trips correctly", .tags(.roundTrip))
  func negativeSmallDecimalRoundTrip() throws {
    let decimal = Decimal(string: "-0.00000123")!
    try verifyRoundTrip(of: PrimitiveWrapper(decimal))
  }

  // MARK: - Data Tests

  @Test("Empty Data round-trips correctly", .tags(.roundTrip))
  func emptyDataRoundTrip() throws {
    let data = Data()
    try verifyRoundTrip(of: PrimitiveWrapper(data))
  }

  @Test("Small Data round-trips correctly", .tags(.roundTrip))
  func smallDataRoundTrip() throws {
    let data = Data([0x01, 0x02, 0x03, 0x04])
    try verifyRoundTrip(of: PrimitiveWrapper(data))
  }

  @Test("Large Data round-trips correctly", .tags(.roundTrip))
  func largeDataRoundTrip() throws {
    let data = Data(repeating: 0x42, count: 10000)
    try verifyRoundTrip(of: PrimitiveWrapper(data))
  }

  @Test("Data with all byte values round-trips correctly", .tags(.roundTrip))
  func dataWithAllBytesRoundTrip() throws {
    let data = Data((0...255).map { UInt8($0) })
    try verifyRoundTrip(of: PrimitiveWrapper(data))
  }

  // MARK: - Combined Standard Types Tests

  @Test("Struct with multiple standard types round-trips correctly", .tags(.roundTrip))
  func standardTypesHolderRoundTrip() throws {
    let holder = StandardTypesHolder(
      url: URL(string: "https://example.com/path")!,
      uuid: UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
      date: Date(timeIntervalSince1970: 1234567890.0),
      decimal: Decimal(123.456)
    )

    try verifyRoundTrip(of: holder, areEqual: { a, b in
      guard
        a.url == b.url,
        a.uuid == b.uuid,
        abs(a.date.timeIntervalSince(b.date)) < 0.001,
        a.decimal == b.decimal
      else {
        return false
      }
      return true
    })
  }

  // MARK: - Optional Standard Types Tests

  @Test("Optional URL with value round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalURLWithValueRoundTrip() throws {
    let url: URL? = URL(string: "https://example.com")!
    try verifyRoundTrip(of: OptionalWrapper(url))
  }

  @Test("Optional URL with nil round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalURLWithNilRoundTrip() throws {
    let url: URL? = nil
    try verifyRoundTrip(of: OptionalWrapper(url))
  }

  @Test("Optional UUID with value round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalUUIDWithValueRoundTrip() throws {
    let uuid: UUID? = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
    try verifyRoundTrip(of: OptionalWrapper(uuid))
  }

  @Test("Optional UUID with nil round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalUUIDWithNilRoundTrip() throws {
    let uuid: UUID? = nil
    try verifyRoundTrip(of: OptionalWrapper(uuid))
  }

  @Test("Optional Date with value round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalDateWithValueRoundTrip() throws {
    let date: Date? = Date(timeIntervalSince1970: 1234567890.0)
    try verifyRoundTrip(of: OptionalWrapper(date), areEqual: { a, b in
      if let aDate = a.value, let bDate = b.value {
        return abs(aDate.timeIntervalSince(bDate)) < 0.001
      }
      return a.value == nil && b.value == nil
    })
  }

  @Test("Optional Date with nil round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalDateWithNilRoundTrip() throws {
    let date: Date? = nil
    try verifyRoundTrip(of: OptionalWrapper(date), areEqual: { a, b in
      if let aDate = a.value, let bDate = b.value {
        return abs(aDate.timeIntervalSince(bDate)) < 0.001
      }
      return a.value == nil && b.value == nil
    })
  }

  @Test("Optional Decimal with value round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalDecimalWithValueRoundTrip() throws {
    let decimal: Decimal? = Decimal(123.456)
    try verifyRoundTrip(of: OptionalWrapper(decimal))
  }

  @Test("Optional Decimal with nil round-trips correctly", .tags(.roundTrip, .optionals))
  func optionalDecimalWithNilRoundTrip() throws {
    let decimal: Decimal? = nil
    try verifyRoundTrip(of: OptionalWrapper(decimal))
  }

  // MARK: - Array of Standard Types Tests

  @Test("Array of URLs round-trips correctly", .tags(.roundTrip, .collections))
  func urlArrayRoundTrip() throws {
    let urls = [
      URL(string: "https://example.com")!,
      URL(string: "http://test.org/path")!,
      URL(fileURLWithPath: "/tmp/test.txt")
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(urls))
  }

  @Test("Empty array of URLs round-trips correctly", .tags(.roundTrip, .collections))
  func emptyURLArrayRoundTrip() throws {
    let urls: [URL] = []
    try verifyRoundTrip(of: PrimitiveWrapper(urls))
  }

  @Test("Array of UUIDs round-trips correctly", .tags(.roundTrip, .collections))
  func uuidArrayRoundTrip() throws {
    let uuids = [
      UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
      UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
      UUID()
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(uuids))
  }

  @Test("Array of Dates round-trips correctly", .tags(.roundTrip, .collections))
  func dateArrayRoundTrip() throws {
    let dates = [
      Date(timeIntervalSince1970: 0),
      Date(timeIntervalSince1970: 1234567890.0),
      Date()
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dates), areEqual: { a, b in
      guard a.value.count == b.value.count else { return false }
      for (aDate, bDate) in zip(a.value, b.value) {
        if abs(aDate.timeIntervalSince(bDate)) >= 0.001 {
          return false
        }
      }
      return true
    })
  }

  @Test("Array of Decimals round-trips correctly", .tags(.roundTrip, .collections))
  func decimalArrayRoundTrip() throws {
    let decimals = [
      Decimal(0),
      Decimal(123.456),
      Decimal(-789.012),
      Decimal(string: "0.000000001")!
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(decimals))
  }

  // MARK: - Dictionary with Standard Types Tests

  @Test("Dictionary with URL values round-trips correctly", .tags(.roundTrip, .collections))
  func urlDictionaryRoundTrip() throws {
    let dict: [String: URL] = [
      "homepage": URL(string: "https://example.com")!,
      "api": URL(string: "https://api.example.com/v1")!,
      "file": URL(fileURLWithPath: "/etc/hosts")
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  @Test("Empty dictionary with URL values round-trips correctly", .tags(.roundTrip, .collections))
  func emptyURLDictionaryRoundTrip() throws {
    let dict: [String: URL] = [:]
    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  @Test("Dictionary with UUID values round-trips correctly", .tags(.roundTrip, .collections))
  func uuidDictionaryRoundTrip() throws {
    let dict: [String: UUID] = [
      "user": UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
      "session": UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
      "request": UUID()
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  @Test("Dictionary with Date values round-trips correctly", .tags(.roundTrip, .collections))
  func dateDictionaryRoundTrip() throws {
    let dict: [String: Date] = [
      "created": Date(timeIntervalSince1970: 1234567890.0),
      "updated": Date(timeIntervalSince1970: 1234567900.0),
      "now": Date()
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dict), areEqual: { a, b in
      guard a.value.count == b.value.count else { return false }
      for (key, aDate) in a.value {
        guard let bDate = b.value[key] else { return false }
        if abs(aDate.timeIntervalSince(bDate)) >= 0.001 {
          return false
        }
      }
      return true
    })
  }

  @Test("Dictionary with Decimal values round-trips correctly", .tags(.roundTrip, .collections))
  func decimalDictionaryRoundTrip() throws {
    let dict: [String: Decimal] = [
      "price": Decimal(19.99),
      "tax": Decimal(1.60),
      "total": Decimal(21.59)
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  // MARK: - Nested Collections with Standard Types

  @Test("Array of optional URLs round-trips correctly", .tags(.roundTrip, .collections, .optionals))
  func arrayOfOptionalURLsRoundTrip() throws {
    let urls: [URL?] = [
      URL(string: "https://example.com")!,
      nil,
      URL(string: "https://test.org")!
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(urls))
  }

  @Test("Dictionary with optional UUID values round-trips correctly", .tags(.roundTrip, .collections, .optionals))
  func dictionaryWithOptionalUUIDsRoundTrip() throws {
    let dict: [String: UUID?] = [
      "primary": UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
      "secondary": nil,
      "tertiary": UUID()
    ]
    try verifyRoundTrip(of: PrimitiveWrapper(dict))
  }

  // MARK: - Edge Cases

  @Test("URL with maximum length components round-trips correctly", .tags(.roundTrip, .edgeCases))
  func longURLRoundTrip() throws {
    let longPath = String(repeating: "a", count: 100)
    let url = URL(string: "https://example.com/\(longPath)?query=\(longPath)")!
    try verifyRoundTrip(of: PrimitiveWrapper(url))
  }

  @Test("Date with negative timestamp round-trips correctly", .tags(.roundTrip, .edgeCases))
  func negativeDateRoundTrip() throws {
    // Date before Unix epoch
    let date = Date(timeIntervalSince1970: -1234567890.0)
    try verifyRoundTrip(of: PrimitiveWrapper(date), areEqual: { a, b in
      abs(a.value.timeIntervalSince(b.value)) < 0.001
    })
  }

  @Test("Decimal with maximum precision round-trips correctly", .tags(.roundTrip, .edgeCases))
  func maxPrecisionDecimalRoundTrip() throws {
    // Decimal with 38 digits (Swift's Decimal max)
    let decimal = Decimal(string: "12345678901234567890.12345678901234567")!
    try verifyRoundTrip(of: PrimitiveWrapper(decimal))
  }

  @Test("Data with zero bytes round-trips correctly", .tags(.roundTrip, .edgeCases))
  func dataWithZeroBytesRoundTrip() throws {
    let data = Data([0x00, 0x00, 0x00, 0x00])
    try verifyRoundTrip(of: PrimitiveWrapper(data))
  }
}

// MARK: - Supporting Types

/// A struct containing multiple standard library types for testing.
struct StandardTypesHolder: Codable, Equatable {
  let url: URL
  let uuid: UUID
  let date: Date
  let decimal: Decimal
}

/// A wrapper for optional values.
struct OptionalWrapper<T: Codable & Equatable>: Codable, Equatable {
  let value: T?

  init(_ value: T?) {
    self.value = value
  }
}
