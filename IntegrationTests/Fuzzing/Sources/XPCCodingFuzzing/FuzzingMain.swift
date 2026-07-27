import Darwin
import Foundation

@main
enum FuzzingMain {
  static func main() {
    do {
      let status = try FuzzingCLI.run(
        arguments: Array(CommandLine.arguments.dropFirst())
      )
      FuzzingCLI.removeScratchDirectory()
      exit(status)
    } catch {
      FuzzingCLI.write("error: \(error)", to: FileHandle.standardError)
      FuzzingCLI.removeScratchDirectory()
      exit(FuzzingExitCode.usage)
    }
  }
}
