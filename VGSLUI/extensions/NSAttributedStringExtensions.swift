// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics
import CoreText
import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

import VGSLFundamentals

extension NSAttributedString {
  public enum VerticalPosition {
    case top
    case center
    case bottom
  }

  public func sizeForWidth(_ width: CGFloat) -> CGSize {
    sizeForString(
      TextLayoutParams(
        string: self,
        maxTextSize: CGSize(width: width, height: .infinity),
        maxNumberOfLines: Int.max,
        truncationToken: nil
      )
    )
  }

  /// Calculates the height required to display the attributed string within a specified width,
  /// considering the maximum number of lines and an optional truncation token.
  ///
  /// - Parameters:
  ///   - width: The maximum allowable width for the string's layout.
  ///   - maxNumberOfLines: The maximum number of lines allowed for the string.
  ///     If the string exceeds this number of lines, it will be truncated.
  ///   - minNumberOfHiddenLines: The minimum number of lines that must remain hidden
  ///     when truncation occurs. Default is 0.
  ///   - truncationToken: An optional NSAttributedString that is appended to the end
  ///     of the truncated text to indicate truncation (e.g., "..." or "Read more").
  public func heightForWidth(
    _ width: CGFloat,
    maxNumberOfLines: Int,
    minNumberOfHiddenLines: Int = 0,
    truncationToken: NSAttributedString? = nil
  ) -> CGFloat {
    let maxTextSize = CGSize(width: width, height: .infinity)
    if minNumberOfHiddenLines > 0 {
      let layout = computeLayout(
        for: self,
        maxTextSize: maxTextSize,
        maxNumberOfLines: Int.max
      )
      if layout.lines.count < maxNumberOfLines + minNumberOfHiddenLines {
        return layout.height
      }
    }

    let layoutParams = TextLayoutParams(
      string: self,
      maxTextSize: maxTextSize,
      maxNumberOfLines: maxNumberOfLines,
      truncationToken: truncationToken
    )

    return sizeForString(layoutParams).height
  }

  public func heightForWidth(_ width: CGFloat, maxTextHeight: CGFloat) -> CGFloat {
    sizeForString(
      TextLayoutParams(
        string: self,
        maxTextSize: CGSize(width: width, height: maxTextHeight),
        maxNumberOfLines: Int.max,
        truncationToken: nil
      )
    ).height
  }

  public func sizeThatFits(_ size: CGSize, maxNumberOfLines: Int) -> CGSize {
    sizeForString(
      TextLayoutParams(
        string: self,
        maxTextSize: size,
        maxNumberOfLines: maxNumberOfLines,
        truncationToken: nil
      )
    )
  }

  public func ascent(forWidth width: CGFloat) -> CGFloat? {
    let maxTextSize = CGSize(width: width, height: .infinity)
    let layout = computeLayout(
      for: self,
      maxTextSize: maxTextSize,
      maxNumberOfLines: 1
    )
    return layout.ascent
  }
}

public func measureString(
  _ string: NSAttributedString,
  maxTextSize: CGSize,
  maxNumberOfLines: Int = .max
) -> (size: CGSize, numberOfLines: Int) {
  let linesConstraint = (maxNumberOfLines > 0) ? maxNumberOfLines : .max
  let layout = computeLayout(
    for: string,
    maxTextSize: maxTextSize,
    maxNumberOfLines: linesConstraint
  )
  return (layout.size, layout.lines.count)
}

private let sizeForString =
  memoize { (
    layoutParams: TextLayoutParams
  ) -> CGSize in
    let layout = computeLayout(
      for: layoutParams.string,
      maxTextSize: layoutParams.maxTextSize,
      maxNumberOfLines: layoutParams.maxNumberOfLines,
      truncationToken: layoutParams.truncationToken
    )
    return layout.size
  }

private func computeLayout(
  for string: NSAttributedString,
  maxTextSize: CGSize,
  maxNumberOfLines: Int,
  truncationToken: NSAttributedString? = nil
) -> TextLayout {
  if string.containsSoftHyphens {
    let layout = string
      .makeCopyWithoutSoftHyphens()
      .makeTextLayout(
        in: maxTextSize,
        maxNumberOfLines: maxNumberOfLines,
        breakWords: false,
        truncationToken: truncationToken
      )
    if layout.entireTextFits(maxTextSize) {
      return layout
    }
  }
  return string.makeTextLayout(
    in: maxTextSize,
    maxNumberOfLines: maxNumberOfLines,
    breakWords: true,
    truncationToken: truncationToken
  )
}

private struct TextLayoutParams: Hashable, @unchecked Sendable {
  let string: NSAttributedString
  let maxTextSize: CGSize
  let maxNumberOfLines: Int
  let truncationToken: NSAttributedString?

  init(
    string: NSAttributedString,
    maxTextSize: CGSize,
    maxNumberOfLines: Int,
    truncationToken: NSAttributedString?
  ) {
    if string is NSMutableAttributedString {
      self.string = string.copy() as! NSAttributedString
    } else {
      self.string = string
    }
    self.maxTextSize = maxTextSize
    self.maxNumberOfLines = maxNumberOfLines
    if let truncationToken, truncationToken is NSMutableAttributedString {
      self.truncationToken = truncationToken.copy() as? NSAttributedString
    } else {
      self.truncationToken = truncationToken
    }
  }
}

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

struct ParagraphAttributes {
  let headIndent: CGFloat
  let spacingBefore: CGFloat
}

private let ellipsis = "\u{2026}"
private let softHyphen: UTF16.CodeUnit = 0x00_AD
private let lineFeed: UTF16.CodeUnit = 0x00_0A
private let carriageReturn: UTF16.CodeUnit = 0x00_0D

extension NSAttributedString {
  var containsSoftHyphens: Bool {
    string.utf16.contains(softHyphen)
  }

  private func firstLineHeadIndent(at offset: Int) -> CGFloat {
    let paragraphStyle = attribute(
      .paragraphStyle,
      at: offset,
      effectiveRange: nil
    ) as? NSParagraphStyle
    return paragraphStyle?.firstLineHeadIndent ?? 0
  }

  private func headIndent(at offset: Int) -> CGFloat {
    let paragraphStyle = attribute(
      .paragraphStyle,
      at: offset,
      effectiveRange: nil
    ) as? NSParagraphStyle
    return paragraphStyle?.headIndent ?? 0
  }

  private func paragraphSpacing(at offset: Int) -> CGFloat {
    let paragraphStyle = attribute(
      .paragraphStyle,
      at: offset,
      effectiveRange: nil
    ) as? NSParagraphStyle
    return paragraphStyle?.paragraphSpacing ?? 0
  }

  private func paragraphSpacingBefore(at offset: Int) -> CGFloat {
    let paragraphStyle = attribute(
      .paragraphStyle,
      at: offset,
      effectiveRange: nil
    ) as? NSParagraphStyle
    return paragraphStyle?.paragraphSpacingBefore ?? 0
  }

