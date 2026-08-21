// Copyright 2026 Yandex LLC. All rights reserved.

import CoreGraphics
import CoreText
import Foundation

typealias LineLayout = (
  line: CTLine,
  bounds: TypographicBounds,
  range: NSRange,
  isTruncated: Bool,
  paragraphAttributes: ParagraphAttributes
)

struct TextLayout {
  var lines: [LineLayout]
  private var sourceLength: Int

  var width: CGFloat {
    lines.map { $0.bounds.width + $0.paragraphAttributes.headIndent }.max() ?? 0
  }

  var height: CGFloat {
    lines.reduce(0) { $0 + $1.bounds.height + $1.paragraphAttributes.spacingBefore }
  }

  var size: CGSize {
    CGSize(width: width, height: height).ceiled()
  }

  var range: NSRange {
    let location = lines.first?.range.location ?? 0
    return NSRange(location: location, length: textLength)
  }

  var textLength: Int {
    lines.reduce(0) { $0 + $1.range.length }
  }

  var ascent: CGFloat? {
    guard lines.count > 0 else {
      return nil
    }
    return lines[0].bounds.ascent
  }

  init(lines: [LineLayout], sourceLength: Int) {
    self.lines = lines
    self.sourceLength = sourceLength
  }

  func entireTextFits(_ size: CGSize) -> Bool {
    sourceLength == textLength &&
      width <= size.width &&
      height <= size.height
  }
}
