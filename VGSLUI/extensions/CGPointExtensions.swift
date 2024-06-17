// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics
import Foundation

extension CGPoint {
  public func movingX(by value: CGFloat) -> CGPoint {
    CGPoint(x: x + value, y: y)
  }

  public func movingY(by value: CGFloat) -> CGPoint {
    CGPoint(x: x, y: y + value)
  }
}

public func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
  CGPoint(
    x: lhs.x + rhs.x,
    y: lhs.y + rhs.y
  )
}

public func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
  CGPoint(
    x: lhs.x - rhs.x,
    y: lhs.y - rhs.y
  )
}

public prefix func -(rhs: CGPoint) -> CGPoint {
  CGPoint(x: -rhs.x, y: -rhs.y)
}

public func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
  CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
}

public func *(lhs: CGFloat, rhs: CGPoint) -> CGPoint {
  rhs * lhs
}

public func /(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
  CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
}

public func -(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
  CGPoint(x: lhs.x - rhs, y: lhs.y - rhs)
}

extension CGPoint: Hashable {
  public func hash(into hasher: inout Hasher) {
    x.hash(into: &hasher)
    y.hash(into: &hasher)
  }
}

extension CGPoint {
  public func rounded(toStep step: CGFloat = 1) -> CGPoint {
    CGPoint(x: x.rounded(toStep: step), y: y.rounded(toStep: step))
  }

  public var roundedToScreenScale: CGPoint {
    rounded(toStep: 1 / PlatformDescription.screenScale())
  }

  public func relativePosition(in rect: CGRect) -> RelativePoint {
    RelativePoint(
      x: (x - rect.minX) / rect.width,
      y: (y - rect.minY) / rect.height
    )
  }

  public func swapCoordinates() -> CGPoint {
    CGPoint(x: y, y: x)
  }

  public func isApproximatelyEqualTo(_ other: CGPoint) -> Bool {
    x.isApproximatelyEqualTo(other.x) &&
      y.isApproximatelyEqualTo(other.y)
  }

  public func distance(to other: CGPoint) -> CGFloat {
    let a = (x - other.x)
    let b = (y - other.y)
    return sqrt(a * a + b * b)
  }
}
