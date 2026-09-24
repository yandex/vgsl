// Copyright 2026 Yandex LLC. All rights reserved.

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
  public func draw(
    inContext context: CGContext,
    verticalPosition: VerticalPosition = .center,
    rect: CGRect,
    textInsets: EdgeInsets = .zero,
    truncationPolicy: TextTruncationPolicy = .grapheme
  ) {
    _ = drawAndGetLayout(
      inContext: context,
      verticalPosition: verticalPosition,
      rect: rect,
      textInsets: textInsets,
      truncationPolicy: truncationPolicy,
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
    truncationToken: NSAttributedString? = nil,
    truncationPolicy: TextTruncationPolicy = .grapheme,
    glyphRenderer: GlyphRenderer? = nil
  ) -> AttributedStringLayout<Void> {
    drawAndGetLayout(
      inContext: context,
      verticalPosition: verticalPosition,
      rect: rect,
      textInsets: textInsets,
      truncationToken: truncationToken,
      truncationPolicy: truncationPolicy,
      actionKey: nil,
      backgroundKey: nil,
      borderKey: nil,
      selectedRange: nil,
      glyphRenderer: glyphRenderer
    )
  }

  public func drawAndGetLayout<ActionType>(
    inContext context: CGContext?,
    verticalPosition: VerticalPosition = .center,
    rect: CGRect,
    textInsets: EdgeInsets = .zero,
    truncationToken: NSAttributedString? = nil,
    truncationPolicy: TextTruncationPolicy = .grapheme,
    actionKey: NSAttributedString.Key? = nil,
    backgroundKey: NSAttributedString.Key? = nil,
    borderKey: NSAttributedString.Key? = nil,
    rangeVerticalAlignmentKey: NSAttributedString.Key? = nil,
    selectedRange _: Range<Int>? = nil,
    glyphRenderer: GlyphRenderer? = nil
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
    let drawingString = stringForDrawing(
      in: rect.size,
      truncationToken: truncationToken,
      truncationPolicy: truncationPolicy
    )
    return drawingString.drawAndGetLayoutImpl(
      inContext: context,
      verticalPosition: verticalPosition,
      rect: transformedRect,
      textInsets: textInsets,
      truncationToken: truncationToken,
      truncationPolicy: truncationPolicy,
      actionKey: actionKey,
      backgroundKey: backgroundKey,
      borderKey: borderKey,
      rangeVerticalAlignmentKey: rangeVerticalAlignmentKey,
      glyphRenderer: glyphRenderer
    )
  }

  private func stringForDrawing(
    in size: CGSize,
    truncationToken: NSAttributedString?,
    truncationPolicy: TextTruncationPolicy
  ) -> NSAttributedString {
    guard containsSoftHyphens else {
      return self
    }

    let copy = makeCopyWithoutSoftHyphens()
    let layout = copy.makeTextLayout(
      in: size,
      breakWords: false,
      truncationToken: truncationToken,
      truncationPolicy: truncationPolicy
    )
    return layout.entireTextFits(size) ? copy : self
  }

  private func drawAndGetLayoutImpl<ActionType>(
    inContext context: CGContext?,
    verticalPosition: VerticalPosition,
    rect: CGRect,
    textInsets: EdgeInsets,
    truncationToken: NSAttributedString?,
    truncationPolicy: TextTruncationPolicy,
    actionKey: NSAttributedString.Key?,
    backgroundKey: NSAttributedString.Key?,
    borderKey: NSAttributedString.Key?,
    rangeVerticalAlignmentKey: NSAttributedString.Key?,
    glyphRenderer: GlyphRenderer?
  ) -> AttributedStringLayout<ActionType> {
    let layout = makeTextLayout(
      in: rect.size.inset(by: textInsets),
      breakWords: true,
      truncationToken: truncationToken,
      truncationPolicy: truncationPolicy
    )
    assertLayoutFits(layout, in: rect)
    let maybeNegativeOffset = verticalPosition.verticalOffset(
      forHeight: layout.height,
      availableHeight: rect.height
    )
    let verticalOffset = max(maybeNegativeOffset, 0)

    if let context {
      drawClouds(
        context: context,
        verticalPosition: verticalPosition,
        rect: rect,
        textInsets: textInsets,
        layout: layout
      )
    }

    return drawLayoutLines(
      layout,
      in: context,
      rect: rect,
      textInsets: textInsets,
      initialOriginY: rect.height - verticalOffset,
      actionKey: actionKey,
      backgroundKey: backgroundKey,
      borderKey: borderKey,
      rangeVerticalAlignmentKey: rangeVerticalAlignmentKey,
      glyphRenderer: glyphRenderer
    )
  }

  private func assertLayoutFits(_ layout: TextLayout, in rect: CGRect) {
    assert(
      // accuracy is needed because sometimes text is a bit higher,
      // but it's not noticeable in rendering and doesn't affect vertical position
      layout.lines.count == 1 ||
        rect.height.isApproximatelyGreaterOrEqualThan(layout.height, withAccuracy: 0.5),
      "Layout constrained to some height should not exceed it"
    )
  }

  private func drawLayoutLines<ActionType>(
    _ layout: TextLayout,
    in context: CGContext?,
    rect: CGRect,
    textInsets: EdgeInsets,
    initialOriginY: CGFloat,
    actionKey: NSAttributedString.Key?,
    backgroundKey: NSAttributedString.Key?,
    borderKey: NSAttributedString.Key?,
    rangeVerticalAlignmentKey: NSAttributedString.Key?,
    glyphRenderer: GlyphRenderer?
  ) -> AttributedStringLayout<ActionType> {
    var runsLayout = [AttributedStringLayout<ActionType>.Run]()
    let firstLineOriginX = layout.lines.first.map { firstLine in
      horizontalOffset(
        lineWidth: firstLine.bounds.width,
        maxWidth: rect.width,
        headIndent: firstLine.paragraphAttributes.headIndent
      ) + rect.origin.x
    }
    var lineOriginY = initialOriginY
    var lines: [AttributedStringLineLayout] = []
    for lineLayout in layout.lines {
      guard let renderedLine: RenderedTextLine<ActionType> = renderLine(
        lineLayout,
        in: context,
        rect: rect,
        textInsets: textInsets,
        previousOriginY: lineOriginY,
        actionKey: actionKey,
        backgroundKey: backgroundKey,
        borderKey: borderKey,
        rangeVerticalAlignmentKey: rangeVerticalAlignmentKey,
        glyphRenderer: glyphRenderer
      ) else {
        break
      }
      runsLayout += renderedLine.runs
      lines.append(renderedLine.layout)
      lineOriginY = renderedLine.nextOriginY
    }

    return AttributedStringLayout(
      firstLineOriginX: firstLineOriginX,
      runsWithAction: runsLayout,
      lines: lines
    )
  }

  private func renderLine<ActionType>(
    _ lineLayout: LineLayout,
    in context: CGContext?,
    rect: CGRect,
    textInsets: EdgeInsets,
    previousOriginY: CGFloat,
    actionKey: NSAttributedString.Key?,
    backgroundKey: NSAttributedString.Key?,
    borderKey: NSAttributedString.Key?,
    rangeVerticalAlignmentKey: NSAttributedString.Key?,
    glyphRenderer: GlyphRenderer?
  ) -> RenderedTextLine<ActionType>? {
    guard let context else {
      return nil
    }
    let originX = horizontalOffset(
      lineWidth: lineLayout.bounds.width,
      maxWidth: rect.width,
      headIndent: lineLayout.paragraphAttributes.headIndent
    )
    let originY = previousOriginY - lineLayout.paragraphAttributes.spacingBefore
    let textPosition = CGPoint(
      x: rect.origin.x + originX + textInsets.left,
      y: rect.origin.y + originY - lineLayout.bounds.ascent - textInsets.top
    )
    let runs: [AttributedStringLayout<ActionType>.Run] = lineLayout.line.draw(
      at: textPosition,
      in: context,
      layoutY: rect.maxY - originY,
      actionKey: actionKey,
      backgroundKey: backgroundKey,
      rangeVerticalAlignmentKey: rangeVerticalAlignmentKey,
      borderKey: borderKey,
      textOriginX: originX,
      glyphRenderer: glyphRenderer
    )
    return RenderedTextLine(
      runs: runs,
      layout: AttributedStringLineLayout(
        line: lineLayout.line,
        verticalOffset: originY,
        horizontalOffset: originX,
        range: lineLayout.range,
        isTruncated: lineLayout.isTruncated
      ),
      originX: originX,
      nextOriginY: originY - lineLayout.bounds.height
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
        let newPaddings: EdgeInsets =
          if index == 0 {
            .init(
              top: 0,
              left: paddings.left,
              bottom: paddings.bottom,
              right: paddings.right
            )
          } else if index == cloudsRects.count - 1 {
            .init(
              top: paddings.top,
              left: paddings.left,
              bottom: 0,
              right: paddings.right
            )
          } else {
            .init(top: 0, left: paddings.left, bottom: 0, right: paddings.right)
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

  private var textAlignment: TextAlignment {
    let paragraphStyle = attribute(
      .paragraphStyle,
      at: 0,
      effectiveRange: nil
    ) as? NSParagraphStyle
    return paragraphStyle?.alignment ?? .natural
  }

}

private struct RenderedTextLine<ActionType> {
  let runs: [AttributedStringLayout<ActionType>.Run]
  let layout: AttributedStringLineLayout
  let originX: CGFloat
  let nextOriginY: CGFloat
}
