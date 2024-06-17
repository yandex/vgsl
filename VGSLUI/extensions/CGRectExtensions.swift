// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics
import Foundation

import VGSLFundamentals

extension CGRect {
  public func inset(by value: CGFloat) -> CGRect {
    inset(by: EdgeInsets(top: value, left: value, bottom: value, right: value))
  }

  public func inset(horizontallyBy insets: SideInsets) -> CGRect {
    inset(by: EdgeInsets(horizontal: insets))
  }

  public func inset(verticallyBy insets: SideInsets) -> CGRect {
    inset(by: EdgeInsets(vertical: insets))
  }
}

extension CGRect {
  public enum Corner: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
  }

  public typealias Corners = Set<Corner>

  public func coordinate(ofCorner corner: Corner) -> CGPoint {
    switch corner {
    case .topLeft:
      origin
    case .topRight:
      CGPoint(x: maxX, y: minY)
    case .bottomLeft:
      CGPoint(x: minX, y: maxY)
    case .bottomRight:
      CGPoint(x: maxX, y: maxY)
    }
  }

  public mutating func set(coordinate: CGPoint, ofCorner corner: Corner) {
    switch corner {
    case .topLeft, .topRight:
      let oldMaxY = maxY
      origin.y = coordinate.y
      size.height = max(0, oldMaxY - coordinate.y)
    case .bottomLeft, .bottomRight:
      size.height = max(0, coordinate.y - origin.y)
      origin.y = min(origin.y, coordinate.y)
    }

    switch corner {
    case .topLeft, .bottomLeft:
      let oldMaxX = maxX
      origin.x = coordinate.x
      size.width = max(0, oldMaxX - coordinate.x)
    case .topRight, .bottomRight:
      size.width = max(0, coordinate.x - origin.x)
      origin.x = min(origin.x, coordinate.x)
    }
  }

  public func offset(by delta: CGPoint) -> CGRect {
    offsetBy(dx: delta.x, dy: delta.y)
  }

  public var minDimension: CGFloat {
    min(width, height)
  }

  public var leastRadius: CGFloat {
    minDimension / 2
  }

  public func expanded(by value: CGFloat) -> CGRect {
    CGRect(
      x: origin.x - value,
      y: origin.y - value,
      width: width + 2 * value,
      height: height + 2 * value
    )
  }

  public func expanded(by insets: EdgeInsets) -> CGRect {
    CGRect(
      x: minX - insets.left,
      y: minY - insets.top,
      width: width + insets.left + insets.right,
      height: height + insets.bottom + insets.top
    )
  }

  public func scaled(x: CGFloat, y: CGFloat) -> CGRect {
    CGRect(
      x: origin.x * x,
      y: origin.y * y,
      width: width * x,
      height: height * y
    )
  }

  public func withScaledSize(_ scale: CGFloat) -> CGRect {
    withScaledSize(x: scale, y: scale)
  }

  public func withScaledSize(x: CGFloat, y: CGFloat) -> CGRect {
    let scaledSize = CGSize(width: width * x, height: height * y)
    return CGRect(center: center, size: scaledSize)
  }

  public init(center: CGPoint, size: CGSize) {
    self.init(origin: .zero, size: size)
    self.center = center
  }

  public var isValidAndFinite: Bool {
    !isNull && !isInfinite
      && !origin.x.isNaN && !origin.y.isNaN
      && !width.isNaN && !height.isNaN
  }

  public func approximatelyEquals(
    to other: CGRect,
    withPrecision precision: CGFloat = 10e-7
  ) -> Bool {
    other.contains(expanded(by: -precision)) &&
      expanded(by: precision).contains(other)
  }

  public func rounded(toStep step: CGFloat) -> CGRect {
    modified(self) {
      let newSize = size.ceiled(toStep: step)
      let newX = origin.x - (newSize.width - size.width) / 2
      let newY = origin.y - (newSize.height - size.height) / 2
      $0.origin = CGPoint(x: newX, y: newY).rounded(toStep: step)
      $0.size = newSize
    }
  }

  public var roundedToScreenScale: CGRect {
    rounded(toStep: 1 / PlatformDescription.screenScale())
  }

  public func isApproximatelyEqualTo(_ other: CGRect) -> Bool {
    origin.isApproximatelyEqualTo(other.origin) && size.isApproximatelyEqualTo(other.size)
  }

  public func borderPath(
    cornerWidth: CGFloat,
    cornerHeight: CGFloat,
    borderWidth: CGFloat
  ) -> CGPath {
    let halfWidth = 0.5 * borderWidth
    let pathRect = inset(by: halfWidth)
    return CGPath(
      roundedRect: pathRect,
      cornerWidth: max(0, cornerWidth - halfWidth),
      cornerHeight: max(0, cornerHeight - halfWidth),
      transform: nil
    )
  }

  public var xRange: Range<CGFloat> {
    minX..<maxX
  }

  public var center: CGPoint {
    get {
      CGPoint(x: midX, y: midY)
    }
    set {
      origin = CGPoint(x: newValue.x - width / 2, y: newValue.y - height / 2)
    }
  }
}

public func contentSize(for frames: [CGRect]) -> CGSize {
  CGSize(
    width: frames.map(\.maxX).max() ?? 0,
    height: frames.map(\.maxY).max() ?? 0
  )
}

public func filter(frames: [CGRect], intersecting frame: CGRect) -> [(index: Int, frame: CGRect)] {
  zip(frames.indices, frames).filter { $0.1.intersects(frame) }
}

extension CGRect.Corners {
  public static let all: Self = Set(CGRect.Corner.allCases)
  public static let right: Self = [.topRight, .bottomRight]
  public static let left: Self = [.topLeft, .bottomLeft]
  public static let top: Self = [.topLeft, .topRight]
  public static let bottom: Self = [.bottomLeft, .bottomRight]
}
