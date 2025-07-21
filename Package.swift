// swift-tools-version:5.9

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableExperimentalFeature("AccessLevelOnImport")
]

let linkerSettings: [LinkerSetting] = [
  .linkedFramework("Foundation"),
  .linkedFramework("UIKit"),
  .linkedFramework("CoreGraphics")
]

let compatibilityShims: (products: [PackageDescription.Product], targets: [PackageDescription.Target]) = (
  products: [
    .library(name: "BasePublic", targets: ["BasePublic"]),
    .library(name: "BaseTinyPublic", targets: ["BaseTinyPublic"]),
    .library(name: "BaseUIPublic", targets: ["BaseUIPublic"]),
    .library(name: "CommonCorePublic", targets: ["CommonCorePublic"]),
    .library(name: "NetworkingPublic", targets: ["NetworkingPublic"]),
    .library(name: "VGSL_Fundamentals", targets: ["VGSL_Fundamentals"]),
    .library(name: "VGSL_Fundamentals_Tiny", targets: ["VGSL_Fundamentals_Tiny"]),
  ],
  targets: [
    .target(
      name: "BasePublic",
      dependencies: ["VGSL", "BaseUIPublic", "NetworkingPublic"],
      path: "CompatibilityShims/BasePublic",
      swiftSettings: swiftSettings,
      linkerSettings: linkerSettings
    ),
    .target(
      name: "BaseTinyPublic",
      dependencies: ["VGSL"],
      path: "CompatibilityShims/BaseTinyPublic",
      swiftSettings: swiftSettings,
      linkerSettings: linkerSettings
    ),
    .target(
      name: "BaseUIPublic",
      dependencies: ["VGSL"],
      path: "CompatibilityShims/BaseUIPublic",
      swiftSettings: swiftSettings,
      linkerSettings: linkerSettings
    ),
    .target(
      name: "CommonCorePublic",
      dependencies: ["VGSL", "BaseUIPublic"],
      path: "CompatibilityShims/CommonCorePublic",
      swiftSettings: swiftSettings,
      linkerSettings: linkerSettings
    ),
    .target(
      name: "NetworkingPublic",
      dependencies: ["VGSL", "BaseUIPublic"],
      path: "CompatibilityShims/NetworkingPublic",
      swiftSettings: swiftSettings,
      linkerSettings: linkerSettings
    ),
    .target(
      name: "VGSL_Fundamentals",
      dependencies: ["VGSL"],
      path: "CompatibilityShims/VGSL_Fundamentals",
      swiftSettings: swiftSettings,
      linkerSettings: linkerSettings
    ),
    .target(
      name: "VGSL_Fundamentals_Tiny",
      dependencies: ["VGSL"],
      path: "CompatibilityShims/VGSL_Fundamentals_Tiny",
      swiftSettings: swiftSettings,
      linkerSettings: linkerSettings
    ),
  ]
)

let package = Package(
  name: "vgsl",
  platforms: [
    .iOS(.v13),
    .tvOS(.v13),
    .macOS(.v10_15),
  ],
  products: [
    .library(name: "VGSLFundamentals", targets: ["VGSLFundamentals"]),
    .library(name: "VGSLUI", targets: ["VGSLUI"]),
    .library(name: "VGSLNetworking", targets: ["VGSLNetworking"]),
    .library(name: "VGSL", targets: ["VGSL"]),
  ] + compatibilityShims.products,
  targets: [
    .target(
      name: "VGSLFundamentals",
      path: "VGSLFundamentals",
      swiftSettings: swiftSettings,
      linkerSettings: linkerSettings
    ),
    .target(
      name: "VGSLUI",
      dependencies: [
        "VGSLFundamentals",
      ],
      path: "VGSLUI",
      swiftSettings: swiftSettings,
      linkerSettings: linkerSettings
    ),
    .target(
      name: "VGSLNetworking",
      dependencies: [
        "VGSLFundamentals",
        "VGSLUI"
      ],
      path: "VGSLNetworking",
      swiftSettings: swiftSettings,
      linkerSettings: linkerSettings
    ),
    .target(
      name: "VGSL",
      dependencies: [
        "VGSLFundamentals",
        "VGSLNetworking",
        "VGSLUI"
      ],
      path: "VGSL",
      swiftSettings: swiftSettings,
      linkerSettings: linkerSettings
    ),
    .testTarget(
        name: "VGSL_Fundamentals_Tests",
        dependencies: [ "VGSL" ],
        path: "Tests",
        swiftSettings: swiftSettings,
        linkerSettings: linkerSettings
    )
  ] + compatibilityShims.targets
)
