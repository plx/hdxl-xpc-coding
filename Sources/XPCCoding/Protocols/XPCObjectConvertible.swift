import Foundation
import XPC

// MARK: XPCObjectConvertible

/// Protocol for values that *may* be convertible to `xpc_object_t` (...but not always).
///
/// The only known "basic type" conforming to this protocol is `String`, which can have
/// unexpected behavior with xpc when it also contains null bytes.
///
/// - SeeAlso: ``LosslessXPCObjectConvertible``, for the *much* more common infallible variant.
@usableFromInline
internal protocol XPCObjectConvertible {
  
  /// Provides an `xpc_object_t` equivalent-to `self`, or throws an error explaining the source of incompatibility.
  func makeXPCObjectRepresentation() throws(XPCObjectCompatibilityError) -> xpc_object_t
  
}

// MARK: - Conformances

extension String: XPCObjectConvertible {
  
  @inlinable
  internal func makeXPCObjectRepresentation() throws(XPCObjectCompatibilityError) -> xpc_object_t {
    try verifyXPCCompatibility()
    return withCString { cString in
      xpc_string_create(cString)
    }
  }

}
