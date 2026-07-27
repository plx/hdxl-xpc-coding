import Foundation
import SPIManifest
import Yams

private let expectedPackageName = "hdxl-xpc-coding"
private let expectedProductName = "XPCCoding"
private let expectedRepositoryURL =
  "https://github.com/plx/hdxl-xpc-coding.git"

private struct ValidationError: LocalizedError {
  let message: String

  var errorDescription: String? {
    message
  }
}

private func require(
  _ condition: @autoclosure () -> Bool,
  _ message: String
) throws {
  guard condition() else {
    throw ValidationError(message: message)
  }
}

private struct AnyCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

private func requireExactKeys(
  in decoder: Decoder,
  expected: Set<String>,
  context: String
) throws {
  let container = try decoder.container(keyedBy: AnyCodingKey.self)
  let actual = Set(container.allKeys.map(\.stringValue))
  try require(
    actual == expected,
    "\(context) keys must be exactly \(expected.sorted()); found \(actual.sorted())."
  )
}

private struct StrictManifest: Decodable {
  let version: Int
  let builder: Builder

  private enum CodingKeys: String, CodingKey {
    case version
    case builder
  }

  init(from decoder: Decoder) throws {
    try requireExactKeys(
      in: decoder,
      expected: ["builder", "version"],
      context: ".spi.yml"
    )
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decode(Int.self, forKey: .version)
    builder = try container.decode(Builder.self, forKey: .builder)
  }

  struct Builder: Decodable {
    let configs: [BuildConfig]

    private enum CodingKeys: String, CodingKey, CaseIterable {
      case configs
    }

    init(from decoder: Decoder) throws {
      try requireExactKeys(
        in: decoder,
        expected: ["configs"],
        context: ".spi.yml builder"
      )
      let container = try decoder.container(keyedBy: CodingKeys.self)
      configs = try container.decode([BuildConfig].self, forKey: .configs)
    }
  }

  struct BuildConfig: Decodable, Equatable {
    let platform: String
    let swiftVersion: String
    let scheme: String?
    let target: String?
    let documentationTargets: [String]?

    private enum CodingKeys: String, CodingKey, CaseIterable {
      case platform
      case swiftVersion = "swift_version"
      case scheme
      case target
      case documentationTargets = "documentation_targets"
    }

    init(
      platform: String,
      swiftVersion: String,
      scheme: String? = nil,
      target: String? = nil,
      documentationTargets: [String]? = nil
    ) {
      self.platform = platform
      self.swiftVersion = swiftVersion
      self.scheme = scheme
      self.target = target
      self.documentationTargets = documentationTargets
    }

    init(from decoder: Decoder) throws {
      let allowedKeys = Set(CodingKeys.allCases.map(\.rawValue))
      let dynamicContainer = try decoder.container(
        keyedBy: AnyCodingKey.self
      )
      let actualKeys = Set(dynamicContainer.allKeys.map(\.stringValue))
      try require(
        actualKeys.isSubset(of: allowedKeys),
        "SPI build config contains unsupported keys: "
          + "\(actualKeys.subtracting(allowedKeys).sorted())."
      )

      let container = try decoder.container(keyedBy: CodingKeys.self)
      platform = try container.decode(String.self, forKey: .platform)
      swiftVersion = try container.decode(String.self, forKey: .swiftVersion)
      scheme = try container.decodeIfPresent(String.self, forKey: .scheme)
      target = try container.decodeIfPresent(String.self, forKey: .target)
      documentationTargets = try container.decodeIfPresent(
        [String].self,
        forKey: .documentationTargets
      )
    }
  }
}

private func stringArray(
  _ value: Any?,
  context: String
) throws -> [String] {
  guard let values = value as? [String] else {
    throw ValidationError(message: "\(context) must be an array of strings.")
  }
  return values
}

private func dictionaryArray(
  _ value: Any?,
  context: String
) throws -> [[String: Any]] {
  guard let values = value as? [[String: Any]] else {
    throw ValidationError(message: "\(context) must be an array of objects.")
  }
  return values
}

