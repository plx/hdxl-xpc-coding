// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "hdxl-xpc-coding",
  platforms: [
    .macOS(.v26),
    .iOS(.v26),
    .macCatalyst(.v26)
  ],
  products: [
    .library(
      name: "XPCCoding",
      targets: ["XPCCoding"]
    ),
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "XPCCoding",
      dependencies: [],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "XPCCodingTests",
      dependencies: ["XPCCoding"],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    
  ],
  swiftLanguageModes: [.v6],
)
