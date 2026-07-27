import Foundation
import XPC
@testable import XPCCoding

// MARK: - Primitive Wrapper

/// A wrapper that holds a single primitive value for keyed container testing.
struct PrimitiveWrapper<T: Codable & Equatable>: Codable, Equatable {
  let value: T

  init(_ value: T) {
    self.value = value
  }
}

extension PrimitiveWrapper: Sendable where T: Sendable {}
