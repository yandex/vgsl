// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics

import VGSLFundamentals

private let _fontSpecifiers = AllocatedUnfairLock<FontSpecifiers>(initialState: .init(
  text: systemFontSpecifier,
  display: systemFontSpecifier
))
public var fontSpecifiers: FontSpecifiers {
  get {
    _fontSpecifiers.withLock { $0 }
  }
  set {
    _fontSpecifiers.withLock { $0 = newValue }
  }
}

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
