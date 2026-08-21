// Copyright 2026 Yandex LLC. All rights reserved.

import CoreGraphics

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct TypographicBounds {
  var ascent: CGFloat
  var descent: CGFloat
  let width: CGFloat

  static let `default` = TypographicBounds(
    ascent: Font.systemFontWithDefaultSize().ascender,
    descent: abs(Font.systemFontWithDefaultSize().descender),
    width: 0
  )

  var height: CGFloat {
    ascent + descent
  }

  func constrained(width maxWidth: CGFloat) -> TypographicBounds {
    TypographicBounds(
      ascent: ascent,
      descent: descent,
      width: min(width, maxWidth)
    )
  }
}