  func makeTextLayout(
    in size: CGSize,
    maxNumberOfLines: Int = .max,
    breakWords: Bool,
    truncationToken: NSAttributedString? = nil
  ) -> TextLayout {
    let typesetter = CTTypesetterCreateWithAttributedString(self)
    var offset = 0
    var lines = [LineLayout]()
    var textHeight: CGFloat = 0
    var isNewline = true
    var savedHeadIndent: CGFloat = 0
    var savedParagraphSpacing: CGFloat = 0

    while offset < length, lines.count < maxNumberOfLines {
      let paragraphAttributes: ParagraphAttributes
      if isNewline {
        paragraphAttributes = ParagraphAttributes(
          headIndent: firstLineHeadIndent(at: offset),
          spacingBefore: paragraphSpacingBefore(at: offset) + savedParagraphSpacing
        )
        savedHeadIndent = headIndent(at: offset)
        savedParagraphSpacing = paragraphSpacing(at: offset)
      } else {
        paragraphAttributes = ParagraphAttributes(
          headIndent: savedHeadIndent,
          spacingBefore: 0
        )
      }

      let availableWidth = size.width - paragraphAttributes.headIndent
      let lineLength = breakWords ?
        typesetter.lineLength(from: offset, constrainedTo: availableWidth) :
        typesetter.lineLengthByWordBoundary(
          for: string,
          from: offset,
          constrainedTo: availableWidth
        )

      guard lineLength > 0 else {
        break
      }

      let suggestedRange = CFRange(location: offset, length: lineLength)
      let layout: LineLayout

      if subrangeEndsWithSoftHyphen(suggestedRange.nsRange) {
        assert(breakWords)
        layout = layoutHyphenatedLine(
          typesetter: typesetter,
          range: suggestedRange,
          availableWidth: availableWidth,
          paragraphAttributes: paragraphAttributes
        )
      } else {
        layout = layoutLine(
          typesetter: typesetter,
          range: suggestedRange,
          paragraphAttributes: paragraphAttributes
        )
      }

      textHeight += layout.bounds.height + paragraphAttributes.spacingBefore
      isNewline = string.utf16.prefix(layout.range.endIndex).last?.isNewline ?? false
      let fitsByHeight = textHeight.isApproximatelyLessOrEqualThan(size.height)
      let nextLineFitsByLineNumber = (lines.count < maxNumberOfLines - 1 && !singleLineBreakMode) ||
        suggestedRange.nsRange.endIndex == length

      if fitsByHeight, nextLineFitsByLineNumber {
        lines.append(layout)
        offset += layout.range.length
      } else if !nextLineFitsByLineNumber {
        if let lastLine = makeTruncatedLine(
          from: suggestedRange.nsRange,
          constrainedTo: availableWidth,
          truncationToken: truncationToken
        ) {
          lines.append((
            lastLine,
            lastLine.typographicBounds,
            suggestedRange.nsRange,
            true,
            paragraphAttributes
          ))
        }
        break
      } else {
        let wholeRange = NSRange(location: 0, length: length)
        let remainingRange = lines.last?.range ?? wholeRange
        let lastParagraphAttributes = lines.last?.paragraphAttributes ?? ParagraphAttributes(
          headIndent: 0,
          spacingBefore: 0
        )
        if let lastLine = makeTruncatedLine(
          from: remainingRange,
          constrainedTo: size.width - lastParagraphAttributes.headIndent,
          truncationToken: truncationToken
        ) {
          lines.removeLastIfExists()
          lines.append((
            lastLine,
            lastLine.typographicBounds,
            suggestedRange.nsRange,
            true,
            lastParagraphAttributes
          ))
        }
        break
      }
    }

    if string.last?.isNewline == true {
      let layout = layoutLine(
        typesetter: typesetter,
        range: CFRange(location: offset - 1, length: 1),
        paragraphAttributes: ParagraphAttributes(
          headIndent: 0,
          spacingBefore: savedParagraphSpacing
        )
      )
      textHeight += layout.bounds.height + savedParagraphSpacing
      let fitsByHeight = textHeight.isApproximatelyLessOrEqualThan(size.height)
      let nextLineFitsByLineNumber = lines.count < maxNumberOfLines - 1 && !singleLineBreakMode
      if fitsByHeight, nextLineFitsByLineNumber {
        lines.append(layout)
      }
    }

    return TextLayout(lines: lines, sourceLength: length)
  }

  private func layoutHyphenatedLine(
    typesetter: CTTypesetter,
    range: CFRange,
    availableWidth: CGFloat,
    paragraphAttributes: ParagraphAttributes
  ) -> LineLayout {
    let line = makeHyphenatedLine(from: range.nsRange)
    let extent = line.typographicBounds.width - availableWidth
    if extent > 0 {
      let correctedLength = typesetter.lineLength(
        from: range.location,
        constrainedTo: availableWidth - extent
      )
      if correctedLength > 0 {
        let correctedRange = CFRange(location: range.location, length: correctedLength)
        if subrangeEndsWithSoftHyphen(correctedRange.nsRange) {
          let correctedLine = makeHyphenatedLine(from: correctedRange.nsRange)
          return (
            correctedLine,
            correctedLine.typographicBounds,
            correctedRange.nsRange,
            false,
            paragraphAttributes
          )
        } else {
          return layoutLine(
            typesetter: typesetter,
            range: correctedRange,
            paragraphAttributes: paragraphAttributes
          )
        }
      }
    }
    return (line, line.typographicBounds, range.nsRange, false, paragraphAttributes)
  }

  private func layoutLine(
    typesetter: CTTypesetter,
    range: CFRange,
    paragraphAttributes: ParagraphAttributes
  ) -> LineLayout {
    let range = range.nsRange
    let trimCharsNumber = string.utf16.count == range
      .upperBound ? 0 : trailingSymbolsTrimCount(range)
    let lineLength = range.length - trimCharsNumber
    let line = CTTypesetterCreateLine(
      typesetter,
      CFRange(location: range.location, length: lineLength)
    )
    return (line, line.typographicBounds, range, false, paragraphAttributes)
  }

  private func makeHyphenatedLine(from range: NSRange) -> CTLine {
    let copyString = attributedSubstring(from: range).mutableCopy() as! NSMutableAttributedString
    copyString.appendWithPreservedAttributes("-")
    return CTLineCreateWithAttributedString(copyString)
  }

  public func draw(
    inContext context: CGContext,
    verticalPosition: VerticalPosition = .center,
    rect: CGRect,
    textInsets: EdgeInsets = .zero
  ) {
    _ = drawAndGetLayout(
      inContext: context,
      verticalPosition: verticalPosition,
      rect: rect,
      textInsets: textInsets,
      actionKey: nil,
      backgroundKey: nil,
      borderKey: nil,
      rangeVerticalAlignmentKey: nil,
      selectedRange: nil
    ) as AttributedStringLayout<Void>
  }

  public func drawAndGetLayout(
    inContext context: CGContext?,
    verticalPosition: VerticalPosition = .center,
    rect: CGRect,
    textInsets: EdgeInsets = .zero,
    truncationToken: NSAttributedString? = nil
  ) -> AttributedStringLayout<Void> {
    drawAndGetLayout(
      inContext: context,
      verticalPosition: verticalPosition,
      rect: rect,
      textInsets: textInsets,
      truncationToken: truncationToken,
      actionKey: nil,
      backgroundKey: nil,
      borderKey: nil,
      rangeVerticalAlignmentKey: nil,
      selectedRange: nil
    )
  }

