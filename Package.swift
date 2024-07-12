// swift-tools-version:5.5

import PackageDescription

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
      path: "CompatibilityShims/BasePublic"
    ),
    .target(
      name: "BaseTinyPublic",
      dependencies: ["VGSL"],
      path: "CompatibilityShims/BaseTinyPublic"
    ),
    .target(
      name: "BaseUIPublic",
      dependencies: ["VGSL"],
      path: "CompatibilityShims/BaseUIPublic"
    ),
    .target(
      name: "CommonCorePublic",
      dependencies: ["VGSL", "BaseUIPublic"],
      path: "CompatibilityShims/CommonCorePublic"
    ),
    .target(
      name: "NetworkingPublic",
      dependencies: ["VGSL", "BaseUIPublic"],
      path: "CompatibilityShims/NetworkingPublic"
    ),
    .target(
      name: "VGSL_Fundamentals",
      dependencies: ["VGSL"],
      path: "CompatibilityShims/VGSL_Fundamentals"
    ),
    .target(
      name: "VGSL_Fundamentals_Tiny",
      dependencies: ["VGSL"],
      path: "CompatibilityShims/VGSL_Fundamentals_Tiny"
    ),
  ]
)

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
  ] + compatibilityShims.products,
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
  ] + compatibilityShims.targets
)
