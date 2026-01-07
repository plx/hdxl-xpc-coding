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
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.4.0"),
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

    // MARK: - Benchmarks

    .executableTarget(
      name: "EncodingBenchmarks",
      dependencies: [
        "XPCCoding",
        .product(name: "Benchmark", package: "package-benchmark"),
      ],
      path: "Benchmarks/EncodingBenchmarks",
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ],
      plugins: [
        .plugin(name: "BenchmarkPlugin", package: "package-benchmark"),
      ]
    ),

    .executableTarget(
      name: "IPCBenchmarks",
      dependencies: [
        "XPCCoding",
        .product(name: "Benchmark", package: "package-benchmark"),
      ],
      path: "Benchmarks/IPCBenchmarks",
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ],
      plugins: [
        .plugin(name: "BenchmarkPlugin", package: "package-benchmark"),
      ]
    ),

  ],
  swiftLanguageModes: [.v6],
)