  public func drawAndGetLayout<ActionType>(
    inContext context: CGContext?,
    verticalPosition: VerticalPosition = .center,
    rect: CGRect,
    textInsets: EdgeInsets = .zero,
    truncationToken: NSAttributedString? = nil,
    actionKey: NSAttributedString.Key? = nil,
    backgroundKey: NSAttributedString.Key? = nil,
    borderKey: NSAttributedString.Key? = nil,
    rangeVerticalAlignmentKey: NSAttributedString.Key? = nil,
    selectedRange: Range<Int>? = nil
  ) -> AttributedStringLayout<ActionType> {
    context?.saveGState()
    defer {
      context?.restoreGState()
    }

    let transform = CGAffineTransform(translationX: 0, y: rect.height)
      .scaledBy(x: 1, y: -1)

    context?.concatenate(transform)
    context?.textMatrix = CGAffineTransform.identity
    let transformedRect = rect.applying(transform)

    if containsSoftHyphens {
      let copy = makeCopyWithoutSoftHyphens()
      let layout = copy.makeTextLayout(
        in: rect.size,
        breakWords: false,
        truncationToken: truncationToken
      )
      if layout.entireTextFits(rect.size) {
        return copy.drawAndGetLayoutImpl(
          inContext: context,
          verticalPosition: verticalPosition,
          rect: transformedRect,
          textInsets: textInsets,
          truncationToken: truncationToken,
          actionKey: actionKey,
          backgroundKey: backgroundKey,
          borderKey: borderKey,
          rangeVerticalAlignmentKey: rangeVerticalAlignmentKey,
          selectedRange: selectedRange
        )
      }
    }
    return drawAndGetLayoutImpl(
      inContext: context,
      verticalPosition: verticalPosition,
      rect: transformedRect,
      textInsets: textInsets,
      truncationToken: truncationToken,
      actionKey: actionKey,
      backgroundKey: backgroundKey,
      borderKey: borderKey,
      rangeVerticalAlignmentKey: rangeVerticalAlignmentKey,
      selectedRange: selectedRange
    )
  }

  private func drawAndGetLayoutImpl<ActionType>(
    inContext context: CGContext?,
    verticalPosition: VerticalPosition,
    rect: CGRect,
    textInsets: EdgeInsets,
    truncationToken: NSAttributedString?,
    actionKey: NSAttributedString.Key?,
    backgroundKey: NSAttributedString.Key?,
    borderKey: NSAttributedString.Key?,
    rangeVerticalAlignmentKey: NSAttributedString.Key?,
    selectedRange _: Range<Int>?
  ) -> AttributedStringLayout<ActionType> {
    let layout = makeTextLayout(
      in: rect.size.inset(by: textInsets),
      breakWords: true,
      truncationToken: truncationToken
    )
    var runsLayout = [AttributedStringLayout<ActionType>.Run]()

    assert(
      // accuracy is needed because sometimes text is a bit higher,
      // but it's not noticeable in rendering and doesn't affect vertical position
      layout.lines.count == 1 ||
        rect.height.isApproximatelyGreaterOrEqualThan(layout.height, withAccuracy: 0.5),
      "Layout constrained to some height should not exceed it"
    )
    let maybeNegativeOffset = verticalPosition.verticalOffset(
      forHeight: layout.height,
      availableHeight: rect.height
    )
    let verticalOffset = max(maybeNegativeOffset, 0)
    var lineOriginY: CGFloat = rect.height - verticalOffset
    var firstLineOriginX: CGFloat?

    if let context {
      drawClouds(
        context: context,
        verticalPosition: verticalPosition,
        rect: rect,
        textInsets: textInsets,
        layout: layout
      )
    }

    var lines: [AttributedStringLineLayout] = []
    for (line, bounds, range, isTruncated, paragraphAttributes) in layout.lines {
      let lineOriginX = horizontalOffset(
        lineWidth: bounds.width,
        maxWidth: rect.width,
        headIndent: paragraphAttributes.headIndent
      )
      if firstLineOriginX == nil {
        firstLineOriginX = lineOriginX + rect.origin.x
      }
      lineOriginY -= paragraphAttributes.spacingBefore
      let textPosition = CGPoint(
        x: rect.origin.x + lineOriginX + textInsets.left,
        y: rect.origin.y + lineOriginY - bounds.ascent - textInsets.top
      )

      if let context {
        let runsWithAction: [AttributedStringLayout<ActionType>.Run] = line.draw(
          at: textPosition,
          in: context,
          rect: rect,
          layoutY: rect.maxY - lineOriginY,
          actionKey: actionKey,
          backgroundKey: backgroundKey,
          rangeVerticalAlignmentKey: rangeVerticalAlignmentKey,
          borderKey: borderKey
        )
        runsLayout += runsWithAction
      } else {
        break
      }

      lines.append(AttributedStringLineLayout(
        line: line,
        verticalOffset: lineOriginY,
        horizontalOffset: lineOriginX,
        range: range,
        isTruncated: isTruncated
      ))
      lineOriginY -= bounds.height
    }

    return AttributedStringLayout(
      firstLineOriginX: firstLineOriginX,
      runsWithAction: runsLayout,
      lines: lines
    )
  }

  private func drawClouds(
    context: CGContext,
    verticalPosition: VerticalPosition,
    rect: CGRect,
    textInsets: EdgeInsets,
    layout: TextLayout
  ) {
    let maybeNegativeOffset = verticalPosition.verticalOffset(
      forHeight: layout.height,
      availableHeight: rect.height
    )
    let verticalOffset = max(maybeNegativeOffset, 0)
    var lineOriginY: CGFloat = rect.height - verticalOffset
    var firstLineOriginX: CGFloat?

    var clouds: [CloudBackgroundAttribute: [CGRect]] = [:]
    for (line, bounds, _, _, paragraphAttributes) in layout.lines {
      let lineOriginX = horizontalOffset(
        lineWidth: bounds.width,
        maxWidth: rect.width,
        headIndent: paragraphAttributes.headIndent
      )
      if firstLineOriginX == nil {
        firstLineOriginX = lineOriginX + rect.origin.x
      }
      lineOriginY -= paragraphAttributes.spacingBefore
      let textPosition = CGPoint(
        x: rect.origin.x + lineOriginX + textInsets.left,
        y: rect.origin.y + lineOriginY - bounds.ascent - textInsets.top
      )
      let cloudBackgrounds = line.calculateCloudsLayout(at: textPosition)
      clouds.append(cloudBackgrounds: cloudBackgrounds)
      lineOriginY -= bounds.height
    }
    for (info, cloudsRects) in clouds {
      draw(context: context, info: info, cloudsRects: cloudsRects)
    }
  }

