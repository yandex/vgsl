// Copyright 2024 Yandex LLC. All rights reserved.
import Foundation

import VGSLFundamentals

extension CGVector {
  public init(_ point: CGPoint) {
    self.init(dx: point.x, dy: point.y)
  }

  public init(_ point1: CGPoint, _ point2: CGPoint) {
    self.init(dx: point2.x - point1.x, dy: point2.y - point1.y)
  }

  public func crossProductMagnitude(_ vector2: CGVector) -> CGFloat {
    dx * vector2.dy - dy * vector2.dx
  }

  public func dotProduct(_ vector2: CGVector) -> CGFloat {
    dx * vector2.dx + dy * vector2.dy
  }

  public var length: CGFloat {
    sqrt(dotProduct(self))
  }

  public var normalized: CGVector {
    let length = self.length
    return CGVector(CGPoint(x: dx / length, y: dy / length))
  }

  public func isClockwised(_ vector2: CGVector) -> Bool {
    crossProductMagnitude(vector2) > 0
  }
}
