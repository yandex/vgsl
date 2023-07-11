// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "vgsl",
  platforms: [
    .iOS(.v11),
  ],
  products: [
    .library(name: "BasePublic", targets: ["BasePublic"]),
    .library(name: "CommonCorePublic", targets: ["CommonCorePublic"]),
    .library(name: "NetworkingPublic", targets: ["NetworkingPublic"]),
  ],
  targets: [
    .target(
      name: "BaseTinyPublic",
      path: "BaseTinyPublic",
      swiftSettings: [
        .unsafeFlags(
          [
            "-emit-module-interface",
            "-enable-library-evolution",
          ]
        )
      ]
    ),
    .target(
      name: "BaseUIPublic",
      dependencies: [
        "BaseTinyPublic",
      ],
      path: "BaseUIPublic",
      swiftSettings: [
        .unsafeFlags(
          [
            "-emit-module-interface",
            "-enable-library-evolution",
          ]
        )
      ]
    ),
    .target(
      name: "BasePublic",
      dependencies: [
        "BaseTinyPublic",
        "BaseUIPublic",
      ],
      path: "BasePublic",
      swiftSettings: [
        .unsafeFlags(
          [
            "-emit-module-interface",
            "-enable-library-evolution",
          ]
        )
      ]
    ),
    .target(
      name: "CommonCorePublic",
      dependencies: [
        "BasePublic",
      ],
      path: "CommonCorePublic",
      swiftSettings: [
        .unsafeFlags(
          [
            "-emit-module-interface",
            "-enable-library-evolution",
          ]
        )
      ]
    ),

    .target(
      name: "NetworkingPublic",
      dependencies: [
        "BasePublic",
      ],
      path: "NetworkingPublic",
      swiftSettings: [
        .unsafeFlags(
          [
            "-emit-module-interface",
            "-enable-library-evolution",
          ]
        )
      ]
    ),
  ]
)