  private func draw(
    context: CGContext?,
    info: CloudBackgroundAttribute,
    cloudsRects: [CGRect]
  ) {
    guard let context, !cloudsRects.isEmpty else { return }
    var leftPoints: [CGPoint] = []
    var rightPoints: [CGPoint] = []
    let paddings = info.insets ?? .init(vertical: 0, horizontal: 0)

    func appendRect(_ rect: CGRect) {
      rightPoints.append(rect.coordinate(ofCorner: .bottomRight))
      rightPoints.append(rect.coordinate(ofCorner: .topRight))
      leftPoints.append(rect.coordinate(ofCorner: .bottomLeft))
      leftPoints.append(rect.coordinate(ofCorner: .topLeft))
    }

    if cloudsRects.count == 1 {
      appendRect(cloudsRects[0].expanded(by: paddings))
    } else {
      for index in 0..<cloudsRects.count {
        let newPaddings: EdgeInsets
        if index == 0 {
          newPaddings = EdgeInsets(
            top: 0,
            left: paddings.left,
            bottom: paddings.bottom,
            right: paddings.right
          )
        } else if index == cloudsRects.count - 1 {
          newPaddings = EdgeInsets(
            top: paddings.top,
            left: paddings.left,
            bottom: 0,
            right: paddings.right
          )
        } else {
          newPaddings = EdgeInsets(top: 0, left: paddings.left, bottom: 0, right: paddings.right)
        }
        appendRect(cloudsRects[index].expanded(by: newPaddings))
      }
    }

    let points: [CGPoint] = rightPoints + leftPoints.reversed()
    context.drawCloud(points: points, cornerRadius: info.cornerRadius, backgroundColor: info.color)
  }

  public func drawSelection(
    context: CGContext?,
    rect: CGRect,
    linesLayout: [AttributedStringLineLayout],
    selectedRange: Range<Int>?
  ) -> CGRect {
    context?.saveGState()
    defer {
      context?.restoreGState()
    }

    let transform = CGAffineTransform(translationX: 0, y: rect.height)
      .scaledBy(x: 1, y: -1)

    context?.concatenate(transform)
    context?.textMatrix = CGAffineTransform.identity
    let transformedRect = rect.applying(transform)
    var selectionRect = CGRect.zero
    for lineLayout in linesLayout {
      drawLineSelection(
        context: context,
        selectionRect: &selectionRect,
        selectedRange: selectedRange,
        rect: transformedRect,
        line: lineLayout.line,
        lineHeight: lineLayout.line.typographicBounds.height,
        range: lineLayout.range,
        lineOriginX: lineLayout.horizontalOffset,
        lineOriginY: lineLayout.verticalOffset,
        isTruncated: lineLayout.isTruncated
      )
    }
    return selectionRect
  }

  private func drawLineSelection(
    context: CGContext?,
    selectionRect: inout CGRect,
    selectedRange: Range<Int>?,
    rect: CGRect,
    line: CTLine,
    lineHeight: CGFloat,
    range: NSRange,
    lineOriginX: CGFloat,
    lineOriginY: CGFloat,
    isTruncated: Bool
  ) {
    guard let leadingSelectionIndex = selectedRange?.lowerBound,
          let trailingSelectionIndex = selectedRange?.upperBound else {
      return
    }

    let needDrawLeadingPointer: Bool
    let needDrawTrailingPointer: Bool

    let leadingSelectionOffset: CGFloat?
    let trailingSelectionOffset: CGFloat?

    if (range.lowerBound...range.upperBound).contains(leadingSelectionIndex),
       (range.lowerBound...range.upperBound).contains(trailingSelectionIndex) {
      let trailingOffset = CTLineGetOffsetForStringIndex(
        line,
        normalizedLineIndex(
          index: trailingSelectionIndex,
          isTruncated: isTruncated,
          range: range
        ),
        nil
      )
      let leadingOffset = CTLineGetOffsetForStringIndex(
        line,
        normalizedLineIndex(
          index: leadingSelectionIndex,
          isTruncated: isTruncated,
          range: range
        ),
        nil
      )
      needDrawLeadingPointer = true
      needDrawTrailingPointer = true
      leadingSelectionOffset = leadingOffset
      trailingSelectionOffset = trailingOffset
      selectionRect = CGRect(
        origin: CGPoint(x: lineOriginX + leadingOffset, y: rect.height - lineOriginY),
        size: CGSize(width: trailingOffset - leadingOffset, height: lineHeight)
      )
    } else if (range.lowerBound..<range.upperBound).contains(leadingSelectionIndex) {
      let leadingOffset = CTLineGetOffsetForStringIndex(
        line,
        normalizedLineIndex(
          index: leadingSelectionIndex,
          isTruncated: isTruncated,
          range: range
        ),
        nil
      )
      let trailingOffset = CTLineGetOffsetForStringIndex(
        line,
        normalizedLineIndex(
          index: range.upperBound - 1,
          isTruncated: isTruncated,
          range: range
        ),
        nil
      )
      needDrawLeadingPointer = true
      needDrawTrailingPointer = false
      leadingSelectionOffset = leadingOffset
      trailingSelectionOffset = trailingOffset
      selectionRect.origin = CGPoint(x: lineOriginX, y: rect.height - lineOriginY)
    } else if ((range.lowerBound + 1)...range.upperBound).contains(trailingSelectionIndex) {
      let leadingOffset = CTLineGetOffsetForStringIndex(
        line,
        normalizedLineIndex(index: range.lowerBound, isTruncated: isTruncated, range: range),
        nil
      )
      let trailingOffset = CTLineGetOffsetForStringIndex(line, trailingSelectionIndex, nil)
      needDrawLeadingPointer = false
      needDrawTrailingPointer = true
      leadingSelectionOffset = leadingOffset
      trailingSelectionOffset = trailingOffset
      selectionRect.size = CGSize(
        width: CTLineGetOffsetForStringIndex(line, range.upperBound - 1, nil) - selectionRect
          .origin.x,
        height: abs((rect.height - lineOriginY) - selectionRect.origin.y + lineHeight)
      )
    } else if leadingSelectionIndex < range.lowerBound,
              trailingSelectionIndex >= range.lowerBound {
      let leadingOffset = CTLineGetOffsetForStringIndex(
        line,
        normalizedLineIndex(index: range.lowerBound, isTruncated: isTruncated, range: range),
        nil
      )
      let trailingOffset = CTLineGetOffsetForStringIndex(line, range.upperBound - 1, nil)
      needDrawLeadingPointer = false
      needDrawTrailingPointer = false
      leadingSelectionOffset = leadingOffset
      trailingSelectionOffset = trailingOffset
    } else {
      leadingSelectionOffset = nil
      trailingSelectionOffset = nil
      needDrawLeadingPointer = false
      needDrawTrailingPointer = false
    }

    guard let leadingSelectionOffset,
          let trailingSelectionOffset else {
      return
    }

    let leftmostTextSelectionPoint = CGPoint(
      x: rect.origin.x + lineOriginX + leadingSelectionOffset,
      y: rect.origin.y + lineOriginY - lineHeight
    )

    context?.setFillColor(selectionColor.cgColor)
    context?.fill(CGRect(
      origin: leftmostTextSelectionPoint,
      size: CGSize(
        width: trailingSelectionOffset - leadingSelectionOffset,
        height: lineHeight
      )
    ))

    context?.setFillColor(selectionPointerColor.cgColor)

    if needDrawLeadingPointer {
      drawLeadingPointer(
        context: context,
        leftmostTextSelectionPoint: leftmostTextSelectionPoint,
        lineHeight: lineHeight
      )
    }

    if needDrawTrailingPointer {
      drawTrailingPointer(
        context: context,
        rightmostTextSelectionPoint: leftmostTextSelectionPoint
          .movingX(by: -leadingSelectionOffset + trailingSelectionOffset),
        lineHeight: lineHeight
      )
    }
  }

