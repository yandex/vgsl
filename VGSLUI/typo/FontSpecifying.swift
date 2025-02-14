// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics

public protocol FontSpecifying: AnyObject, Sendable {
  func font(weight: FontWeight, size: CGFloat) -> Font
}

public struct FontSpecifiers: Sendable {
  public var text: FontSpecifying
  public var display: FontSpecifying
  public var wide: FontSpecifying?

  public init(
    text: FontSpecifying,
    display: FontSpecifying,
    wide: FontSpecifying? = nil
  ) {
    self.text = text
    self.display = display
    self.wide = wide
  }

  public func font(family: FontFamily, weight: FontWeight, size: CGFloat) -> Font {
    switch family {
    case .YSTextWide:
      guard let font = wide?.font(weight: weight, size: size) else { fallthrough }
      return font
    case .YSDisplay:
      return display.font(weight: weight, size: size)
    case .YSText:
      return text.font(weight: weight, size: size)
    }
  }
}

extension FontSpecifiers {
  public func textFont(weight: FontWeight, size: CGFloat) -> Font {
    font(family: .YSText, weight: weight, size: size)
  }
}
