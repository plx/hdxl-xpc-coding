import Foundation

extension Decimal {

  static let testExamples: [Self] = [
    Decimal(0),
    Decimal(123.456),
    Decimal(-789.012),
    Decimal(string: "12345678901234567890")!,
    Decimal(string: "0.000000001")!,
    Decimal(string: "3.14159265358979323846")!,
    Decimal(string: "-0.00000123")!,
  ]

  static let optionalTestExamples: [Self?] = [nil] + testExamples.map(Optional.some)

}
