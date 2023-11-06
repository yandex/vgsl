// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "vgsl",
  platforms: [
    .iOS(.v11),
  ],
  products: [
    .library(name: "BaseTinyPublic", targets: ["BaseTinyPublic"]),
    .library(name: "BaseUIPublic", targets: ["BaseUIPublic"]),
    .library(name: "BasePublic", targets: ["BasePublic"]),
    .library(name: "CommonCorePublic", targets: ["CommonCorePublic"]),
    .library(name: "NetworkingPublic", targets: ["NetworkingPublic"]),
  ],
  targets: [
    .target(
      name: "BaseTinyPublic",
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
      ],
      path: "BasePublic"
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
  ]
)
