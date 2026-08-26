// swift-tools-version:6.0

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableExperimentalFeature("AccessLevelOnImport"),
]

let linkerSettings: [LinkerSetting] = [
  .linkedFramework("Foundation"),
  .linkedFramework("UIKit", .when(platforms: [.iOS])),
  .linkedFramework("AppKit", .when(platforms: [.macOS])),
  .linkedFramework("CoreGraphics"),
]

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
  ],
  targets: [
    .target(
      name: "VGSLFundamentals",
      path: "VGSLFundamentals",
      swiftSettings: swiftSettings,
      linkerSettings: [
        .linkedFramework("Foundation"),
        .linkedFramework("CoreGraphics"),
      ]
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
        "VGSLUI",
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
        "VGSLUI",
      ],
      path: "VGSL",
      swiftSettings: swiftSettings,
      linkerSettings: linkerSettings
    ),
  ],
  swiftLanguageModes: [.v6]
)
