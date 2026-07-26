// swift-tools-version:6.3

// Derived from CodableXPC; substantially modified by hdxl-xpc-coding contributors.
// Licensed under Apache License v2.0 with Runtime Library Exception.
// See LICENSE and THIRD_PARTY_NOTICES.md for details.

// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "hdxl-xpc-coding",
  platforms: [
    .macOS(.v26),
    .iOS(.v26),
    .macCatalyst(.v26),
  ],
  products: [
    .library(
      name: "XPCCoding",
      targets: ["XPCCoding"]
    ),
    .executable(
      name: "XPCCodingBenchmarks",
      targets: ["XPCCodingBenchmarks"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "XPCCoding",
      dependencies: [],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .executableTarget(
      name: "XPCCodingBenchmarks",
      dependencies: ["XPCCoding"],
      path: "Benchmarks/XPCCodingBenchmarks",
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