private func validatePackageDescription(
  at packageDescriptionPath: String,
  configs: [StrictManifest.BuildConfig]
) throws {
  let data = try Data(contentsOf: URL(fileURLWithPath: packageDescriptionPath))
  guard
    let package = try JSONSerialization.jsonObject(with: data)
      as? [String: Any]
  else {
    throw ValidationError(message: "Package description is not a JSON object.")
  }

  try require(
    package["name"] as? String == expectedPackageName,
    "Package identity must be \(expectedPackageName)."
  )

  let toolsVersion = package["toolsVersion"] as? [String: Any]
  try require(
    toolsVersion?["_version"] as? String == "6.3.0",
    "Package tools version must be exactly 6.3."
  )
  let swiftLanguageVersions = try stringArray(
    package["swiftLanguageVersions"],
    context: "swiftLanguageVersions"
  )
  try require(
    swiftLanguageVersions == ["6"],
    "Package language mode must be exactly Swift 6."
  )

  let platforms = try dictionaryArray(
    package["platforms"],
    context: "platforms"
  )
  let actualPlatforms = Set(
    try platforms.map { platform in
      guard
        let name = platform["platformName"] as? String,
        let version = platform["version"] as? String,
        let options = platform["options"] as? [Any]
      else {
        throw ValidationError(
          message: "Each package platform must have a name, version, and options."
        )
      }
      try require(options.isEmpty, "Package platform options must be empty.")
      return "\(name)@\(version)"
    }
  )
  try require(
    platforms.count == 3
      && actualPlatforms == ["ios@26.0", "maccatalyst@26.0", "macos@26.0"],
    "Package platforms must be exactly macOS, iOS, and Mac Catalyst 26.0."
  )

  let products = try dictionaryArray(
    package["products"],
    context: "products"
  )
  let libraryProducts = try products.compactMap { product -> String? in
    guard let name = product["name"] as? String else {
      throw ValidationError(message: "Every package product needs a name.")
    }
    guard
      let type = product["type"] as? [String: Any],
      type["library"] != nil
    else {
      return nil
    }
    return name
  }
  guard
    let xpcCodingProduct = products.first(where: {
      $0["name"] as? String == expectedProductName
    })
  else {
    throw ValidationError(
      message: "Package product \(expectedProductName) does not exist."
    )
  }
  let xpcCodingProductTargets = try stringArray(
    xpcCodingProduct["targets"],
    context: "\(expectedProductName) product targets"
  )
  try require(
    xpcCodingProductTargets == [expectedProductName],
    "\(expectedProductName) product must vend only its matching target."
  )
  let xpcCodingType = xpcCodingProduct["type"] as? [String: Any]
  try require(
    xpcCodingType?["library"] != nil,
    "\(expectedProductName) must remain a library product."
  )

  let targets = try dictionaryArray(package["targets"], context: "targets")
  let regularTargets = Set(
    targets.compactMap { target -> String? in
      guard target["type"] as? String == "regular" else {
        return nil
      }
      return target["name"] as? String
    }
  )
  try require(
    regularTargets.contains(expectedProductName),
    "Package target \(expectedProductName) does not exist."
  )

  for config in configs {
    if let target = config.target {
      try require(
        regularTargets.contains(target),
        "SPI target \(target) is not a regular package target."
      )
    }
    if let scheme = config.scheme {
      try require(
        libraryProducts.contains(scheme),
        "SPI scheme \(scheme) does not match a library product."
      )
    }
    for documentationTarget in config.documentationTargets ?? [] {
      try require(
        regularTargets.contains(documentationTarget),
        "SPI documentation target \(documentationTarget) does not exist."
      )
    }
  }
}

private func validateManifest(at manifestPath: String) throws -> StrictManifest {
  let officialManifest = try Manifest.load(at: manifestPath)
  let contents = try String(
    contentsOfFile: manifestPath,
    encoding: .utf8
  )
  let manifest = try YAMLDecoder().decode(StrictManifest.self, from: contents)

  try require(
    officialManifest.version == manifest.version,
    "The official SPIManifest parser disagrees with the strict manifest version."
  )
  try require(manifest.version == 1, ".spi.yml version must be exactly 1.")

  let expectedConfigs = [
    StrictManifest.BuildConfig(
      platform: "macos-spm",
      swiftVersion: "6.3",
      target: expectedProductName,
      documentationTargets: [expectedProductName]
    ),
    StrictManifest.BuildConfig(
      platform: "macos-xcodebuild",
      swiftVersion: "6.3",
      scheme: expectedProductName
    ),
    StrictManifest.BuildConfig(
      platform: "ios",
      swiftVersion: "6.3",
      scheme: expectedProductName
    ),
  ]
  try require(
    manifest.builder.configs == expectedConfigs,
    "SPI configs must be the reviewed Swift 6.3 macOS/iOS XPCCoding set."
  )
  return manifest
}

private func validateReadme(at readmePath: String) throws {
  let readme = try String(contentsOfFile: readmePath, encoding: .utf8)
  try require(
    readme.contains(expectedRepositoryURL),
    "README must contain the canonical repository URL \(expectedRepositoryURL)."
  )
}

private func run() throws {
  guard CommandLine.arguments.count == 4 else {
    throw ValidationError(
      message:
        "usage: SPIManifestValidator <.spi.yml> <package-description.json> <README.md>"
    )
  }

  let manifest = try validateManifest(at: CommandLine.arguments[1])
  try validatePackageDescription(
    at: CommandLine.arguments[2],
    configs: manifest.builder.configs
  )
  try validateReadme(at: CommandLine.arguments[3])

  print(
    "Verified .spi.yml with SPIManifest 1.13.0: "
      + "hdxl-xpc-coding/XPCCoding, Swift 6.3, macOS 26, iOS 26, "
      + "and XPCCoding documentation."
  )
}

do {
  try run()
} catch {
  let description =
    (error as? LocalizedError)?.errorDescription ?? String(describing: error)
  let message = "error: \(description)\n"
  FileHandle.standardError.write(Data(message.utf8))
  exit(EXIT_FAILURE)
}
