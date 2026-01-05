import XPC
import Foundation

// MARK: XPCCodec.Configuration

extension XPCCodec {

  /// Configuration options for an ``XPCCodec``.
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
    ///   - stringKeyStrategy: The strategy for handling null bytes in string keys.
    ///   - stringValueStrategy: The strategy for handling null bytes in string values.
    public init(
      stringKeyStrategy: StringKeyStrategy,
      stringValueStrategy: StringValueStrategy
    ) {
      self.stringKeyStrategy = stringKeyStrategy
      self.stringValueStrategy = stringValueStrategy
    }

  }

}

// MARK: - Synthesized Conformances

extension XPCCodec.Configuration: Sendable { }
extension XPCCodec.Configuration: Equatable { }
extension XPCCodec.Configuration: Hashable { }
extension XPCCodec.Configuration: Codable { }


// MARK: - CaseIterable

extension XPCCodec.Configuration: CaseIterable {
  
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
