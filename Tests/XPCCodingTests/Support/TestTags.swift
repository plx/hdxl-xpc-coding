// Tests/XPCCodingTests/Support/TestTags.swift
// Tag definitions for test filtering
//
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing

extension Tag {
  /// Tests for encoding operations
  @Tag static var encoding: Self

  /// Tests for decoding operations
  @Tag static var decoding: Self

  /// Tests that verify round-trip encoding/decoding
  @Tag static var roundTrip: Self

  /// Tests for primitive types (Bool, Int, String, etc.)
  @Tag static var primitives: Self

  /// Tests for container operations
  @Tag static var containers: Self

  /// Tests for keyed containers (dictionaries)
  @Tag static var keyed: Self

  /// Tests for unkeyed containers (arrays)
  @Tag static var unkeyed: Self

  /// Tests for single-value containers
  @Tag static var singleValue: Self

  /// Tests for class inheritance
  @Tag static var inheritance: Self

  /// Tests for optional and nil handling
  @Tag static var optionals: Self

  /// Tests for error conditions
  @Tag static var errors: Self

  /// Tests for edge cases and boundary conditions
  @Tag static var edgeCases: Self

  /// Tests for collections (arrays, dictionaries, sets)
  @Tag static var collections: Self

  /// Tests for standard library types (URL, UUID, Date, etc.)
  @Tag static var standardLibrary: Self

  /// Tests for coding path tracking
  @Tag static var codingPath: Self

  /// Tests for nested containers
  @Tag static var nested: Self
}
