// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics

public var fontSpecifiers = FontSpecifiers(
  text: systemFontSpecifier,
  display: systemFontSpecifier
)

private let systemFontSpecifier = SystemFontSpecifier()

private final class SystemFontSpecifier: FontSpecifying {
  func font(weight: FontWeight, size: CGFloat) -> Font {
    .systemFont(ofSize: size, weight: weight.cast())
  }
}

extension FontWeight {
  fileprivate func cast() -> Font.Weight {
    switch self {
    case .bold:
      .bold
    case .semibold:
      .semibold
    case .medium:
      .medium
    case .regular:
      .regular
    case .light:
      .light
    }
  }
}
