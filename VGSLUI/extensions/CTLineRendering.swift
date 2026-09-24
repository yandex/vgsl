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

extension CTLine {
  internal var runs: [CTRun] {
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

  var typographicBounds: TypographicBounds {
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
    if maxHeight < .greatestFiniteMagnitude, currentLineHeight > maxHeight {
      adjustedLineHeight = maxHeight
    } else if minHeight > 0, currentLineHeight < minHeight {
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

  internal func draw<ActionType>(
    at position: CGPoint,
    in context: CGContext,
    layoutY: CGFloat,
    actionKey: NSAttributedString.Key?,
    backgroundKey: NSAttributedString.Key?,
    rangeVerticalAlignmentKey: NSAttributedString.Key?,
    borderKey: NSAttributedString.Key?,
    textOriginX: CGFloat,
    glyphRenderer: GlyphRenderer?
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

      drawRun(
        run,
        at: position,
        runPosition: runPosition,
        textOriginX: textOriginX,
        in: context,
        glyphRenderer: glyphRenderer
      )

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

  private func drawRun(
    _ run: CTRun,
    at position: CGPoint,
    runPosition: CGPoint,
    textOriginX: CGFloat,
    in context: CGContext,
    glyphRenderer: GlyphRenderer?
  ) {
    context.textPosition = position
    let handled = glyphRenderer.map { renderer in
      context.withPreservedTextState {
        renderer.drawGlyphs(of: run, at: position, in: context)
      }
    } ?? false

    if handled {
      drawShadowForHandledGlyphs(run, at: position, in: context)
      drawAllDecorations(
        for: run,
        at: runPosition,
        textOriginX: textOriginX,
        in: context
      )
    } else {
      context.inSeparateGState {
        context.performDrawing(shadedWith: run.shadow) {
          CTRunDraw(run, context, .infinite)
          drawDecorationsSkippedByCoreText(
            for: run,
            at: runPosition,
            textOriginX: textOriginX,
            in: context
          )
        }
      }
    }
  }

  private func drawShadowForHandledGlyphs(
    _ run: CTRun,
    at position: CGPoint,
    in context: CGContext
  ) {
    guard run.shadow != nil else {
      return
    }
    context.inSeparateGState {
      run.configureTextDrawing(in: context)
      context.beginTransparencyLayer(auxiliaryInfo: nil)
      context.inSeparateGState {
        context.performDrawing(shadedWith: run.shadow) {
          run.drawGlyphs(at: position, in: context)
        }
      }
      context.setBlendMode(.destinationOut)
      run.drawGlyphs(at: position, in: context)
      context.endTransparencyLayer()
    }
  }

  private func drawAllDecorations(
    for run: CTRun,
    at position: CGPoint,
    textOriginX: CGFloat,
    in context: CGContext
  ) {
    context.inSeparateGState {
      context.performDrawing(shadedWith: run.shadow) {
        if run.isUnderline {
          drawUnderline(for: run, at: position, with: textOriginX, in: context)
        }
        if run.isSingleStrikethrough {
          drawStrikethrough(for: run, at: position, in: context)
        }
      }
    }
  }

  private func drawDecorationsSkippedByCoreText(
    for run: CTRun,
    at position: CGPoint,
    textOriginX: CGFloat,
    in context: CGContext
  ) {
    if run.isUnderline, #available(iOS 18, tvOS 18, macOS 13, *) {
      drawUnderline(for: run, at: position, with: textOriginX, in: context)
    }
    if run.isSingleStrikethrough {
      if #available(iOS 18, tvOS 18, *) {
        drawStrikethrough(for: run, at: position, in: context)
      } else if #available(iOS 15, tvOS 15, *) {
        // Supported by CoreText directly
      } else {
        drawStrikethrough(for: run, at: position, in: context)
      }
    }
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

  private func drawUnderline(
    for run: CTRun,
    at position: CGPoint,
    with lineXCorrection: CGFloat,
    in context: CGContext
  ) {
    context.saveGState()
    context.setStrokeColor(run.color)
    context.setLineWidth(run.font.underlineThickness)

    var underlinePath = run.strikethroughLine(
      forTextPosition: position,
      offset: run.font.underlinePosition - run.font.underlineThickness
    )

    if #available(iOS 16, tvOS 16, macOS 13, *) {
      let glyphStartPosition = CGPoint(
        x: lineXCorrection,
        y: position.y
      )
      for glyphPath in run.glyphPaths(runPosition: glyphStartPosition) {
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
    }
    context.addPath(underlinePath)
    context.strokePath()
    context.restoreGState()
  }

  internal func calculateCloudsLayout(
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

  internal var typographicBounds: TypographicBounds {
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    let width = CGFloat(CTRunGetTypographicBounds(self, .infinite, &ascent, &descent, nil))
    return TypographicBounds(ascent: ascent, descent: descent, width: width)
  }

  internal var baselineOffset: CGFloat {
    var offset: CGFloat? = attribute(withName: .baselineOffset)
    if #available(iOS 11, tvOS 11, OSX 10.13, *) {
      offset = offset ?? attribute(withName: kCTBaselineOffsetAttributeName)
    }
    return offset ?? 0
  }

  internal var paragraphStyle: NSParagraphStyle? {
    let style: NSParagraphStyle? = attribute(withName: .paragraphStyle)
      ?? attribute(withName: kCTParagraphStyleAttributeName)
    return style
  }

  internal var isSingleStrikethrough: Bool {
    let underlineStyle: Int? = attribute(withName: .strikethroughStyle)
    return underlineStyle == UnderlineStyle.single.rawValue
  }

  internal var isUnderline: Bool {
    let underlineStyle: Int? = attribute(withName: .underlineStyle)
    return underlineStyle == UnderlineStyle.single.rawValue
  }

  internal var color: CGColor {
    let color: Any? = attribute(withName: .foregroundColor) ??
      attribute(withName: kCTForegroundColorAttributeName)
    if let systemColor = color as? SystemColor {
      return systemColor.cgColor
    } else if let cgColor = safeCFCast(color as CFTypeRef) as CGColor? {
      return cgColor
    }

    return Color.black.cgColor
  }

  internal func configureTextDrawing(in context: CGContext) {
    let strokeWidth: CGFloat? = attribute(withName: .strokeWidth) ??
      attribute(withName: kCTStrokeWidthAttributeName)
    guard let strokeWidth, strokeWidth != 0 else {
      context.setFillColor(color)
      context.setTextDrawingMode(.fill)
      return
    }

    let strokeColor = resolvedColor(
      attribute(withName: .strokeColor) ?? attribute(withName: kCTStrokeColorAttributeName)
    ) ?? color
    context.setLineWidth(abs(strokeWidth) * font.pointSize / 100)
    context.setStrokeColor(strokeColor)
    if strokeWidth > 0 {
      context.setTextDrawingMode(.stroke)
    } else {
      context.setFillColor(color)
      context.setTextDrawingMode(.fillStroke)
    }
  }

  private func resolvedColor(_ value: Any?) -> CGColor? {
    if let systemColor = value as? SystemColor {
      return systemColor.cgColor
    }
    if let value {
      return safeCFCast(value as CFTypeRef) as CGColor?
    }
    return nil
  }

  var font: Font {
    let font: Font? = attribute(withName: .font) ?? attribute(withName: kCTFontAttributeName)
    return font ?? Font.systemFontWithDefaultSize()
  }

  internal var attachment: TextAttachment? {
    let attachment: TextAttachment? = attribute(withName: .attachment)
    return attachment
  }

  internal var origin: CGPoint {
    var origins = [CGPoint.zero]
    CTRunGetPositions(self, CFRangeMake(0, 1), &origins)
    return origins.first!
  }

  internal func strikethroughLine(
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

  internal var shadow: SystemShadow? {
    attribute(withName: .shadow)
  }

  internal func action<ActionType>(for key: NSAttributedString.Key) -> ActionType? {
    attribute(withName: key) as ActionType?
  }

  internal func background(for key: NSAttributedString.Key) -> BackgroundAttribute? {
    attribute(withName: key) as BackgroundAttribute?
  }

  internal func cloudBackground(for key: NSAttributedString.Key) -> CloudBackgroundAttribute? {
    attribute(withName: key) as CloudBackgroundAttribute?
  }

  internal func border(for key: NSAttributedString.Key) -> BorderAttribute? {
    attribute(withName: key) as BorderAttribute?
  }

  internal func rangeVerticalAlignment(
    for key: NSAttributedString
      .Key
  ) -> RangeVerticalAlignmentAttribute? {
    attribute(withName: key) as RangeVerticalAlignmentAttribute?
  }

  internal func glyphPaths(runPosition: CGPoint) -> [CGPath] {
    let glyphCount = CTRunGetGlyphCount(self)
    var glyphs: [CGGlyph] = Array(repeating: CGGlyph(), count: glyphCount)
    CTRunGetGlyphs(self, .infinite, &glyphs)

    var positions: [CGPoint] = Array(repeating: .zero, count: glyphCount)
    CTRunGetPositions(self, .infinite, &positions)

    return zip(glyphs, positions).compactMap { glyph, position in
      var transform = CGAffineTransform.identity.translatedBy(
        x: runPosition.x + position.x,
        y: runPosition.y + position.y
      )
      return CTFontCreatePathForGlyph(font, glyph, &transform)
    }
  }
}
