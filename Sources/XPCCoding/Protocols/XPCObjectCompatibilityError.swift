import Foundation
import XPC

// MARK: XPCObjectCompatibilityError

/// Error used to explain *why* a specific value wasn't convertible to an equivalent `xpc_object_t`.
internal enum XPCObjectCompatibilityError: Error {
  /// Case for when strings contain content that won't work with XPC (e.g. interior null bytes, etc.).
  ///
  /// First string is a brief explanation, second string is the incompatible string, itself.
  case incompatibleStringContent(String, String)  // explanation, string
}

// MARK: - CustomStringConvertible

extension XPCObjectCompatibilityError: CustomStringConvertible {

  internal var description: String {
    switch self {
    case .incompatibleStringContent(let explanation, _):
      explanation
    }
  }

}

// MARK: - CustomStringConvertible

extension XPCObjectCompatibilityError: CustomDebugStringConvertible {

  internal var debugDescription: String {
    switch self {
    case .incompatibleStringContent(let explanation, _):
      explanation  // bit wary of printing the incompatible strings...
    }
  }

}
