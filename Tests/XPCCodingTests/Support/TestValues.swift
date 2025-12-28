import Foundation

// MARK: Bool

extension Bool {
  
  static let exampleValues: [Self] = [true, false]
}

// MARK: Data

extension Data {
  
  static let exampleValues: [Self] = [0,1,2,4,8,16,1024,4096].enumerated().map { index, count in
    Data(repeating: UInt8(index), count: count)
  }
  
}

// MARK: String

extension String {
  
  static let nullFreeExampleValues: [Self] = [
    "",
    "a",
    "ab",
    "abc",
    """
    Four score and seven years ago...
    """
  ]
  
  static let exampleValues: [Self] = nullFreeExampleValues // TODO: emoji, examples with null, etc.
  
}

// MARK: Signed Integers

extension Int8 {
  
  static let allValues: some Sendable & Collection<Self> = Int8.min...Int8.max
  static let exampleValues: [Self] = [
    Self.min, Self.min + 1,
    Self.max, Self.max - 1,
    0, 1, 2, -1, -2
  ]
  
}

extension Int16 {
  
  static let exampleValues: [Self] = [
    Self.min, Self.min + 1,
    Self.max, Self.max - 1
  ] + Int8.exampleValues.map(Self.init(_:))

}

extension Int32 {

  static let exampleValues: [Self] = [
    Self.min, Self.min + 1,
    Self.max, Self.max - 1
  ] + Int16.exampleValues.map(Self.init(_:))
  
}

extension Int64 {
  
  static let exampleValues: [Self] = [
    Self.min, Self.min + 1,
    Self.max, Self.max - 1
  ] + Int32.exampleValues.map(Self.init(_:))
  
}

extension Int128 {
  
  static let exampleValues: [Self] = [
    Self.min, Self.min + 1,
    Self.max, Self.max - 1
  ] + Int64.exampleValues.map(Self.init(_:))
  
}

extension Int {
  
  static let exampleValues: [Self] = Int64.exampleValues.map(Self.init(_:))
  
}

// MARK: Unsigned Integers

extension UInt8 {
  
  static let allValues: some Sendable & Collection<Self> = UInt8.min...UInt8.max
  static let exampleValues: [Self] = [
    Self.min, Self.min + 1,
    Self.max, Self.max - 1,
    0, 1, 2
  ]
  
}

extension UInt16 {
  
  static let exampleValues: [Self] = [
    Self.min, Self.min + 1,
    Self.max, Self.max - 1
  ] + UInt8.exampleValues.map(Self.init(_:))
  
}

extension UInt32 {
  
  static let exampleValues: [Self] = [
    Self.min, Self.min + 1,
    Self.max, Self.max - 1
  ] + UInt16.exampleValues.map(Self.init(_:))
  
}

extension UInt64 {
  
  static let exampleValues: [Self] = [
    Self.min, Self.min + 1,
    Self.max, Self.max - 1
  ] + UInt32.exampleValues.map(Self.init(_:))
  
}

extension UInt128 {
  
  static let exampleValues: [Self] = [
    Self.min, Self.min + 1,
    Self.max, Self.max - 1
  ] + UInt64.exampleValues.map(Self.init(_:))
  
}

extension UInt {
  
  static let exampleValues: [Self] = UInt64.exampleValues.map(Self.init(_:))
  
}

// MARK: Floating Point

extension BinaryFloatingPoint {
  
  static var _commonNumericExampleValues: [Self] {
    [
      0.0,
      -1.0,
      1.0,
      .pi,
      -.pi,
      1000.0,
      -1000.0,
      1024.0,
      -1024.0
    ]
  }
  
  static var _extremeNumericExampleValues: [Self] {
    [
      .greatestFiniteMagnitude,
      .leastNonzeroMagnitude,
      .leastNormalMagnitude,
      -.greatestFiniteMagnitude,
      -.leastNonzeroMagnitude,
      -.leastNormalMagnitude,
    ]
  }
  
  static var _finiteNumericExampleValues: [Self] { _commonNumericExampleValues + _extremeNumericExampleValues }
  static var _numericExampleValues: [Self] { _commonNumericExampleValues + _extremeNumericExampleValues + _nonFiniteNumericExampleValues }
  
  static var _nonFiniteNumericExampleValues: [Self] {
    [
      .infinity,
      -.infinity
    ]
  }

  static var _nonNumericExampleValues: [Self] {
    [
      .nan,
      .signalingNaN
    ]
  }

  static var _exampleValues: [Self] { _numericExampleValues + _nonNumericExampleValues }

}

extension Double {
  
  static let commonNumericExampleValues = _commonNumericExampleValues
  static let extremeNumericExampleValues = _extremeNumericExampleValues
  static let finiteNumericExampleValues = _finiteNumericExampleValues
  static let nonFiniteNumericExampleValues = _finiteNumericExampleValues
  static let nonNumericExampleValues = _nonNumericExampleValues
  static let exampleValues = _exampleValues
  
}

extension Float {
  
  static let commonNumericExampleValues = _commonNumericExampleValues
  static let extremeNumericExampleValues = _extremeNumericExampleValues
  static let finiteNumericExampleValues = _finiteNumericExampleValues
  static let nonFiniteNumericExampleValues = _finiteNumericExampleValues
  static let nonNumericExampleValues = _nonNumericExampleValues
  static let exampleValues = _exampleValues
  
}

extension Float16 {
  
  static let commonNumericExampleValues = _commonNumericExampleValues
  static let extremeNumericExampleValues = _extremeNumericExampleValues
  static let finiteNumericExampleValues = _finiteNumericExampleValues
  static let nonFiniteNumericExampleValues = _finiteNumericExampleValues
  static let nonNumericExampleValues = _nonNumericExampleValues
  static let exampleValues = _exampleValues
  
}
