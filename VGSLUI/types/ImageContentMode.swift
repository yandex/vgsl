// Copyright 2015 Yandex LLC. All rights reserved.

import CoreGraphics
import Foundation
import QuartzCore

public struct ImageContentMode: Equatable {
  public enum Scale: Equatable {
    case resize
    case aspectFill
    case aspectFit
    case aspectWidth
    case noScale
  }

  public enum VerticalAlignment: Equatable {
    case top
    case center
    case bottom
  }

  public enum HorizontalAlignment: Equatable {
    case left
    case center
    case right
  }

  public let scale: Scale
  public let verticalAlignment: VerticalAlignment
  public let horizontalAlignment: HorizontalAlignment

  public init(
    scale: Scale,
    verticalAlignment: VerticalAlignment = .center,
    horizontalAlignment: HorizontalAlignment = .center
  ) {
    self.scale = scale
    self.verticalAlignment = verticalAlignment
    self.horizontalAlignment = horizontalAlignment
  }

  public func contentsGravity(isGeometryFlipped: Bool) -> CALayerContentsGravity {
    switch scale {
    case .resize:
      .resize
    case .aspectFill:
      .resizeAspectFill
    case .aspectFit:
      .resizeAspect
    case .aspectWidth:
      .resize
    case .noScale:
      noScaleGravity(isGeometryFlipped: isGeometryFlipped)
    }
  }

  private func noScaleGravity(isGeometryFlipped: Bool) -> CALayerContentsGravity {
    switch (verticalAlignment, horizontalAlignment) {
    case (.top, .left):
      isGeometryFlipped ? .bottomLeft : .topLeft
    case (.center, .left):
      .left
    case (.bottom, .left):
      isGeometryFlipped ? .topLeft : .bottomLeft
    case (.top, .center):
      isGeometryFlipped ? .bottom : .top
    case (.center, .center):
      .center
    case (.bottom, .center):
      isGeometryFlipped ? .top : .bottom
    case (.top, .right):
      isGeometryFlipped ? .bottomRight : .topRight
    case (.center, .right):
      .right
    case (.bottom, .right):
      isGeometryFlipped ? .topRight : .bottomRight
    }
  }
}

extension ImageContentMode {
  public static let `default` = ImageContentMode(scale: .resize)
  public static let center = ImageContentMode(scale: .noScale)
  public static let scaleAspectFit = ImageContentMode(scale: .aspectFit)
  public static let scaleAspectFill = ImageContentMode(scale: .aspectFill)
  public static let scaleAspectWidth = ImageContentMode(
    scale: .aspectWidth,
    verticalAlignment: .top
  )
  public static let bottom = ImageContentMode(
    scale: .noScale,
    verticalAlignment: .bottom
  )
  public static let bottomLeft = ImageContentMode(
    scale: .noScale,
    verticalAlignment: .bottom,
    horizontalAlignment: .left
  )
  public static let bottomRight = ImageContentMode(
    scale: .noScale,
    verticalAlignment: .bottom,
    horizontalAlignment: .right
  )
  public static let left = ImageContentMode(
    scale: .noScale,
    horizontalAlignment: .left
  )
  public static let right = ImageContentMode(
    scale: .noScale,
    horizontalAlignment: .right
  )
  public static let top = ImageContentMode(
    scale: .noScale,
    verticalAlignment: .top
  )
  public static let topLeft = ImageContentMode(
    scale: .noScale,
    verticalAlignment: .top,
    horizontalAlignment: .left
  )
  public static let topRight = ImageContentMode(
    scale: .noScale,
    verticalAlignment: .top,
    horizontalAlignment: .right
  )
  public static let noScale = ImageContentMode(scale: .noScale)
}

extension ImageContentMode: CustomDebugStringConvertible {
  public var debugDescription: String {
    let alignmentDescription =
      if verticalAlignment == .center, horizontalAlignment == .center {
        "\(verticalAlignment)"
      } else {
        "\(verticalAlignment)-\(horizontalAlignment)"
      }
    return "Scale: \(scale), Alignment: \(alignmentDescription)"
  }
}
