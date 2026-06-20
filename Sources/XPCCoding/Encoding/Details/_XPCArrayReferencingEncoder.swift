import Foundation
import XPC

// MARK: _XPCArrayReferencingEncoder

/// Specialized encoder used to inject the xpc object for a superclass's encoder
/// into an array being managed by the 
@usableFromInline
internal final class _XPCArrayReferencingEncoder: _XPCEncoder {
  
  @usableFromInline
  internal let xpcArray: xpc_object_t
  
  @usableFromInline
  internal let index: Int
  
  @usableFromInline
  internal init(
    stringKeyStrategy: StringKeyStrategy,
    stringValueStrategy: StringValueStrategy,
    codingPath: [any CodingKey],
    index: Int,
    array: xpc_object_t
  ) {
    self.xpcArray = array
    self.index = index
    super.init(
      stringKeyStrategy: stringKeyStrategy,
      stringValueStrategy: stringValueStrategy,
      codingPath: codingPath
    )
  }
  
  @usableFromInline
  internal override func container<Key>(
    keyedBy type: Key.Type
  ) -> KeyedEncodingContainer<Key> where Key : CodingKey {
    let newDictionary = xpc_dictionary_create(nil, nil, 0)
    xpc_array_set_value(xpcArray, index, newDictionary)

    do {
      let container = try XPCKeyedEncodingContainer<Key>(
        referencing: self,
        wrapping: newDictionary
      )
      return KeyedEncodingContainer(container)
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable internal error creating keyed-container:

        - keyedBy: \(type)
        - error: \(String(reflecting: error))
        """
      )
    }
  }

  @usableFromInline
  internal override func unkeyedContainer() -> UnkeyedEncodingContainer {
    let newArray = xpc_array_create(nil, 0)
    xpc_array_set_value(xpcArray, index, newArray)

    do {
      return try XPCUnkeyedEncodingContainer(
        referencing: self,
        wrapping: newArray
      )
    }
    catch let error {
      fatalError(
        """
        Encountered unrecoverable internal error creating unkeyed-container:

        - error: \(String(reflecting: error))
        """
      )
    }
  }
  
  @usableFromInline
  internal override func singleValueContainer() -> SingleValueEncodingContainer {
    XPCSingleValueEncodingContainer(referencing: self) { [self] value in
      guard index < xpc_array_get_count(xpcArray) else {
        throw EncodingError.invalidValue(
          xpcArray,
          EncodingError.Context(
            codingPath: codingPath,
            debugDescription: "Overshot end index on an array: index \(index) vs count \(xpc_array_get_count(xpcArray))."
          )
        )
      }
      xpc_array_set_value(xpcArray, index, value)
    }
  }
}
