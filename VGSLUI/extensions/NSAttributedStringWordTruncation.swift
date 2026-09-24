// Copyright 2026 Yandex LLC. All rights reserved.

import CoreText
import Foundation

extension NSAttributedString {
  func makeWordTruncatedLine(
    constrainedTo width: CGFloat,
    customTruncationToken: NSAttributedString?
  ) -> CTLine? {
    guard length > 0 else {
      return nil
    }

    let typesetter = CTTypesetterCreateWithAttributedString(self)
    let clusterLength = CTTypesetterSuggestClusterBreak(typesetter, 0, Double(width))
    let lineBreakLength = CTTypesetterSuggestLineBreak(typesetter, 0, Double(width))
    let source = string as NSString
    let screenScale = PlatformDescription.screenScale()

    if length <= clusterLength {
      let fullContentLength = trimmedTruncationContentLength(
        upTo: length,
        source: source
      )
      if let fullContentLine = makeFittingWordTruncationLine(
        contentLength: fullContentLength,
        constrainedTo: width,
        customTruncationToken: customTruncationToken,
        screenScale: screenScale,
        source: source
      ) {
        return fullContentLine
      }
    }

    return makeFittingWordTruncationLine(
      typesetter: typesetter,
      initialContentLength: lineBreakLength,
      constrainedTo: width,
      customTruncationToken: customTruncationToken,
      screenScale: screenScale,
      source: source
    )
  }

  private func makeFittingWordTruncationLine(
    typesetter: CTTypesetter,
    initialContentLength: Int,
    constrainedTo width: CGFloat,
    customTruncationToken: NSAttributedString?,
    screenScale: CGFloat,
    source: NSString
  ) -> CTLine? {
    var previousContentLength = min(initialContentLength, length)
    var widthAdjustment: CGFloat = 0

    while previousContentLength > 0 {
      let retainedContentLength = trimmedTruncationContentLength(
        upTo: previousContentLength,
        source: source
      )
      guard retainedContentLength > 0 else {
        return nil
      }

      guard let candidate = makeWordTruncationCandidate(
        typesetter: typesetter,
        previousContentLength: previousContentLength,
        retainedContentLength: retainedContentLength,
        constrainedTo: width,
        widthAdjustment: widthAdjustment,
        customTruncationToken: customTruncationToken,
        screenScale: screenScale,
        source: source
      ) else {
        previousContentLength = source.rangeOfComposedCharacterSequence(
          at: retainedContentLength - 1
        ).location
        widthAdjustment = 0
        continue
      }

      if !candidate.overrun.isApproximatelyGreaterThan(0) {
        return candidate.line
      }

      previousContentLength = candidate.contentLength
      widthAdjustment += max(candidate.overrun, screenScale)
    }

    return nil
  }

  private func makeWordTruncationCandidate(
    typesetter: CTTypesetter,
    previousContentLength: Int,
    retainedContentLength: Int,
    constrainedTo width: CGFloat,
    widthAdjustment: CGFloat,
    customTruncationToken: NSAttributedString?,
    screenScale: CGFloat,
    source: NSString
  ) -> WordTruncationCandidate? {
    let token = wordTruncationToken(
      customTruncationToken,
      contentLength: retainedContentLength,
      renderedContentLength: retainedContentLength
    )
    let tokenWidth = CTLineCreateWithAttributedString(token).typographicBounds.width
    let contentWidth = width - tokenWidth - widthAdjustment + screenScale
    guard contentWidth > 0 else {
      return nil
    }
    guard let contentLength = nextWordBoundaryContentLength(
      typesetter,
      noLaterThan: previousContentLength,
      constrainedTo: contentWidth,
      screenScale: screenScale,
      source: source
    ) else {
      return nil
    }

    let line = makeWordTruncationLine(
      contentLength: contentLength,
      customTruncationToken: customTruncationToken
    )
    let overrun = calculateWordTruncationOverrun(
      for: line,
      constrainedTo: width,
      screenScale: screenScale
    )
    return WordTruncationCandidate(line: line, contentLength: contentLength, overrun: overrun)
  }

  private func nextWordBoundaryContentLength(
    _ typesetter: CTTypesetter,
    noLaterThan previousContentLength: Int,
    constrainedTo contentWidth: CGFloat,
    screenScale: CGFloat,
    source: NSString
  ) -> Int? {
    let lineBreakLength = CTTypesetterSuggestLineBreak(typesetter, 0, Double(contentWidth))
    guard lineBreakLength > 0,
          lineBreakLength <= previousContentLength else {
      return nil
    }

    let clusterBreakLength = CTTypesetterSuggestClusterBreak(typesetter, 0, Double(contentWidth))
    if lineBreakLength == clusterBreakLength,
       !isStableWordBoundary(
         typesetter,
         at: lineBreakLength,
         screenScale: screenScale,
         source: source
       ) {
      return nil
    }

    let contentLength = trimmedTruncationContentLength(upTo: lineBreakLength, source: source)
    guard contentLength > 0 else {
      return nil
    }
    return contentLength
  }

