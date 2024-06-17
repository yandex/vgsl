// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "vgsl",
  platforms: [
    .iOS(.v9),
    .tvOS(.v9),
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
      path: "VGSLFundamentals"
    ),
    .target(
      name: "VGSLUI",
      dependencies: [
        "VGSLFundamentals",
      ],
      path: "VGSLUI"
    ),
    .target(
      name: "VGSLNetworking",
      dependencies: [
        "VGSLFundamentals",
        "VGSLUI"
      ],
      path: "VGSLNetworking"
    ),
    .target(
      name: "VGSL",
      dependencies: [
        "VGSLFundamentals",
        "VGSLNetworking",
        "VGSLUI"
      ],
      path: "VGSL"
    ),
  ]
)
