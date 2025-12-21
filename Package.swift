// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CodableXPC",
  platforms: [
    .macOS(.v26),
    .iOS(.v26),
    .macCatalyst(.v26)
  ],
  products: [
    .library(
      name: "CodableXPC",
      targets: ["CodableXPC"]
    ),
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "CodableXPC",
      dependencies: [],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "CodableXPCTests",
      dependencies: ["CodableXPC"],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    
  ],
  swiftLanguageModes: [.v6],
)
