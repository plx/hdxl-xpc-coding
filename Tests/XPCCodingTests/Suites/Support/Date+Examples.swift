import Foundation

extension Date {
  
  static let testExamples: [Self] = [
    Date(),
    Date(timeIntervalSince1970: 0), // epoch
    Date.distantPast,
    Date.distantFuture,
    Date(timeIntervalSince1970: 1234567890.123456),
    Date(timeIntervalSince1970: 1705322445.0)
  ]
  
  static let optionalTestExamples: [Self?] = [nil] + testExamples.map { $0 }

}
