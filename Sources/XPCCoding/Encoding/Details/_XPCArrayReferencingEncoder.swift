// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

// MARK: _XPCArrayReferencingEncoder

/// Installs a superclass encoder's XPC object into a reserved array element.
internal final class _XPCArrayReferencingEncoder: _XPCEncoder {

  /// The array in which we replace a reserved element.
  internal let xpcArray: xpc_object_t

  /// The index of the reserved element.
  internal let index: Int

  internal init(
    stringKeyStrategy: StringKeyStrategy,
    stringValueStrategy: StringValueStrategy,
    codingPath: [any CodingKey],
    userInfo: [CodingUserInfoKey: Any],
    index: Int,
    array: xpc_object_t
  ) {
    self.xpcArray = array
    self.index = index
    super.init(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      codingPath: codingPath,
      userInfo: userInfo
    )
  }

  internal override func insertIntoOutputDestination(
    _ topLevelObject: xpc_object_t
  ) throws {
    let count = xpc_array_get_count(xpcArray)
    guard index >= 0, index < count else {
      throw EncodingError.invalidValue(
        xpcArray,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "Array reference index \(index) is outside the valid range 0..<\(count)."
        )
      )
    }
    xpc_array_set_value(xpcArray, index, topLevelObject)
  }
}
