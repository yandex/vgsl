// Copyright 2023 Yandex LLC. All rights reserved.

// TODO(dmt021): @_spi(Extensions)
extension String {
  public enum PaddingSide {
    case left
    case right
  }

  public func pad(_ side: PaddingSide, with character: Character, upTo upToCount: Int) -> String {
    let padCount = upToCount - count
    guard padCount > 0 else { return self }

    // swiftlint:disable:next no_direct_use_of_repeating_count_initializer
    let pad = String(repeating: character, count: padCount)
    switch side {
    case .left:
      return pad + self
    case .right:
      return self + pad
    }
  }

  public init(_ staticString: StaticString) {
    let result = staticString.withUTF8Buffer {
      String(decoding: $0, as: UTF8.self)
    }
    self.init(result)
  }

  public func wordRangesForCaretPosition(_ caretPos: Index) ->
    (wordRange: Range<Index>, enclosingRange: Range<Index>)? {
    var wordRange: Range<Index>?
    var enclosingRange: Range<Index>?
    enumerateSubstrings(
      in: wholeStringRange,
      options: .byWords
    ) { _, _wordRange, _enclosingRange, stop -> Void in
      let caretAtTheBeginningOfWord = _wordRange.lowerBound == caretPos
      let caretInsideWord = _wordRange.contains(caretPos)
      let caretAtTheEndOfWord = _wordRange.upperBound == caretPos
      if !caretAtTheBeginningOfWord, caretInsideWord || caretAtTheEndOfWord {
        wordRange = _wordRange
        enclosingRange = _enclosingRange
        stop = true
      }
    }

    if let wordRange = wordRange, let enclosingRange = enclosingRange {
      return (wordRange, enclosingRange)
    } else {
      return nil
    }
  }

  public func allWordRanges() -> [Range<Index>] {
    var wordRanges: [Range<Index>] = []
    enumerateSubstrings(in: wholeStringRange, options: .byWords) { _, range, _, _ -> Void in
      wordRanges.append(range)
    }
    return wordRanges
  }

  public func allWords() -> [String] {
    allWordRanges().map { String(self[$0]) }
  }

  public var wholeStringRange: Range<Index> {
    startIndex..<endIndex
  }

  public var stringEndRange: Range<Index> {
    endIndex..<endIndex
  }

  public func rangeOfCommonWordPrefixWithString(_ str: String) -> CountableRange<Int> {
    var idx = 0
    let words = allWords()
    var strIdx = 0
    let strWords = str.allWords()

    while idx != words.count, strIdx != strWords.count, words[idx] == strWords[strIdx] {
      idx += 1
      strIdx += 1
    }

    return 0..<idx
  }

  public func rangeOfCommonWordSuffixWithString(_ str: String) -> CountableRange<Int>? {
    let words = allWords()
    let strWords = str.allWords()

    let pairsCount = min(words.count, strWords.count)
    let firstNonEqualWordIdx = zip(words.reversed(), strWords.reversed())
      .enumerated()
      .first(where: { $0.element.0 != $0.element.1 })?.offset ?? pairsCount

    let result = (words.count - firstNonEqualWordIdx)..<words.count
    return result.isEmpty ? nil : result
  }

  public func differsOnlyInWhitespaceFrom(_ other: String) -> Bool {
    let s1WithoutWhitespace = self.replacingOccurrences(of: " ", with: "")
    let s2WithoutWhitespace = other.replacingOccurrences(of: " ", with: "")
    return String(s1WithoutWhitespace) == String(s2WithoutWhitespace)
  }

  public func substringToString(_ string: String) -> String {
    components(separatedBy: string).first ?? ""
  }

  public var trimmed: String {
    trimmingCharacters(in: .whitespaces)
  }

  /// Removes all whitespace at the beginning and at the end of the string, and
  /// ensures there is only one whitespace character between words.
  public var normalizedForWhitespaces: String {
    let array = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    return array.joined(separator: " ")
  }

  public var normalized: String {
    normalizedForWhitespaces.lowercased()
  }

  public func replacingCharactersInRange(
    _ range: Range<Index>,
    withString string: String,
    lengthLimit: Int = .max
  ) -> (result: String, insertionOffset: Index) {
    let indices = startIndex..<endIndex
    precondition(
      indices.contains(range.lowerBound) || startIndex == range
        .lowerBound || endIndex == range.lowerBound
    )
    precondition(indices.contains(range.upperBound) || endIndex == range.upperBound)
    let maxInsertionLength = max(
      0,
      lengthLimit - count + distance(from: range.lowerBound, to: range.upperBound)
    )
    let stringToInsert = String(string.prefix(maxInsertionLength))
    let result = replacingCharacters(in: range, with: stringToInsert)

    let insertionDistance = distance(from: startIndex, to: range.lowerBound) + stringToInsert.count
    let insertionOffset = result.index(
      result.startIndex,
      offsetBy: insertionDistance,
      limitedBy: result.endIndex
    ) ?? result.endIndex
    return (String(result.prefix(lengthLimit)), insertionOffset)
  }

  public var sanitizedPath: String {
    split(separator: "/").joined(separator: "/")
  }

  public var base64Encoded: String {
    data(using: .utf8)?.base64EncodedString() ?? ""
  }

  public func formatted(_ args: CVarArg...) -> Self {
    String(format: self, args)
  }
}