  private func drawTrailingPointer(
    context: CGContext?,
    rightmostTextSelectionPoint: CGPoint,
    lineHeight: CGFloat
  ) {
    context?.fill(CGRect(
      origin: rightmostTextSelectionPoint,
      size: CGSize(
        width: pointerShapeWidth,
        height: lineHeight
      )
    ))

    context?.fillEllipse(in: CGRect(
      origin: rightmostTextSelectionPoint
        .movingX(by: -pointerCircleSize.width / 2 + pointerShapeWidth / 2),
      size: pointerCircleSize
    ))
  }

  private func drawLeadingPointer(
    context: CGContext?,
    leftmostTextSelectionPoint: CGPoint,
    lineHeight: CGFloat
  ) {
    context?.fill(CGRect(
      origin: leftmostTextSelectionPoint.movingX(by: -pointerShapeWidth),
      size: CGSize(
        width: pointerShapeWidth,
        height: lineHeight
      )
    ))

    context?.fillEllipse(in: CGRect(
      origin: leftmostTextSelectionPoint
        .movingX(by: -pointerCircleSize.width / 2 - pointerShapeWidth / 2)
        .movingY(by: lineHeight - pointerCircleSize.height),
      size: pointerCircleSize
    ))
  }

  private func normalizedLineIndex(index: Int, isTruncated: Bool, range: NSRange) -> Int {
    isTruncated ? index - range.lowerBound : index
  }

  private func horizontalOffset(
    lineWidth: CGFloat,
    maxWidth: CGFloat,
    headIndent: CGFloat
  ) -> CGFloat {
    switch textAlignment {
    case .left, .natural, .justified:
      headIndent
    case .center:
      max(((maxWidth - lineWidth) / 2).roundedToScreenScale, 0)
    case .right:
      max(maxWidth - lineWidth + headIndent, 0)
    @unknown default:
      0
    }
  }

  private func subrangeEndsWithSoftHyphen(_ range: NSRange) -> Bool {
    let index = string.utf16.index(
      string.utf16.startIndex,
      offsetBy: range.location + range.length - 1
    )
    return string.utf16[index] == softHyphen
  }

  private func trailingSymbolsTrimCount(_ range: NSRange) -> Int {
    guard range.length > 1 else {
      return 0
    }
    let utf16 = string.utf16
    let lastSymbolIndex = utf16.index(
      utf16.startIndex,
      offsetBy: range.endIndex - 1
    )
    let lastSymbol = utf16[lastSymbolIndex]
    if lastSymbol == lineFeed, range.length > 2 {
      let preLastIndex = utf16.index(before: lastSymbolIndex)
      return utf16[preLastIndex] == carriageReturn ? 2 : 1
    }
    return lastSymbol.isWhitespaceOrNewline ? 1 : 0
  }

  private func makeTruncatedLine(
    from range: NSRange,
    constrainedTo width: CGFloat,
    truncationToken: NSAttributedString?
  ) -> CTLine? {
    guard range.length > 0 else {
      return nil
    }

    let token: NSAttributedString
    if lineBreakMode == .byClipping {
      token = NSAttributedString()
    } else if let truncationToken {
      token = adjustTruncationTokenRanges(
        truncationToken,
        truncationOffset: length - range.location
      )
    } else {
      let allAttributes = attributes(at: range.endIndex - 1, effectiveRange: nil)
      token = NSAttributedString(string: ellipsis, attributes: allAttributes)
    }

    let remainingString: NSAttributedString
    let lineTerminatesDueToNewlineSymbol = string.utf16.prefix(range.endIndex).last!.isNewline
    if lineTerminatesDueToNewlineSymbol {
      let line = attributedSubstring(from: range)
      if line.truncationType == CTLineTruncationType.end {
        remainingString = line + token
      } else {
        remainingString = line
      }
    } else {
      remainingString = attributedSubstring(
        from: NSRange(location: range.location, length: length - range.location)
      )
    }

    let remainingLine = CTLineCreateWithAttributedString(remainingString)
    let tokenLine = CTLineCreateWithAttributedString(token)
    guard let truncatedLine = CTLineCreateTruncatedLine(
      remainingLine,
      Double(width),
      remainingString.truncationType,
      tokenLine
    ) else {
      return nil
    }

    let overrun = (truncatedLine.typographicBounds.width - width).roundedUpToScreenScale
    if overrun.isApproximatelyGreaterThan(0) {
      let roundedWidth = (width - overrun).roundedDownToScreenScale
      return CTLineCreateTruncatedLine(
        remainingLine,
        Double(roundedWidth),
        remainingString.truncationType,
        tokenLine
      )
    } else {
      return truncatedLine
    }
  }

  private func adjustTruncationTokenRanges(
    _ token: NSAttributedString,
    truncationOffset: Int
  ) -> NSAttributedString {
    guard let mutableToken = token.mutableCopy() as? NSMutableAttributedString else {
      return self
    }

    let fullRange = NSRange(location: 0, length: token.length)
    token.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
      if let border = attributes[BorderAttribute.Key] as? BorderAttribute {
        var newAttributes = attributes
        let adjustedRange = CFRange(
          location: border.range.location + truncationOffset,
          length: border.range.length
        )
        let adjustedBorder = BorderAttribute(
          color: border.color,
          width: border.width,
          cornerRadius: border.cornerRadius,
          range: adjustedRange
        )
        newAttributes[BorderAttribute.Key] = adjustedBorder
        mutableToken.setAttributes(newAttributes, range: range)
      }
    }
    return mutableToken
  }

  private var lineBreakMode: LineBreakMode {
    guard length > 0 else {
      return .byWordWrapping
    }
    let paragraphStyle = attribute(
      .paragraphStyle,
      at: length - 1,
      effectiveRange: nil
    ) as? NSParagraphStyle
    return paragraphStyle?.lineBreakMode ?? .byWordWrapping
  }

  private var truncationType: CTLineTruncationType {
    switch lineBreakMode {
    case .byTruncatingHead:
      .start
    case .byTruncatingMiddle:
      .middle
    default:
      .end
    }
  }

  private var singleLineBreakMode: Bool {
    switch lineBreakMode {
    case .byTruncatingHead, .byTruncatingMiddle:
      true
    case .byClipping, .byCharWrapping, .byWordWrapping, .byTruncatingTail:
      false
    @unknown default:
      false
    }
  }

  private var textAlignment: TextAlignment {
    let paragraphStyle = attribute(
      .paragraphStyle,
      at: 0,
      effectiveRange: nil
    ) as? NSParagraphStyle
    return paragraphStyle?.alignment ?? .natural
  }

  func makeCopyWithoutSoftHyphens() -> NSAttributedString {
    let copy = mutableCopy() as! NSMutableAttributedString
    let hyphenOffsets = copy.string.utf16
      .enumerated()
      .filter { $0.element == softHyphen }
      .map(\.offset)

    var deleteCount = 0

    for offset in hyphenOffsets {
      copy.deleteCharacters(in: NSRange(location: offset - deleteCount, length: 1))
      deleteCount += 1
    }

    return copy
  }
}

extension CTTypesetter {
  fileprivate func lineLength(from offset: Int, constrainedTo width: CGFloat) -> CFIndex {
    CTTypesetterSuggestLineBreak(self, offset, Double(width))
  }

