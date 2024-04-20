// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "vgsl",
  platforms: [
    .iOS(.v9),
    .tvOS(.v11),
  ],
  products: [
    .library(name: "VGSL_Fundamentals_Tiny", targets: ["VGSL_Fundamentals_Tiny"]),
    .library(name: "VGSL_Fundamentals", targets: ["VGSL_Fundamentals"]),
    .library(name: "VGSL", targets: ["VGSL"]),
    .library(name: "BaseTinyPublic", targets: ["BaseTinyPublic"]),
    .library(name: "BaseUIPublic", targets: ["BaseUIPublic"]),
    .library(name: "BasePublic", targets: ["BasePublic"]),
    .library(name: "CommonCorePublic", targets: ["CommonCorePublic"]),
    .library(name: "NetworkingPublic", targets: ["NetworkingPublic"]),
  ],
  targets: [
    .target(
      name: "BaseTinyPublic",
      dependencies: [
        "VGSL_Fundamentals_Tiny",
      ],
      path: "BaseTinyPublic"
    ),
    .target(
      name: "BaseUIPublic",
      dependencies: [
        "BaseTinyPublic",
      ],
      path: "BaseUIPublic"
    ),
    .target(
      name: "BasePublic",
      dependencies: [
        "BaseTinyPublic",
        "BaseUIPublic",
        "VGSL_Fundamentals",
      ],
      path: "BasePublic",
      resources: [.copy("PrivacyInfo.xcprivacy")]
    ),
    .target(
      name: "CommonCorePublic",
      dependencies: [
        "BasePublic",
      ],
      path: "CommonCorePublic"
    ),
    .target(
      name: "NetworkingPublic",
      dependencies: [
        "BasePublic",
      ],
      path: "NetworkingPublic"
    ),
    .target(
      name: "VGSL",
      dependencies: [
        "VGSL_Fundamentals",
      ],
      path: "VGSL"
    ),
    .target(
      name: "VGSL_Fundamentals",
      dependencies: [
        "VGSL_Fundamentals_Tiny",
      ],
      path: "VGSL_Fundamentals"
    ),
    .target(
      name: "VGSL_Fundamentals_Tiny",
      path: "VGSL_Fundamentals_Tiny"
    ),
  ]
)
