import Foundation

// MARK: - Corpus

enum Corpus {

  static let fileExtension = "json"

  // MARK: Location

  /// Finds the checked-in corpus without depending on the build layout.
  ///
  /// The working directory is searched first so a developer can run the harness
  /// from the repository root or from this package. The source-relative fallback
  /// keeps `swift run` convenient from anywhere in the checkout.
  static func defaultDirectory() throws -> URL {
    let manager = FileManager.default
    var candidates: [URL] = []

    var directory = URL(fileURLWithPath: manager.currentDirectoryPath)
    for _ in 0..<8 {
      candidates.append(directory.appendingPathComponent("Corpus"))
      candidates.append(
        directory.appendingPathComponent("IntegrationTests/Fuzzing/Corpus")
      )
      let parent = directory.deletingLastPathComponent()
      guard parent.path != directory.path else {
        break
      }
      directory = parent
    }
    candidates.append(sourceRelativeDirectory)

    for candidate in candidates {
      var isDirectory: ObjCBool = false
      if manager.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      {
        return candidate.standardizedFileURL
      }
    }
    throw FuzzingError(
      """
      Unable to locate the checked-in corpus. Pass --corpus with the path to \
      IntegrationTests/Fuzzing/Corpus.
      """
    )
  }

  /// `Sources/XPCCodingFuzzing/Corpus.swift` → `Corpus/`.
  private static var sourceRelativeDirectory: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Corpus")
  }

  // MARK: Writing

  static func write(
    themes: [CorpusTheme],
    to directory: URL
  ) throws {
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    for theme in themes {
      let url =
        directory
        .appendingPathComponent(theme.name)
        .appendingPathExtension(fileExtension)
      try FuzzingJSON.encode(theme.descriptors).write(to: url, options: .atomic)
    }
  }

  // MARK: Reading

  /// Loads every checked-in case, in a deterministic theme and file order.
  static func load(from directory: URL) throws -> [ProbeDescriptor] {
    var descriptors: [ProbeDescriptor] = []
    for theme in HistoricalCorpus.themes() {
      descriptors.append(
        contentsOf: try loadTheme(named: theme.name, from: directory)
      )
    }
    return descriptors
  }

  /// Loads every checked-in case the ordinary campaign may execute.
  static func loadRunnable(from directory: URL) throws -> [ProbeDescriptor] {
    try load(from: directory).filter { $0.probe != .deliberateHang }
  }

  static func loadTheme(
    named name: String,
    from directory: URL
  ) throws -> [ProbeDescriptor] {
    let url =
      directory
      .appendingPathComponent(name)
      .appendingPathExtension(fileExtension)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw FuzzingError(
        """
        Missing corpus theme file \(url.path). Run \
        `XPCCodingFuzzing corpus regenerate` and review the result.
        """
      )
    }
    do {
      return try FuzzingJSON.decode(
        [ProbeDescriptor].self,
        from: Data(contentsOf: url)
      )
    } catch {
      throw FuzzingError(
        "Unable to decode corpus theme \(url.lastPathComponent): \(error)"
      )
    }
  }

  static func loadDescriptor(at url: URL) throws -> ProbeDescriptor {
    do {
      return try FuzzingJSON.decode(
        ProbeDescriptor.self,
        from: Data(contentsOf: url)
      )
    } catch {
      throw FuzzingError("Unable to decode \(url.path): \(error)")
    }
  }

  // MARK: Verification

  struct VerificationResult {
    var caseCount: Int
    var digest: String
  }

  /// Confirms the checked-in JSON still matches the reviewed Swift inventory.
  ///
  /// Fixtures are reviewed expectations. A representation change must update the
  /// inventory and the JSON in the same reviewed change, so drift is a failure
  /// rather than something to regenerate away.
  static func verify(directory: URL) throws -> VerificationResult {
    let themes = HistoricalCorpus.themes()
    var problems: [String] = []
    var allDescriptors: [ProbeDescriptor] = []

    for theme in themes {
      let stored: [ProbeDescriptor]
      do {
        stored = try loadTheme(named: theme.name, from: directory)
      } catch {
        problems.append("\(error)")
        continue
      }
      allDescriptors.append(contentsOf: stored)

      guard stored != theme.descriptors else {
        continue
      }
      if stored.count != theme.descriptors.count {
        problems.append(
          """
          theme `\(theme.name)` has \(stored.count) checked-in cases but the \
          reviewed inventory defines \(theme.descriptors.count)
          """
        )
      }
      let storedByID = Dictionary(
        stored.map { ($0.id, $0) },
        uniquingKeysWith: { first, _ in first }
      )
      for expected in theme.descriptors {
        guard let actual = storedByID[expected.id] else {
          problems.append("theme `\(theme.name)` is missing case `\(expected.id)`")
          continue
        }
        if actual != expected {
          problems.append(
            "theme `\(theme.name)` case `\(expected.id)` differs from the inventory"
          )
        }
      }
      let expectedIDs = Set(theme.descriptors.map(\.id))
      for actual in stored where !expectedIDs.contains(actual.id) {
        problems.append(
          "theme `\(theme.name)` has unreviewed case `\(actual.id)`"
        )
      }
    }

    let knownFileNames = Set(
      themes.map { "\($0.name).\(fileExtension)" }
    )
    let contents =
      (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    for fileName in contents.sorted()
    where fileName.hasSuffix(".\(fileExtension)") && !knownFileNames.contains(fileName) {
      problems.append("unreviewed corpus file `\(fileName)`")
    }

    let duplicateIDs = duplicates(in: allDescriptors.map(\.id))
    for id in duplicateIDs {
      problems.append("duplicate case identifier `\(id)`")
    }

    guard problems.isEmpty else {
      throw FuzzingError(
        """
        The checked-in corpus does not match the reviewed inventory:
          - \(problems.joined(separator: "\n  - "))
        """
      )
    }

    return VerificationResult(
      caseCount: allDescriptors.count,
      digest: try FuzzingJSON.digest(allDescriptors)
    )
  }

  private static func duplicates(in identifiers: [String]) -> [String] {
    var seen: Set<String> = []
    var repeated: Set<String> = []
    for identifier in identifiers where !seen.insert(identifier).inserted {
      repeated.insert(identifier)
    }
    return repeated.sorted()
  }

}

// MARK: - Error

struct FuzzingError: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}
