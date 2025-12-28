import Foundation

extension KeyedEncodingContainer {
  
  // MARK: - Data Elements
  
  @inlinable
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeRawPointer: UnsafeRawPointer?,
    count: Int,
    forKey key: Key
  ) throws {
    try encode(
      UnsafeRawPointerShim(
        unsafeRawPointer: unsafeRawPointer,
        count: count
      ),
      forKey: key
    )
  }

  @inlinable
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeMutableRawPointer: UnsafeMutableRawPointer?,
    count: Int,
    forKey key: Key
  ) throws {
    try encode(
      UnsafeMutableRawPointerShim(
        unsafeMutableRawPointer: unsafeMutableRawPointer,
        count: count
      ),
      forKey: key
    )
  }

  @inlinable
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeRawBufferPointer: UnsafeRawBufferPointer,
    forKey key: Key
  ) throws {
    try encode(
      UnsafeRawBufferPointerShim(unsafeRawBufferPointer: unsafeRawBufferPointer),
      forKey: key
    )
  }

  @inlinable
  public mutating func efficientlyEncodeBinaryData(
    _ unsafeMutableRawBufferPointer: UnsafeMutableRawBufferPointer,
    forKey key: Key
  ) throws {
    try encode(
      UnsafeMutableRawBufferPointerShim(unsafeMutableRawBufferPointer: unsafeMutableRawBufferPointer),
      forKey: key
    )
  }
  
  // MARK: - Element Buffers

  @inlinable
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafePointer: UnsafePointer<T>?,
    count: Int,
    forKey key: Key
  ) throws {
    var container = nestedUnkeyedContainer(forKey: key)
    try container.efficientlyEncodeElements(
      unsafePointer,
      count: count
    )
  }
  
  @inlinable
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafeMutablePointer: UnsafeMutablePointer<T>?,
    count: Int,
    forKey key: Key
  ) throws {
    var container = nestedUnkeyedContainer(forKey: key)
    try container.efficientlyEncodeElements(
      unsafeMutablePointer,
      count: count
    )
  }
  
  @inlinable
  public mutating func efficientlyEncodeElements<T: Encodable>(
    _ unsafeBufferPointer: UnsafeBufferPointer<T>,
    forKey key: Key
  ) throws {
    var container = nestedUnkeyedContainer(forKey: key)
    try container.efficientlyEncodeElements(unsafeBufferPointer)
  }
  
  @inlinable
  public mutating func efficientlyEncodeBinaryData<T: Encodable>(
    _ unsafeMutableBufferPointer: UnsafeMutableBufferPointer<T>,
    forKey key: Key
  ) throws {
    var container = nestedUnkeyedContainer(forKey: key)
    try container.efficientlyEncodeElements(unsafeMutableBufferPointer)
  }

}

// MARK: - UnsafeRawPointerShim

@usableFromInline
internal struct UnsafeRawPointerShim: Encodable {
  
  @usableFromInline
  internal let unsafeRawPointer: UnsafeRawPointer?
  
  @usableFromInline
  internal let count: Int
  
  @inlinable
  init(unsafeRawPointer: UnsafeRawPointer?, count: Int) {
    self.unsafeRawPointer = unsafeRawPointer
    self.count = count
  }
  
  @inlinable
  internal func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch container as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      try container.directlyEncodeXPCData(
        unsafeRawPointer,
        count: count
      )
    case .none:
      switch unsafeRawPointer {
      case .some(let unsafeRawPointer):
        try container.encode(
          Data(
            bytesNoCopy: UnsafeMutableRawPointer(mutating: unsafeRawPointer),
            count: count,
            deallocator: .none
          )
        )
      case .none:
        try container.encode(Data())
      }
    }
  }
  
}

// MARK: - UnsafeMutableRawPointerShim

@usableFromInline
internal struct UnsafeMutableRawPointerShim: Encodable {
  
  @usableFromInline
  internal let unsafeMutableRawPointer: UnsafeMutableRawPointer?
  
  @usableFromInline
  internal let count: Int
  
  @inlinable
  init(unsafeMutableRawPointer: UnsafeMutableRawPointer?, count: Int) {
    self.unsafeMutableRawPointer = unsafeMutableRawPointer
    self.count = count
  }
  
  @inlinable
  internal func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch container as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      try container.directlyEncodeXPCData(
        unsafeMutableRawPointer,
        count: count
      )
    case .none:
      switch unsafeMutableRawPointer {
      case .some(let unsafeMutableRawPointer):
        try container.encode(
          Data(
            bytesNoCopy: unsafeMutableRawPointer,
            count: count,
            deallocator: .none
          )
        )
      case .none:
        try container.encode(Data())
      }
    }
  }
  
}

// MARK: - UnsafeRawBufferPointerShim

@usableFromInline
internal struct UnsafeRawBufferPointerShim: Encodable {
  
  @usableFromInline
  internal let unsafeRawBufferPointer: UnsafeRawBufferPointer
  
  @inlinable
  init(unsafeRawBufferPointer: UnsafeRawBufferPointer) {
    self.unsafeRawBufferPointer = unsafeRawBufferPointer
  }
  
  @inlinable
  internal func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch container as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      try container.directlyEncodeXPCData(unsafeRawBufferPointer)
    case .none:
      switch unsafeRawBufferPointer.baseAddress {
      case .some(let baseAddress):
        try container.encode(
          Data(
            bytesNoCopy: UnsafeMutableRawPointer(mutating: baseAddress),
            count: unsafeRawBufferPointer.count,
            deallocator: .none
          )
        )
      case .none:
        try container.encode(Data())
      }
    }
  }
  
}

// MARK: - UnsafeMutableRawBufferPointerShim

@usableFromInline
internal struct UnsafeMutableRawBufferPointerShim: Encodable {
  
  @usableFromInline
  internal let unsafeMutableRawBufferPointer: UnsafeMutableRawBufferPointer
  
  @inlinable
  init(unsafeMutableRawBufferPointer: UnsafeMutableRawBufferPointer) {
    self.unsafeMutableRawBufferPointer = unsafeMutableRawBufferPointer
  }
  
  @inlinable
  internal func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch container as? XPCEnhancedSingleValueEncodingContainer {
    case .some(var container):
      try container.directlyEncodeXPCData(unsafeMutableRawBufferPointer)
    case .none:
      switch unsafeMutableRawBufferPointer.baseAddress {
      case .some(let baseAddress):
        try container.encode(
          Data(
            bytesNoCopy: baseAddress,
            count: unsafeMutableRawBufferPointer.count,
            deallocator: .none
          )
        )
      case .none:
        try container.encode(Data())
      }
    }
  }
  
}