  private func isStableWordBoundary(
    _ typesetter: CTTypesetter,
    at boundaryLength: Int,
    screenScale: CGFloat,
    source: NSString
  ) -> Bool {
    guard boundaryLength < length else {
      return true
    }

    let nextClusterRange = source.rangeOfComposedCharacterSequence(at: boundaryLength)
    let probeContentLength = NSMaxRange(nextClusterRange)
    let probeLine = CTTypesetterCreateLine(
      typesetter,
      CFRange(location: 0, length: probeContentLength)
    )
    let probeWidth = probeLine.typographicBounds.width + screenScale
    let lineBreakLength = CTTypesetterSuggestLineBreak(typesetter, 0, Double(probeWidth))
    let clusterBreakLength = CTTypesetterSuggestClusterBreak(typesetter, 0, Double(probeWidth))
    return lineBreakLength == boundaryLength && clusterBreakLength > boundaryLength
  }

  private func makeFittingWordTruncationLine(
    contentLength: Int,
    constrainedTo width: CGFloat,
    customTruncationToken: NSAttributedString?,
    screenScale: CGFloat,
    source: NSString
  ) -> CTLine? {
    let trimmedContentLength = trimmedTruncationContentLength(
      upTo: contentLength,
      source: source
    )
    guard trimmedContentLength > 0 else {
      return nil
    }

    let line = makeWordTruncationLine(
      contentLength: trimmedContentLength,
      customTruncationToken: customTruncationToken
    )
    let overrun = calculateWordTruncationOverrun(
      for: line,
      constrainedTo: width,
      screenScale: screenScale
    )
    return overrun.isApproximatelyGreaterThan(0) ? nil : line
  }

  private func calculateWordTruncationOverrun(
    for line: CTLine,
    constrainedTo width: CGFloat,
    screenScale: CGFloat
  ) -> CGFloat {
    let overrun = line.typographicBounds.width - width
    return (overrun / screenScale).rounded(.up) * screenScale
  }

  private func makeWordTruncationLine(
    contentLength: Int,
    customTruncationToken: NSAttributedString?
  ) -> CTLine {
    let content = wordTruncationContent(length: contentLength)
    let token = wordTruncationToken(
      customTruncationToken,
      contentLength: contentLength,
      renderedContentLength: content.length
    )
    return CTLineCreateWithAttributedString(content + token)
  }

  private func wordTruncationContent(length contentLength: Int) -> NSAttributedString {
    let content = attributedSubstring(
      from: NSRange(location: 0, length: contentLength)
    ).mutableCopy() as! NSMutableAttributedString
    guard content.string.utf16.last == softHyphen else {
      return content
    }

    let hyphenAttributes = content.attributes(at: content.length - 1, effectiveRange: nil)
    content.append(NSAttributedString(string: visibleHyphen, attributes: hyphenAttributes))
    return content
  }

  private func wordTruncationToken(
    _ customTruncationToken: NSAttributedString?,
    contentLength: Int,
    renderedContentLength: Int
  ) -> NSAttributedString {
    if let customTruncationToken {
      return customTruncationToken.adjustingBorderRanges(by: renderedContentLength)
    }
    let attributes = attributes(at: contentLength - 1, effectiveRange: nil)
    return NSAttributedString(string: ellipsis, attributes: attributes)
  }

  private func trimmedTruncationContentLength(
    upTo endIndex: Int,
    source: NSString
  ) -> Int {
    var result = min(endIndex, length)

    while result > 0 {
      let trailingRange = source.rangeOfComposedCharacterSequence(at: result - 1)
      let trailingSymbol = source.substring(with: trailingRange)
      guard isTrimmableTruncationSymbol(trailingSymbol) else {
        break
      }
      result = trailingRange.location
    }

    return result
  }

  private func isTrimmableTruncationSymbol(_ symbol: String) -> Bool {
    symbol == zeroWidthSpace || symbol.unicodeScalars.allSatisfy {
      CharacterSet.whitespacesAndNewlines.contains($0)
    }
  }
}

private let ellipsis = "\u{2026}"
private let visibleHyphen = "-"
private let softHyphen: UTF16.CodeUnit = 0x00_AD
private let zeroWidthSpace = "\u{200B}"

private struct WordTruncationCandidate {
  let line: CTLine
  let contentLength: Int
  let overrun: CGFloat
}