  fileprivate func lineLengthByWordBoundary(
    for string: String,
    from offset: Int,
    constrainedTo width: CGFloat
  ) -> Int {
    let lineLength = self.lineLength(from: offset, constrainedTo: width)

    if lineLength + offset == string.utf16.count {
      return lineLength
    }

    if string.utf16.prefix(offset + lineLength).last?.isWhitespaceOrNewline == true {
      return lineLength
    }

    let whitespaceOffsetFromEnd = string.utf16
      .dropFirst(offset)
      .prefix(lineLength)
      .reversed()
      .enumerated()
      .first(where: { _, unit in unit.isWhitespace })?.offset

    if let whitespaceOffsetFromEnd {
      return lineLength - whitespaceOffsetFromEnd - 1
    }

    return 0
  }
}

extension CTLine {
  fileprivate var runs: [CTRun] {
    CTLineGetGlyphRuns(self) as! [CTRun]
  }

  private var typographicBoundsNotConsideringEmojiHeight: TypographicBounds {
    let runsBounds: [TypographicBounds] = runs.map {
      let bounds = $0.typographicBounds
      let font = $0.font
      let baselineOffset = $0.baselineOffset

      let ascenderOffset = baselineOffset
      let descenderOffset = -baselineOffset

      if font.fontName != Font.emojiFontName {
        return modified(bounds) {
          $0.ascent += ascenderOffset
          $0.descent += descenderOffset
        }
      }
      let systemFont = Font.systemFont(ofSize: font.pointSize)
      return modified(bounds) {
        $0.ascent = systemFont.ascender + ascenderOffset
        $0.descent = abs(systemFont.descender) + descenderOffset
      }
    }

    guard !runsBounds.isEmpty else {
      return .default
    }

    return TypographicBounds(
      ascent: runsBounds.map(\.ascent).max()!,
      descent: runsBounds.map(\.descent).max()!,
      width: runsBounds.map(\.width).reduce(0, +)
    )
  }

  fileprivate var typographicBounds: TypographicBounds {
    var bounds = typographicBoundsNotConsideringEmojiHeight

    let height = bounds.height
    let (minHeight, maxHeight) = overriddenHeight

    var heightDiff: CGFloat = 0
    if height < minHeight {
      heightDiff += minHeight - height
    }
    if height > maxHeight {
      heightDiff -= height - maxHeight
    }

    let halfHeightDiff = heightDiff / 2
    bounds.ascent += halfHeightDiff
    bounds.descent += halfHeightDiff

    let descentAddition = 1 - modf(bounds.descent).1
    if descentAddition < 0.5 {
      bounds.ascent -= descentAddition
      bounds.descent += descentAddition
    }

    return bounds
  }

  private var overriddenHeight: (min: CGFloat, max: CGFloat) {
    var minHeight: CGFloat = 0
    var maxHeight: CGFloat = 0
    for run in runs {
      let style = run.paragraphStyle
      minHeight = max(minHeight, style?.minimumLineHeight ?? 0)
      maxHeight = max(maxHeight, style?.maximumLineHeight ?? 0)
    }
    if maxHeight == 0 {
      maxHeight = .greatestFiniteMagnitude
    }
    return (minHeight, maxHeight)
  }

  private var overriddenTypographicBounds: (ascent: CGFloat, descent: CGFloat, leading: CGFloat) {
    var lineAscent: CGFloat = 0
    var lineDescent: CGFloat = 0
    var lineLeading: CGFloat = 0

    CTLineGetTypographicBounds(self, &lineAscent, &lineDescent, &lineLeading)

    let (minHeight, maxHeight) = overriddenHeight
    let currentLineHeight = lineAscent + lineDescent

    var adjustedLineHeight = currentLineHeight
    if maxHeight < .greatestFiniteMagnitude && currentLineHeight > maxHeight {
        adjustedLineHeight = maxHeight
    } else if minHeight > 0 && currentLineHeight < minHeight {
        adjustedLineHeight = minHeight
    }

    let freeSpace = (adjustedLineHeight - currentLineHeight) / 2
    let adjustedAscent = freeSpace + lineAscent
    let adjustedDescent = freeSpace + lineDescent

    return (adjustedAscent, adjustedDescent, lineLeading)
  }

  struct CloudBackground {
    let rect: CGRect
    let info: CloudBackgroundAttribute
  }

