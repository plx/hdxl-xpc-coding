// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

import Foundation
import XPC

/// This is used for encoding super classes into an existing dictionary managed by an existing keyed container.
@usableFromInline
internal final class _XPCDictionaryReferencingEncoder: _XPCEncoder {

  /// The dictionary in which we store the encoded value.
  @usableFromInline
  internal let xpcDictionary: xpc_object_t

  /// The key under which we store the encoded value.
  @usableFromInline
  internal let codingKey: any CodingKey

  @usableFromInline
  internal init(
    stringKeyStrategy: StringKeyStrategy,
    stringValueStrategy: StringValueStrategy,
    codingPath: [CodingKey],
    codingKey: CodingKey,
    dictionary: xpc_object_t
  ) {
    self.xpcDictionary = dictionary
    self.codingKey = codingKey
    super.init(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      codingPath: codingPath
    )
  }

  @usableFromInline
  internal override func insertIntoOutputDestination(
    _ topLevelObject: xpc_object_t
  ) throws {
    xpcDictionary.setValue(
      topLevelObject,
      forKey: codingKey,
      strategy: stringKeyStrategy
    )
  }
}
