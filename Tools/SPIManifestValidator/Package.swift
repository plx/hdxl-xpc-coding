// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "SPIManifestValidator",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(
      name: "SPIManifestValidator",
      targets: ["SPIManifestValidator"]
    )
  ],
  dependencies: [
    .package(
      url: "https://github.com/SwiftPackageIndex/SPIManifest.git",
      exact: "1.13.0"
    ),
    .package(
      url: "https://github.com/jpsim/Yams.git",
      exact: "6.2.2"
    ),
  ],
  targets: [
    .executableTarget(
      name: "SPIManifestValidator",
      dependencies: [
        .product(name: "SPIManifest", package: "SPIManifest"),
        .product(name: "Yams", package: "Yams"),
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