  fileprivate func draw<ActionType>(
    at position: CGPoint,
    in context: CGContext,
    rect: CGRect,
    layoutY: CGFloat,
    actionKey: NSAttributedString.Key?,
    backgroundKey: NSAttributedString.Key?,
    rangeVerticalAlignmentKey: NSAttributedString.Key?,
    borderKey: NSAttributedString.Key?
  ) -> [AttributedStringLayout<ActionType>.Run] {
    var runsWithActions = [AttributedStringLayout<ActionType>.Run]()
    for run in runs {
      var position = position

      #if os(iOS)
      if let key = rangeVerticalAlignmentKey,
          let verticalAlignment = run.rangeVerticalAlignment(for: key)?.verticalAlignment,
          run.baselineOffset == 0 {
        let runAscent = run.typographicBounds.ascent
        let runDescent = run.typographicBounds.descent
        let lineAscent = overriddenTypographicBounds.ascent
        let lineDescent = overriddenTypographicBounds.descent

        switch verticalAlignment {
        case .top:
          position.y += lineAscent - runAscent
        case .bottom:
          position.y -= lineDescent - runDescent
        case .center:
          let lineCenter = (lineAscent - lineDescent) / 2
          let textCenter = (runAscent - runDescent) / 2
          position.y += lineCenter - textCenter
        case .baseline:
          break
        }
      }
      #endif

      let runPosition = CGPoint(
        x: position.x + run.origin.x,
        y: position.y + run.baselineOffset
      )
      if let action = (actionKey.flatMap(run.action) as ActionType?) {
        let bounds = run.typographicBounds
        runsWithActions.append(
          AttributedStringLayout<ActionType>.Run(
            rect: CGRect(
              x: runPosition.x,
              y: layoutY,
              width: bounds.width,
              height: bounds.height
            ),
            action: action
          )
        )
      }
      #if os(iOS)
      let border = borderKey.flatMap(run.border)
      let background = backgroundKey.flatMap(run.background)

      if background != nil || border != nil {
        var corners: UIRectCorner = []

        if let border {
          let leftIndex = CTLineGetStringIndexForPosition(self, runPosition - position.x)
          let rightIndex = CTLineGetStringIndexForPosition(
            self,
            runPosition.movingX(by: run.typographicBounds.width - position.x)
          )
          if (leftIndex...rightIndex).contains(border.range.location) {
            corners = [.topLeft, .bottomLeft]
          }
          if (leftIndex...rightIndex).contains(border.range.location + border.range.length - 1) {
            corners.update(with: [.topRight, .bottomRight])
          }
        }

        let borderWidth = border?.width ?? 0
        let padding = background?.padding ?? .zero

        let scaleX = (run.typographicBounds.width - borderWidth) / run.typographicBounds.width
        let scaleY = (run.typographicBounds.height - borderWidth) / run.typographicBounds.height

        let path = UIBezierPath(
          roundedRect: CGRect(
            origin: .zero,
            size: CGSize(
              width: run.typographicBounds.width + padding.horizontal.sum,
              height: run.typographicBounds.height + padding.vertical.sum
            )
          ),
          byRoundingCorners: corners,
          cornerRadii: CGSize(squareDimension: border?.cornerRadius ?? 0)
        )
        path.apply(CGAffineTransform(scaleX: scaleX, y: scaleY))
        path.apply(CGAffineTransform(
          translationX: runPosition.x + borderWidth / 2 - padding.left,
          y: runPosition.y + borderWidth / 2 - run.typographicBounds.descent - padding.bottom
        ))

        context.saveGState()
        context.setFillColor(background?.color ?? Color.clear.cgColor)
        context.setStrokeColor(border?.color ?? Color.clear.cgColor)
        context.setLineWidth(borderWidth)
        context.addPath(path.cgPath)
        context.closePath()
        context.drawPath(using: .fillStroke)
        context.restoreGState()
      }
      #endif

      context.textPosition = position

      context.inSeparateGState {
        context.performDrawing(shadedWith: run.shadow) {
          CTRunDraw(run, context, .infinite)
          if run.isUnderline {
            if #available(iOS 18, tvOS 18, macOS 13, *) {
              drawUnderline(for: run, at: runPosition, in: context)
            }
          }
          if run.isSingleStrikethrough {
            if #available(iOS 18, tvOS 18, *) {
              drawStrikethrough(for: run, at: runPosition, in: context)
            } else if #available(iOS 15, tvOS 15, *) {
              // Supported by CoreText directly
            } else {
              drawStrikethrough(for: run, at: runPosition, in: context)
            }
          }
        }
      }

      if let attachment = run.attachment,
         let image = attachment.image {
        context.saveGState()
        #if os(iOS) || os(tvOS)
        let imagePosition = position + run.origin + attachment.bounds.origin
        let positionTransform = CGAffineTransform(
          translationX: imagePosition.x,
          y: imagePosition.y
        )
        let transform = image.orientationTransform.concatenating(positionTransform)
        context.concatenate(transform)
        #endif

        context.draw(image.cgImg!, in: CGRect(origin: .zero, size: attachment.bounds.size))
        context.restoreGState()
      }
    }

    return runsWithActions
  }

  private func drawStrikethrough(for run: CTRun, at position: CGPoint, in context: CGContext) {
    let lineWidth = run.font.estimatedStrikethroughWidth

    context.saveGState()
    context.setStrokeColor(run.color)
    context.setLineWidth(lineWidth)
    context.addPath(
      run.strikethroughLine(
        forTextPosition: position,
        offset: run.baselineOffset + ceil(run.font.xHeight * 0.5)
      )
    )
    context.strokePath()
    context.restoreGState()
  }

  @available(iOS 16, tvOS 16, macOS 13, *)
  private func drawUnderline(for run: CTRun, at position: CGPoint, in context: CGContext) {
    context.saveGState()
    context.setStrokeColor(run.color)
    context.setLineWidth(run.font.underlineThickness)

    var underlinePath = run.strikethroughLine(
      forTextPosition: position,
      offset: run.font.underlinePosition - run.font.underlineThickness
    )
    for glyphPath in run.glyphPaths(runPosition: position) {
      let thickedPath = glyphPath.copy(
        strokingWithWidth: run.font.underlineThickness * 2.5,
        lineCap: .round,
        lineJoin: .round,
        miterLimit: 0
      )
      if !underlinePath.lineIntersection(thickedPath).isEmpty {
        underlinePath = underlinePath.lineSubtracting(thickedPath)
      }
    }
    context.addPath(underlinePath)
    context.strokePath()
    context.restoreGState()
  }

  fileprivate func calculateCloudsLayout(
    at position: CGPoint
  ) -> [CloudBackground] {
    var cloudBackgrounds: [CloudBackground] = []
    for run in runs {
      let runPosition = CGPoint(x: position.x + run.origin.x, y: position.y)
      let cloudBackground = run.cloudBackground(for: CloudBackgroundAttribute.Key)
      guard let cloudBackground else { continue }
      let maximumLineHeight: CGFloat = run.paragraphStyle?.maximumLineHeight ?? .zero

      let rect = CGRect(
        origin: runPosition.movingY(by: -run.typographicBounds.descent),
        size: CGSize(
          width: run.typographicBounds.width,
          height: max(run.typographicBounds.height, maximumLineHeight)
        )
      )
      if let cloudRun = cloudBackgrounds.last, cloudRun.info == cloudBackground {
        let newRect = CGRect(
          origin: cloudRun.rect.origin,
          size: CGSize(width: cloudRun.rect.width + rect.width, height: cloudRun.rect.height)
        )
        cloudBackgrounds[cloudBackgrounds.count - 1] = CloudBackground(
          rect: newRect,
          info: cloudBackground
        )
      } else {
        cloudBackgrounds.append(CloudBackground(rect: rect, info: cloudBackground))
      }
    }
    return cloudBackgrounds
  }
}

extension CTRun {
  private func attribute<T>(withName name: Any) -> T? {
    let runAttributes = CTRunGetAttributes(self) as NSDictionary
    return runAttributes[name].flatMap { $0 as? T }
  }

  private func attribute<T>(withName name: NSAttributedString.Key) -> T? {
    attribute(withName: name as Any)
  }

  fileprivate var typographicBounds: TypographicBounds {
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    let width = CGFloat(CTRunGetTypographicBounds(self, .infinite, &ascent, &descent, nil))
    return TypographicBounds(ascent: ascent, descent: descent, width: width)
  }

