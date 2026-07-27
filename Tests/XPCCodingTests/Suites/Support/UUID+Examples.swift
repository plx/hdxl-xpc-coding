import Foundation

extension UUID {

  static let testExamples: [Self] = [
    UUID(),  // random per session,
    UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
    UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
    UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
    UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
  ]

  static let optionalTestExamples: [Self?] = [nil] + testExamples.map(Optional.some)

}
