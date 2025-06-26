// Copyright 2024 Yandex LLC. All rights reserved.
import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public final class CloudBackgroundAttribute: Hashable, StringAttribute {
  public static let Key = NSAttributedString.Key("CloudBackground")

  public let color: Color
  public let cornerRadius: CGFloat
  public let range: Range<Int>
  public let insets: EdgeInsets?

  public init(
    color: Color,
    cornerRadius: CGFloat,
    range: Range<Int>,
    insets: EdgeInsets? = nil
  ) {
    self.color = color
    self.cornerRadius = cornerRadius
    self.range = range
    self.insets = insets
  }

  public func apply(to str: CFMutableAttributedString, at range: CFRange) {
    CFAttributedStringSetAttribute(str, range, CloudBackgroundAttribute.Key as CFString, self)
  }

  public static func ==(lhs: CloudBackgroundAttribute, rhs: CloudBackgroundAttribute) -> Bool {
    lhs.color == rhs.color &&
      lhs.cornerRadius == rhs.cornerRadius &&
      lhs.range == rhs.range &&
      lhs.insets == rhs.insets
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(color)
    hasher.combine(cornerRadius)
    hasher.combine(range)
    if let insets {
      hasher.combine(insets.top)
      hasher.combine(insets.bottom)
      hasher.combine(insets.left)
      hasher.combine(insets.right)
    }
  }
}
