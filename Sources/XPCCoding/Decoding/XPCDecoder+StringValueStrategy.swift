import Foundation
import XPC
import Combine

extension XPCDecoder {

  /// The strategy for handling encoded null bytes in string values during decoding.
  ///
  /// This strategy must match the encoding strategy used when the data was created
  /// to ensure correct round-tripping of string values.
  public enum StringValueStrategy {

    /// Decode string values directly without any transformation.
    ///
    /// Use this when values were encoded with ``XPCEncoder/StringValueStrategy/assumeAbsent``
    /// or ``XPCEncoder/StringValueStrategy/throwOnDiscovery`` and are known not to
    /// contain any encoded null bytes.
    case passthrough

    /// Decode percent-encoded null bytes in string values.
    ///
    /// Use this when values were encoded with ``XPCEncoder/StringValueStrategy/percentEscape``.
    /// This is the default strategy.
    case percentEscape

    /// Decode strings from binary data using the specified encoding.
    ///
    /// Use this when values were encoded with
    /// ``XPCEncoder/StringValueStrategy/useDataRepresentation(_:)``. The encoding
    /// must match the one used during encoding.
    case useDataRepresentation(XPCCodec.StringValueDataRepresentation)
  }

}

extension XPCDecoder.StringValueStrategy: Sendable { }
extension XPCDecoder.StringValueStrategy: Equatable { }
extension XPCDecoder.StringValueStrategy: Hashable { }
extension XPCDecoder.StringValueStrategy: Codable { }
extension XPCDecoder.StringValueStrategy: CaseIterable {
  
  static public let allCases: [Self] = {
    [
      .passthrough,
      .percentEscape
    ] + XPCCodec.StringValueDataRepresentation.allCases.map {
      Self.useDataRepresentation($0)
    }
  }()

}

extension XPCDecoder.StringValueStrategy {

  /// The standard (default) strategy for decoding string values.
  public static let standard: Self = XPCCodec.StringValueStrategy.standard.decodingStrategy

}

extension XPCCodec.StringValueStrategy {
  
  @usableFromInline
  internal var decodingStrategy: XPCDecoder.StringValueStrategy {
    switch self {
    case .assumeAbsent:
      .passthrough
    case .throwOnDiscovery:
      .passthrough
    case .percentEscape:
      .percentEscape
    case .useDataRepresentation(let representation):
      .useDataRepresentation(representation)
    }
  }
  
}
