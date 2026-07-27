// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "XPCCodingFuzzing",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(
      name: "XPCCodingFuzzing",
      targets: ["XPCCodingFuzzing"]
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
      name: "XPCCodingFuzzing",
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
