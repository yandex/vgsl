// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

// TODO(dmt021): @_spi(Extensions)
extension String {
  public func range(from nsRange: NSRange) -> Range<Index>? {
    let validPositions = (indices + [endIndex]).map { $0.utf16Offset(in: self) }

    guard let from = (
      validPositions.firstIndex(of: nsRange.lowerBound)
        ?? validPositions.firstIndex(where: { $0 > nsRange.lowerBound }).map { $0 - 1 }
    ),
      let to = (
        validPositions.firstIndex(of: nsRange.upperBound)
          ?? validPositions.reversed().firstIndex(where: { $0 < nsRange.upperBound })
          .map { validPositions.count - $0 }
      )
    else { return nil }

    guard let fromIndex = index(startIndex, offsetBy: from, limitedBy: endIndex),
          let toIndex = index(startIndex, offsetBy: to, limitedBy: endIndex) else { return nil }

    return fromIndex..<toIndex
  }

  public func matchesRegex(_ regex: NSRegularExpression) -> Bool {
    let range = stringRangeAsNSRange(wholeStringRange, inString: self)
    let result = regex.firstMatch(in: self, options: [], range: range)
    return result != nil
  }

  public func matchesPattern(_ pattern: String) throws -> Bool {
    let regex = try regexForPattern(pattern)
    return matchesRegex(regex)
  }

  // MOBYANDEXIOS-772: some locales dont contain info about how words should be hyphenated,
  // so we can use other locales to reach this point; for example, Ukrainian may be
  // hyphenated using Russian rules: seems good
  private func hyphenationLocaleForLocale(_ locale: Locale) -> Locale? {
    let hyphenationLocaleMap = [
      "uk": "ru_RU",
      "be": "ru_RU",
    ]

    var fallbackLocale = locale

    for (localeID, hyphenationLocaleID) in hyphenationLocaleMap {
      if locale.identifier.hasPrefix("\(localeID)_") {
        fallbackLocale = Locale(identifier: hyphenationLocaleID)
        break
      }

      if locale.identifier == localeID {
        fallbackLocale = Locale(identifier: hyphenationLocaleID)
        break
      }
    }

    if CFStringIsHyphenationAvailableForLocale(fallbackLocale as CFLocale) {
      return fallbackLocale
    } else {
      return nil
    }
  }

  // MOBYANDEXIOS-772: as of UILabel does not correctly hyphenate words,
  // this method inserts special symbols into string: soft hyphens.
  // They work just like point of stops, without being actually rendered.
  public func hyphenatedStringForLocale(_ locale: Locale) -> String {
    guard let hyphenationLocale = hyphenationLocaleForLocale(locale) else {
      return self
    }

    let range = CFRangeMake(0, utf16.count)
    let hyphenIndices: [CFIndex] = utf16.indices.compactMap {
      let characterIndex = utf16.distance(from: utf16.startIndex, to: $0)
      let hyphenIndex = CFStringGetHyphenationLocationBeforeIndex(
        self as CFString,
        characterIndex,
        range,
        0,
        hyphenationLocale as CFLocale,
        nil
      )
      return (hyphenIndex == kCFNotFound ? nil : hyphenIndex)
    }

    let result = NSMutableString(string: self)
    Set(hyphenIndices).sorted(by: >).forEach {
      result.insert(softHyphenCharacter, at: $0)
    }

    return String(result)
  }

  public var hyphenatedStringForCyrillicAndLatin: String {
    hyphenatedStringForLocale(Locale(identifier: "ru_RU"))
      .hyphenatedStringForLocale(Locale(identifier: "en_US"))
  }

  public var utf8Data: Data? {
    data(using: String.Encoding.utf8)
  }
}

public func stringRangeAsNSRange(_ range: Range<String.Index>, inString string: String) -> NSRange {
  NSRange(range, in: string)
}

private let regexForPattern = memoize { (pattern: String) throws -> NSRegularExpression in
  try NSRegularExpression(pattern: pattern, options: [])
}

private let softHyphenCharacter = "\u{00AD}"
