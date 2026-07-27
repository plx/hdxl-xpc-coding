import Darwin
import Foundation

@main
enum BaselineMain {
  static func main() {
    do {
      exit(try BaselineCLI.run(arguments: Array(CommandLine.arguments.dropFirst())))
    } catch {
      BaselineCLI.write("error: \(error)", to: FileHandle.standardError)
      exit(BaselineExitCode.usage)
    }
  }
}
