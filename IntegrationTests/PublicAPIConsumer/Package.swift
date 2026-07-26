// swift-tools-version:6.3

import PackageDescription

let package = Package(
  name: "XPCCodingPublicAPIConsumer",
  platforms: [
    .macOS(.v26),
    .iOS(.v26),
    .macCatalyst(.v26),
  ],
  dependencies: [
    .package(
      name: "hdxl-xpc-coding",
      path: "../.."
    )
  ],
  targets: [
    .executableTarget(
      name: "XPCCodingPublicAPIConsumer",
      dependencies: [
        .product(
          name: "XPCCoding",
          package: "hdxl-xpc-coding"
        )
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
