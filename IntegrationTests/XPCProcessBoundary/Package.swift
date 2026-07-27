// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "XPCCodingXPCProcessBoundary",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(
      name: "XPCCodingXPCIntegrationClient",
      targets: ["XPCCodingXPCIntegrationClient"]
    ),
    .executable(
      name: "XPCCodingXPCIntegrationService",
      targets: ["XPCCodingXPCIntegrationService"]
    ),
  ],
  dependencies: [
    .package(
      name: "hdxl-xpc-coding",
      path: "../.."
    )
  ],
  targets: [
    .target(
      name: "XPCCodingXPCIntegrationProtocol"
    ),
    .executableTarget(
      name: "XPCCodingXPCIntegrationClient",
      dependencies: [
        "XPCCodingXPCIntegrationProtocol",
        .product(
          name: "XPCCoding",
          package: "hdxl-xpc-coding"
        ),
      ]
    ),
    .executableTarget(
      name: "XPCCodingXPCIntegrationService",
      dependencies: [
        "XPCCodingXPCIntegrationProtocol",
        .product(
          name: "XPCCoding",
          package: "hdxl-xpc-coding"
        ),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
