import XPC
import Foundation

// MARK: XPCCodec.Configuration

extension XPCCodec {

  /// Configuration options for an ``XPCCodec``.
  ///
  /// An `XPCCodec` stores this value as its only persistent behavioral state.
  /// Direct codec operations snapshot it, and each codec factory derives a
  /// fresh facade from it.
  ///
  /// Controls how the encoder and decoder handle strings that may contain embedded null bytes.
  /// Since XPC only supports C-style null-terminated strings, Swift strings containing null bytes
  /// require special handling to avoid truncation during encoding.
  public struct Configuration {

    /// The strategy for handling embedded null bytes in string keys.
    public var stringKeyStrategy: StringKeyStrategy

    /// The strategy for handling embedded null bytes in string values.
    public var stringValueStrategy: StringValueStrategy

    /// Creates a new configuration with the specified strategies.
    ///
    /// - Parameters:
    ///   - stringKeyStrategy: The strategy for handling null bytes in string
    ///     keys. Defaults to ``XPCCodec/StringKeyStrategy/standard``.
    ///   - stringValueStrategy: The strategy for handling null bytes in string
    ///     values. Defaults to ``XPCCodec/StringValueStrategy/standard``.
    public init(
      stringKeyStrategy: StringKeyStrategy = .standard,
      stringValueStrategy: StringValueStrategy = .standard
    ) {
      self.stringKeyStrategy = stringKeyStrategy
      self.stringValueStrategy = stringValueStrategy
    }

  }

}

// MARK: - Well-Known Values

extension XPCCodec.Configuration {

  /// The standard safe configuration used by zero-argument codec and coder
  /// construction.
  ///
  /// Both string keys and string values use the reversible percent-escape
  /// strategy, preserving embedded null and literal percent scalars.
  public static let standard: Self = Self()

}

// MARK: - Synthesized Conformances

extension XPCCodec.Configuration: Sendable { }
extension XPCCodec.Configuration: Equatable { }
extension XPCCodec.Configuration: Hashable { }
extension XPCCodec.Configuration: Codable { }


// MARK: - CaseIterable

extension XPCCodec.Configuration: CaseIterable {

  /// Every configuration formed by pairing each
  /// ``XPCCodec/StringKeyStrategy`` with each ``XPCCodec/StringValueStrategy``.
  ///
  /// The order is an implementation detail; treat this as a set. It exists so
  /// exhaustive round-trip tests can cover the whole configuration space.
  public static let allCases: [Self] = {
    var result: [Self] = []
    let stringKeyStrategies = XPCCodec.StringKeyStrategy.allCases
    let stringValueStrategies = XPCCodec.StringValueStrategy.allCases
    result.reserveCapacity(stringKeyStrategies.count * stringValueStrategies.count)
    for stringKeyStrategy in stringKeyStrategies {
      for stringValueStrategy in stringValueStrategies {
        result.append(
          Self(
            stringKeyStrategy: stringKeyStrategy,
            stringValueStrategy: stringValueStrategy
          )
        )
      }
    }
    
    return result
  }()
}
