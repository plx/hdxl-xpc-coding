import Darwin
import Foundation

@main
enum BenchmarkMain {
  static func main() {
    do {
      try BenchmarkCLI.run(arguments: Array(CommandLine.arguments.dropFirst()))
    } catch {
      FileHandle.standardError.write(
        Data("error: \(error)\n".utf8)
      )
      exit(EXIT_FAILURE)
    }
  }
}
