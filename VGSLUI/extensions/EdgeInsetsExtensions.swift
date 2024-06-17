// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics
import Foundation

extension EdgeInsets {
  public var contentOrigin: CGPoint {
    CGPoint(x: left, y: top)
  }

  public init(horizontal: SideInsets = .zero, vertical: SideInsets = .zero) {
    self.init(
      top: vertical.leading,
      left: horizontal.leading,
      bottom: vertical.trailing,
      right: horizontal.trailing
    )
  }

  public init(uniform inset: CGFloat) {
    self.init(
      top: inset,
      left: inset,
      bottom: inset,
      right: inset
    )
  }

  public func addTop(_ value: CGFloat) -> EdgeInsets {
    EdgeInsets(top: top + value, left: left, bottom: bottom, right: right)
  }

  public var horizontal: SideInsets {
    SideInsets(leading: left, trailing: right)
  }

  public var vertical: SideInsets {
    SideInsets(leading: top, trailing: bottom)
  }

  // VGSL-34: Remove in major release
  @inlinable
  public var horizontalInsets: SideInsets {
    horizontal
  }

  // VGSL-34: Remove in major release
  @inlinable
  public var verticalInsets: SideInsets {
    vertical
  }
}

extension EdgeInsets {
  public func insetHeight(_ height: CGFloat) -> CGFloat {
    height - (top + bottom)
  }

  public func isApproximatelyEqualTo(_ other: EdgeInsets) -> Bool {
    top.isApproximatelyEqualTo(other.top) &&
      left.isApproximatelyEqualTo(other.left) &&
      bottom.isApproximatelyEqualTo(other.bottom) &&
      right.isApproximatelyEqualTo(other.right)
  }
}

public func availableWidthForWidth(_ width: CGFloat, insets: EdgeInsets) -> CGFloat {
  width - (insets.left + insets.right)
}

public func availableWidthForWidth(_ width: CGFloat, insets: SideInsets) -> CGFloat {
  width - (insets.leading + insets.trailing)
}

public prefix func -(_ value: EdgeInsets) -> EdgeInsets {
  EdgeInsets(
    top: -value.top,
    left: -value.left,
    bottom: -value.bottom,
    right: -value.right
  )
}

public func *(lhs: EdgeInsets, rhs: CGFloat) -> EdgeInsets {
  EdgeInsets(
    top: lhs.top * rhs,
    left: lhs.left * rhs,
    bottom: lhs.bottom * rhs,
    right: lhs.right * rhs
  )
}
