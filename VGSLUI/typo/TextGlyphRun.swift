// Copyright 2026 Yandex LLC. All rights reserved.

import CoreGraphics
import CoreText

extension CTRun {
  /// Draws the shaped glyphs without decorations, attachments or shadows.
  /// The caller controls the fill/stroke colors and text drawing mode.
  public func drawGlyphs(at position: CGPoint, in context: CGContext) {
    let count = CTRunGetGlyphCount(self)
    guard count > 0 else {
      return
    }
    var glyphs = [CGGlyph](repeating: 0, times: UInt(count))
    var positions = [CGPoint](repeating: .zero, times: UInt(count))
    CTRunGetGlyphs(self, CFRange(location: 0, length: 0), &glyphs)
    CTRunGetPositions(self, CFRange(location: 0, length: 0), &positions)

    context.withPreservedTextState {
      context.translateBy(x: position.x, y: position.y)
      context.textPosition = .zero
      context.textMatrix = CTRunGetTextMatrix(self)
      CTFontDrawGlyphs(font, glyphs, positions, count, context)
    }
  }
}
