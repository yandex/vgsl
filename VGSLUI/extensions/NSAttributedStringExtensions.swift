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
    TextLayoutParams(
      string: self,
      maxTextSize: CGSize(width: width, height: .infinity),
      maxNumberOfLines: Int.max,
      truncationToken: nil
    ).size()
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
    truncationToken: NSAttributedString? = nil,
    truncationPolicy: TextTruncationPolicy = .grapheme
  ) -> CGFloat {
    let maxTextSize = CGSize(width: width, height: .infinity)
    if minNumberOfHiddenLines > 0 {
      let layout = computeLayout(
        for: self,
        maxTextSize: maxTextSize,
        maxNumberOfLines: Int.max,
        truncationPolicy: truncationPolicy
      )
      if layout.lines.count < maxNumberOfLines + minNumberOfHiddenLines {
        return layout.height
      }
    }

    let layoutParams = TextLayoutParams(
      string: self,
      maxTextSize: maxTextSize,
      maxNumberOfLines: maxNumberOfLines,
      truncationToken: truncationToken,
      truncationPolicy: truncationPolicy
    )

    return layoutParams.size().height
  }

  public func heightForWidth(
    _ width: CGFloat,
    maxTextHeight: CGFloat,
    truncationPolicy: TextTruncationPolicy = .grapheme
  ) -> CGFloat {
    TextLayoutParams(
      string: self,
      maxTextSize: CGSize(width: width, height: maxTextHeight),
      maxNumberOfLines: Int.max,
      truncationToken: nil,
      truncationPolicy: truncationPolicy
    ).size().height
  }

  public func sizeThatFits(
    _ size: CGSize,
    maxNumberOfLines: Int,
    truncationPolicy: TextTruncationPolicy = .grapheme
  ) -> CGSize {
    TextLayoutParams(
      string: self,
      maxTextSize: size,
      maxNumberOfLines: maxNumberOfLines,
      truncationToken: nil,
      truncationPolicy: truncationPolicy
    ).size()
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
  maxNumberOfLines: Int = .max,
  truncationPolicy: TextTruncationPolicy = .grapheme
) -> (size: CGSize, numberOfLines: Int) {
  let linesConstraint = (maxNumberOfLines > 0) ? maxNumberOfLines : .max
  let layout = computeLayout(
    for: string,
    maxTextSize: maxTextSize,
    maxNumberOfLines: linesConstraint,
    truncationPolicy: truncationPolicy
  )
  return (layout.size, layout.lines.count)
}

private let textLayoutCache = TextLayoutCache()

private extension TextLayoutParams {
  func size() -> CGSize {
    if isCacheable,
       let cachedSize = textLayoutCache.value(for: self) {
      return cachedSize
    }

    let size = computeLayout(
      for: string,
      maxTextSize: maxTextSize,
      maxNumberOfLines: maxNumberOfLines,
      truncationToken: truncationToken,
      truncationPolicy: truncationPolicy
    ).size

    if isCacheable {
      textLayoutCache.insert(size, for: self)
    }
    return size
  }
}

