// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "XPCCodingBaselineProbe",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(
      name: "XPCCodingBaselineProbe",
      targets: ["XPCCodingBaselineProbe"]
    )
  ],
  dependencies: [
    .package(
      name: "hdxl-xpc-coding",
      path: "../.."
    )
  ],
  targets: [
    .executableTarget(
      name: "XPCCodingBaselineProbe",
      dependencies: [
        .product(
          name: "XPCCoding",
          package: "hdxl-xpc-coding"
        )
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
