import Foundation
import SanitizerNegativeControlSupport
import Testing

@Suite("Disposable Sanitizer Negative Controls")
struct SanitizerNegativeControlTests {

  @Test(
    .enabled(
      if: ProcessInfo.processInfo.environment["XPCCODING_SANITIZER_NEGATIVE_CONTROL"]
        == "address"
    )
  )
  func `AddressSanitizer detects an out-of-bounds write`() {
    let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
    pointer.advanced(by: 16).pointee = 0xFF
    pointer.deallocate()
  }

  @Test(
    .enabled(
      if: ProcessInfo.processInfo.environment["XPCCODING_SANITIZER_NEGATIVE_CONTROL"]
        == "undefined"
    )
  )
  func `UndefinedBehaviorSanitizer detects a misaligned load`() {
    sanitizer_negative_control_undefined_behavior()
  }

  @Test(
    .enabled(
      if: ProcessInfo.processInfo.environment["XPCCODING_SANITIZER_NEGATIVE_CONTROL"]
        == "thread"
    )
  )
  func `ThreadSanitizer detects a data race`() {
    sanitizer_negative_control_thread()
  }

}
