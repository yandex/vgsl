// Copyright 2026 Yandex LLC. All rights reserved.

import CoreGraphics
import CoreText

public protocol GlyphRenderer: AnyObject {
  /// Receives a shaped run and its line origin in the current CoreText coordinate system.
  /// Pass the origin unchanged to `CTRun.drawGlyphs(at:in:)` when drawing the run.
  /// Return true after replacing its glyphs; VGSL still draws single underlines,
  /// single strikethroughs, shadows and images. Return false to preserve the normal rendering.
  /// Do not retain the drawing context.
  func drawGlyphs(of run: CTRun, at lineOrigin: CGPoint, in context: CGContext) -> Bool
}