  fileprivate var baselineOffset: CGFloat {
    var offset: CGFloat? = attribute(withName: .baselineOffset)
    if #available(iOS 11, tvOS 11, OSX 10.13, *) {
      offset = offset ?? attribute(withName: kCTBaselineOffsetAttributeName)
    }
    return offset ?? 0
  }

  fileprivate var paragraphStyle: NSParagraphStyle? {
    let style: NSParagraphStyle? = attribute(withName: .paragraphStyle)
      ?? attribute(withName: kCTParagraphStyleAttributeName)
    return style
  }

  fileprivate var isSingleStrikethrough: Bool {
    let underlineStyle: Int? = attribute(withName: .strikethroughStyle)
    return underlineStyle == UnderlineStyle.single.rawValue
  }

  fileprivate var isUnderline: Bool {
    let underlineStyle: Int? = attribute(withName: .underlineStyle)
    return underlineStyle == UnderlineStyle.single.rawValue
  }

  fileprivate var color: CGColor {
    let color: Any? = attribute(withName: .foregroundColor) ??
      attribute(withName: kCTForegroundColorAttributeName)
    if let systemColor = color as? SystemColor {
      return systemColor.cgColor
    } else if let cgColor = safeCFCast(color as CFTypeRef) as CGColor? {
      return cgColor
    }

    return Color.black.cgColor
  }

  fileprivate var font: Font {
    let font: Font? = attribute(withName: .font) ?? attribute(withName: kCTFontAttributeName)
    return font ?? Font.systemFontWithDefaultSize()
  }

  fileprivate var attachment: TextAttachment? {
    let attachment: TextAttachment? = attribute(withName: .attachment)
    return attachment
  }

  fileprivate var origin: CGPoint {
    var origins = [CGPoint.zero]
    CTRunGetPositions(self, CFRangeMake(0, 1), &origins)
    return origins.first!
  }

  fileprivate func strikethroughLine(
    forTextPosition position: CGPoint,
    offset: CGFloat
  ) -> CGPath {
    let width = CTRunGetTypographicBounds(self, .infinite, nil, nil, nil)

    let start = CGPoint(
      x: position.x,
      y: position.y + offset
    )

    let end = CGPoint(
      x: position.x + CGFloat(width),
      y: position.y + offset
    )

    let path = CGMutablePath()
    path.move(to: start)
    path.addLine(to: end)
    return path
  }

  fileprivate var shadow: SystemShadow? {
    attribute(withName: .shadow)
  }

  fileprivate func action<ActionType>(for key: NSAttributedString.Key) -> ActionType? {
    attribute(withName: key) as ActionType?
  }

  fileprivate func background(for key: NSAttributedString.Key) -> BackgroundAttribute? {
    attribute(withName: key) as BackgroundAttribute?
  }

  fileprivate func cloudBackground(for key: NSAttributedString.Key) -> CloudBackgroundAttribute? {
    attribute(withName: key) as CloudBackgroundAttribute?
  }

  fileprivate func border(for key: NSAttributedString.Key) -> BorderAttribute? {
    attribute(withName: key) as BorderAttribute?
  }

  fileprivate func rangeVerticalAlignment(for key: NSAttributedString.Key) -> RangeVerticalAlignmentAttribute? {
    attribute(withName: key) as RangeVerticalAlignmentAttribute?
  }

  fileprivate func glyphPaths(runPosition: CGPoint) -> [CGPath] {
    let glyphCount = CTRunGetGlyphCount(self)
    var glyphs: [CGGlyph] = Array(repeating: CGGlyph(), count: glyphCount)
    CTRunGetGlyphs(self, .infinite, &glyphs)

    var positions: [CGPoint] = Array(repeating: .zero, count: glyphCount)
    CTRunGetPositions(self, .infinite, &positions)

    return zip(glyphs, positions).compactMap { glyph, position in
      var transform = CGAffineTransform.identity
        .translatedBy(x: position.x, y: runPosition.y + position.y)
      return CTFontCreatePathForGlyph(font, glyph, &transform)
    }
  }
}

extension NSMutableAttributedString {
  fileprivate func appendWithPreservedAttributes(_ string: String) {
    replaceCharacters(in: NSRange(location: length, length: 0), with: string)
  }
}

extension CFRange {
  fileprivate static let infinite = CFRange(location: 0, length: 0)

  fileprivate static func withLength(_ length: Int) -> CFRange {
    CFRange(location: 0, length: length)
  }

  fileprivate var nsRange: NSRange {
    NSRange(location: self.location, length: self.length)
  }
}

extension NSRange {
  fileprivate var endIndex: Int {
    location + length
  }
}

extension UTF16Char {
  fileprivate var isWhitespace: Bool {
    isIn(.whitespaces)
  }

  fileprivate var isWhitespaceOrNewline: Bool {
    isIn(.whitespacesAndNewlines)
  }

  fileprivate var isNewline: Bool {
    isIn(.newlines)
  }

  private func isIn(_ characterSet: CharacterSet) -> Bool {
    UnicodeScalar(self).map(characterSet.contains) ?? false
  }
}

public func +(lhs: NSAttributedString, rhs: NSAttributedString) -> NSAttributedString {
  let result = lhs.mutableCopy() as! NSMutableAttributedString
  result.append(rhs)
  return result
}

extension Array {
  fileprivate mutating func removeLastIfExists() {
    guard !isEmpty else {
      return
    }
    removeLast()
  }
}

extension NSAttributedString.VerticalPosition {
  fileprivate func verticalOffset(forHeight height: CGFloat, availableHeight: CGFloat) -> CGFloat {
    switch self {
    case .top: 0
    case .center: (availableHeight - height) / 2
    case .bottom: availableHeight - height
    }
  }
}

extension CGContext {
  fileprivate func performDrawing(shadedWith shadow: SystemShadow?, _ drawing: () -> Void) {
    guard let shadow, let color = shadow.cgColor else {
      drawing()
      return
    }
    // fix for UIKit compatibility
    let offsetToUse: CGSize =
      if #available(iOS 14, *) {
        shadow.shadowOffset
      } else {
        CGSize(
          width: shadow.shadowOffset.width,
          height: -shadow.shadowOffset.height
        )
      }
    setShadow(
      offset: offsetToUse,
      blur: shadow.shadowBlurRadius,
      color: color
    )
    drawing()
  }
}

extension Font {
  fileprivate var estimatedStrikethroughWidth: CGFloat {
    // count strikethrough line of 1 pt as normal for default 12-pt font size
    max(
      1 / PlatformDescription.screenScale(),
      (pointSize / 12).roundedToScreenScale
    )
  }

  fileprivate var underlineThickness: CGFloat {
    CTFontGetUnderlineThickness(self)
  }

  fileprivate var underlinePosition: CGFloat {
    CTFontGetUnderlinePosition(self)
  }
}

private let selectionColor = Color.colorWithHexCode(0xB3_D7_FE_7F)

private let selectionPointerColor = Color.colorWithHexCode(0x22_66_C5_FF)

private let pointerCircleSize = CGSize(width: 10, height: 10)
private let pointerShapeWidth: CGFloat = 2

extension NSAttributedString {
  public var isEmpty: Bool {
    length == 0
  }

  public var prettyDebugDescription: String {
    var result = "\"" + string + "\""
    enumerateAttributes(in: NSRange(location: 0, length: length)) { attributes, range, _ in
      if range.location != 0 || range.length != length {
        result += "\nStyle for \(range.location)-\(range.upperBound):"
      } else {
        result += "\nStyle:"
      }
      result += "\n" + String(describing: Typo(attributes: attributes)).indented()
    }

    return result
  }
}

extension NSAttributedString {
  public func with(typo: Typo) -> NSAttributedString {
    let result = NSMutableAttributedString(attributedString: self)

    enumerateAttributes(
      in: NSRange(location: 0, length: length),
      options: []
    ) { attributes, range, _ in
      let sourceTypo = Typo(attributes: attributes)
      let resultTypo = sourceTypo + typo
      result.addAttributes(resultTypo.attributes, range: range)
    }

    return result
  }

  public func scaled(by scale: CGFloat) -> NSAttributedString {
    guard scale != 1 else { return self }

    let result = NSMutableAttributedString(attributedString: self)

    enumerateAttributes(
      in: NSRange(location: 0, length: length),
      options: []
    ) { attributes, range, _ in
      let sourceTypo = Typo(attributes: attributes)
      let resultTypo = sourceTypo.scaled(by: scale)
      result.setAttributes(resultTypo.attributes, range: range)
    }

    return result
  }
}

extension CGPath {
  fileprivate static func with(rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    path.addRect(rect)
    return path
  }
}

extension [CloudBackgroundAttribute: [CGRect]] {
  fileprivate mutating func append(cloudBackgrounds: [CTLine.CloudBackground]) {
    for background in cloudBackgrounds {
      var array = self[background.info] ?? []
      array.append(background.rect)
      self[background.info] = array
    }
  }
}
