// Copyright 2026 Yandex LLC. All rights reserved.

import CoreText
import Foundation

extension NSAttributedString {
  func makeTruncatedLine(
    from range: NSRange,
    constrainedTo width: CGFloat,
    truncationToken: NSAttributedString?,
    truncationPolicy: TextTruncationPolicy
  ) -> CTLine? {
    guard range.length > 0 else {
      return nil
    }

    let token = makeTruncationToken(truncationToken, for: range)
    let rangeEndIndex = range.location + range.length
    let lastCodeUnit = string.utf16.prefix(rangeEndIndex).last!
    let lineTerminatesDueToNewlineSymbol = UnicodeScalar(lastCodeUnit)
      .map(CharacterSet.newlines.contains) ?? false
    let remainingContent = remainingTruncationContent(
      from: range,
      lineTerminatesDueToNewlineSymbol: lineTerminatesDueToNewlineSymbol
    )

    switch truncationPolicy {
    case .word:
      if lineBreakMode != .byClipping,
         remainingContent.truncationType == CTLineTruncationType.end,
         let wordTruncatedLine = remainingContent.makeWordTruncatedLine(
           constrainedTo: width,
           customTruncationToken: truncationToken
         ) {
        return wordTruncatedLine
      }
    case .grapheme:
      break
    }

    return remainingContent.makeGraphemeTruncatedLine(
      constrainedTo: width,
      truncationToken: token,
      lineTerminatesDueToNewlineSymbol: lineTerminatesDueToNewlineSymbol
    )
  }

  var lineBreakMode: LineBreakMode {
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

  private func makeTruncationToken(
    _ truncationToken: NSAttributedString?,
    for range: NSRange
  ) -> NSAttributedString {
    if lineBreakMode == .byClipping {
      return NSAttributedString()
    }
    if let truncationToken {
      return truncationToken.adjustingBorderRanges(
        by: length - range.location
      )
    }
    let allAttributes = attributes(
      at: range.location + range.length - 1,
      effectiveRange: nil
    )
    return NSAttributedString(string: ellipsis, attributes: allAttributes)
  }

  private func remainingTruncationContent(
    from range: NSRange,
    lineTerminatesDueToNewlineSymbol: Bool
  ) -> NSAttributedString {
    if lineTerminatesDueToNewlineSymbol {
      return attributedSubstring(from: range)
    }
    return attributedSubstring(
      from: NSRange(location: range.location, length: length - range.location)
    )
  }

  private func makeGraphemeTruncatedLine(
    constrainedTo width: CGFloat,
    truncationToken: NSAttributedString,
    lineTerminatesDueToNewlineSymbol: Bool
  ) -> CTLine? {
    let content = lineTerminatesDueToNewlineSymbol && truncationType == .end
      ? self + truncationToken
      : self
    let line = CTLineCreateWithAttributedString(content)
    let tokenLine = CTLineCreateWithAttributedString(truncationToken)
    guard let truncatedLine = CTLineCreateTruncatedLine(
      line,
      Double(width),
      content.truncationType,
      tokenLine
    ) else {
      return nil
    }

    let truncatedLineWidth = truncatedLine.typographicBounds.width
    let overrun = (truncatedLineWidth - width).roundedUpToScreenScale
    guard overrun.isApproximatelyGreaterThan(0) else {
      return truncatedLine
    }

    let roundedWidth = (width - overrun).roundedDownToScreenScale
    return CTLineCreateTruncatedLine(
      line,
      Double(roundedWidth),
      content.truncationType,
      tokenLine
    )
  }

  fileprivate var truncationType: CTLineTruncationType {
    switch lineBreakMode {
    case .byTruncatingHead:
      .start
    case .byTruncatingMiddle:
      .middle
    default:
      .end
    }
  }
}

extension NSAttributedString {
  func adjustingBorderRanges(by offset: Int) -> NSAttributedString {
    guard let mutableString = mutableCopy() as? NSMutableAttributedString else {
      return self
    }

    let fullRange = NSRange(location: 0, length: length)
    enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
      guard let border = attributes[BorderAttribute.Key] as? BorderAttribute else {
        return
      }
      var adjustedAttributes = attributes
      adjustedAttributes[BorderAttribute.Key] = BorderAttribute(
        color: border.color,
        width: border.width,
        cornerRadius: border.cornerRadius,
        range: CFRange(
          location: border.range.location + offset,
          length: border.range.length
        )
      )
      mutableString.setAttributes(adjustedAttributes, range: range)
    }
    return mutableString
  }
}

private let ellipsis = "\u{2026}"
