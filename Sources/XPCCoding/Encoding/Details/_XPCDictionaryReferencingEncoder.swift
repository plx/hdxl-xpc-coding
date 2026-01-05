import Foundation
import XPC

/// This is used for encoding super classes into an existing dictionary managed by an existing keyed container.
@usableFromInline
internal final class _XPCDictionaryReferencingEncoder: _XPCEncoder {

  /// The dictionary to store the encoded value in.
  @usableFromInline
  internal let xpcDictionary: xpc_object_t
  
  /// The coding key under-which we'll store the value.
  @usableFromInline
  internal let codingKey: CodingKey
    
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
  override func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
    let newDictionary = xpc_dictionary_create(nil, nil, 0)
    xpcDictionary.setValue(
      newDictionary,
      forKey: codingKey,
      strategy: stringKeyStrategy
    )

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
  override func unkeyedContainer() -> UnkeyedEncodingContainer {
    let newArray = xpc_array_create(nil, 0)
    xpcDictionary.setValue(
      newArray,
      forKey: codingKey,
      strategy: stringKeyStrategy
    )

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
  override func singleValueContainer() -> SingleValueEncodingContainer {
    XPCSingleValueEncodingContainer(referencing: self) { [self] value in
      xpcDictionary.setValue(
        value,
        forKey: codingKey,
        strategy: stringKeyStrategy
      )
    }
  }
}

