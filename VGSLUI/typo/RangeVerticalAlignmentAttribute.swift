// Copyright 2025 Yandex LLC. All rights reserved.

import CoreGraphics
import Foundation

public final class RangeVerticalAlignmentAttribute: StringAttribute {
  public static let Key = NSAttributedString.Key("RangeVerticalAlignment")

  public enum VerticalAlignment: String {
    case top
    case center
    case bottom
    case baseline
  }

  public let verticalAlignment: VerticalAlignment
  public let range: CFRange

  public init(verticalAlignment: VerticalAlignment, range: CFRange) {
    self.verticalAlignment = verticalAlignment
    self.range = range
  }

  public func apply(to str: CFMutableAttributedString, at range: CFRange) {
    CFAttributedStringSetAttribute(str, range, RangeVerticalAlignmentAttribute.Key as CFString, self)
  }
}
