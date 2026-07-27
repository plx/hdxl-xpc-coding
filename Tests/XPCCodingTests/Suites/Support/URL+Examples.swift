import Foundation

extension URL {
  
  static let testExamples: [Self] = [
    URL(string: "http://example.com")!,
    URL(string: "https://example.com/path")!,
    URL(fileURLWithPath: "/tmp/test.txt"),
    URL(string: "https://example.com?foo=bar&baz=qux")!,
    URL(string: "https://example.com/path%20with%20spaces?name=John%20Doe")!,
    URL(string: "https://example.com:8080/path")!,
    URL(string: "https://user:pass@example.com:8080/path/to/resource?query=value&foo=bar#fragment")!
  ]

  static let optionalTestExamples: [Self?] = [nil] + testExamples.map(Optional.some)

}