private func computeLayout(
  for string: NSAttributedString,
  maxTextSize: CGSize,
  maxNumberOfLines: Int,
  truncationToken: NSAttributedString? = nil,
  truncationPolicy: TextTruncationPolicy = .grapheme
) -> TextLayout {
  if string.containsSoftHyphens {
    let layout = string
      .makeCopyWithoutSoftHyphens()
      .makeTextLayout(
        in: maxTextSize,
        maxNumberOfLines: maxNumberOfLines,
        breakWords: false,
        truncationToken: truncationToken,
        truncationPolicy: truncationPolicy
      )
    if layout.entireTextFits(maxTextSize) {
      return layout
    }
  }
  return string.makeTextLayout(
    in: maxTextSize,
    maxNumberOfLines: maxNumberOfLines,
    breakWords: true,
    truncationToken: truncationToken,
    truncationPolicy: truncationPolicy
  )
}

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
    truncationToken: NSAttributedString? = nil,
    truncationPolicy: TextTruncationPolicy = .grapheme
  ) -> TextLayout {
    let typesetter = CTTypesetterCreateWithAttributedString(self)
    var progress = TextLayoutProgress()
    while progress.offset < length, progress.lines.count < maxNumberOfLines {
      let paragraphAttributes = paragraphAttributes(for: &progress)
      let availableWidth = size.width - paragraphAttributes.headIndent
      let lineLength = breakWords ?
        typesetter.lineLength(from: progress.offset, constrainedTo: availableWidth) :
        typesetter.lineLengthByWordBoundary(
          for: string,
          from: progress.offset,
          constrainedTo: availableWidth
        )
      guard lineLength > 0 else {
        break
      }
      let suggestedRange = CFRange(location: progress.offset, length: lineLength)
      let layout = suggestedLineLayout(
        typesetter: typesetter,
        range: suggestedRange,
        availableWidth: availableWidth,
        paragraphAttributes: paragraphAttributes,
        breakWords: breakWords
      )
      if !appendOrTruncateLine(
        layout,
        suggestedRange: suggestedRange.nsRange,
        availableWidth: availableWidth,
        size: size,
        maxNumberOfLines: maxNumberOfLines,
        truncationToken: truncationToken,
        truncationPolicy: truncationPolicy,
        progress: &progress
      ) {
        break
      }
    }

    appendTrailingNewline(
      typesetter: typesetter, size: size, maxNumberOfLines: maxNumberOfLines, progress: &progress
    )
    return TextLayout(lines: progress.lines, sourceLength: length)
  }

  private func paragraphAttributes(for progress: inout TextLayoutProgress) -> ParagraphAttributes {
    if progress.isNewline {
      let result = ParagraphAttributes(
        headIndent: firstLineHeadIndent(at: progress.offset),
        spacingBefore: paragraphSpacingBefore(at: progress.offset) + progress.paragraphSpacing
      )
      progress.headIndent = headIndent(at: progress.offset)
      progress.paragraphSpacing = paragraphSpacing(at: progress.offset)
      return result
    }
    return ParagraphAttributes(headIndent: progress.headIndent, spacingBefore: 0)
  }

  private func suggestedLineLayout(
    typesetter: CTTypesetter,
    range: CFRange,
    availableWidth: CGFloat,
    paragraphAttributes: ParagraphAttributes,
    breakWords: Bool
  ) -> LineLayout {
    guard subrangeEndsWithSoftHyphen(range.nsRange) else {
      return layoutLine(
        typesetter: typesetter,
        range: range,
        paragraphAttributes: paragraphAttributes
      )
    }
    assert(breakWords)
    return layoutHyphenatedLine(
      typesetter: typesetter,
      range: range,
      availableWidth: availableWidth,
      paragraphAttributes: paragraphAttributes
    )
  }

  private func appendOrTruncateLine(
    _ layout: LineLayout,
    suggestedRange: NSRange,
    availableWidth: CGFloat,
    size: CGSize,
    maxNumberOfLines: Int,
    truncationToken: NSAttributedString?,
    truncationPolicy: TextTruncationPolicy,
    progress: inout TextLayoutProgress
  ) -> Bool {
    progress.height += layout.bounds.height + layout.paragraphAttributes.spacingBefore
    progress.isNewline = string.utf16.prefix(layout.range.endIndex).last?.isNewline ?? false
    let fitsByHeight = progress.height.isApproximatelyLessOrEqualThan(size.height)
    let nextLineFits = (progress.lines.count < maxNumberOfLines - 1 && !singleLineBreakMode) ||
      suggestedRange.endIndex == length
    if fitsByHeight, nextLineFits {
      progress.lines.append(layout)
      progress.offset += layout.range.length
      return true
    }

    let previousLine = progress.lines.last
    let truncationRange = nextLineFits
      ? previousLine?.range ?? NSRange(location: 0, length: length)
      : suggestedRange
    let paragraphAttributes = nextLineFits
      ? previousLine?.paragraphAttributes ?? ParagraphAttributes(headIndent: 0, spacingBefore: 0)
      : layout.paragraphAttributes
    appendTruncatedLine(
      from: truncationRange,
      suggestedRange: suggestedRange,
      constrainedTo: nextLineFits ? size.width - paragraphAttributes.headIndent : availableWidth,
      paragraphAttributes: paragraphAttributes,
      replacingPreviousLine: nextLineFits,
      truncationToken: truncationToken,
      truncationPolicy: truncationPolicy,
      progress: &progress
    )
    return false
  }

  private func appendTruncatedLine(
    from range: NSRange,
    suggestedRange: NSRange,
    constrainedTo width: CGFloat,
    paragraphAttributes: ParagraphAttributes,
    replacingPreviousLine: Bool,
    truncationToken: NSAttributedString?,
    truncationPolicy: TextTruncationPolicy,
    progress: inout TextLayoutProgress
  ) {
    guard let lastLine = makeTruncatedLine(
      from: range,
      constrainedTo: width,
      truncationToken: truncationToken,
      truncationPolicy: truncationPolicy
    ) else {
      return
    }
    if replacingPreviousLine {
      progress.lines.removeLastIfExists()
    }
    progress.lines.append((
      lastLine,
      lastLine.typographicBounds,
      suggestedRange,
      true,
      paragraphAttributes
    ))
  }

  private func appendTrailingNewline(
    typesetter: CTTypesetter,
    size: CGSize,
    maxNumberOfLines: Int,
    progress: inout TextLayoutProgress
  ) {
    guard string.last?.isNewline == true else {
      return
    }
    let layout = layoutLine(
      typesetter: typesetter,
      range: CFRange(location: progress.offset - 1, length: 1),
      paragraphAttributes: ParagraphAttributes(
        headIndent: 0,
        spacingBefore: progress.paragraphSpacing
      )
    )
    progress.height += layout.bounds.height + progress.paragraphSpacing
    let fitsByHeight = progress.height.isApproximatelyLessOrEqualThan(size.height)
    let nextLineFits = progress.lines.count < maxNumberOfLines - 1 && !singleLineBreakMode
    if fitsByHeight, nextLineFits {
      progress.lines.append(layout)
    }
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

private struct TextLayoutProgress {
  var offset = 0
  var lines = [LineLayout]()
  var height: CGFloat = 0
  var isNewline = true
  var headIndent: CGFloat = 0
  var paragraphSpacing: CGFloat = 0
}
