// Copyright 2023 Yandex LLC. All rights reserved.

// TODO(dmt021): @_spi(Extensions)
extension String {
  /// This method is really slow and should be used only to format debugDescription.
  public func indented(level: Int = 1) -> String {
    // swiftlint:disable no_direct_use_of_repeating_count_initializer
    let indent = String(repeating: " ", count: max(level * 2, 0))
    // swiftlint:disable no_direct_use_of_repeating_count_initializer
    return split(separator: "\n", omittingEmptySubsequences: false)
      .map { indent + $0 }
      .joined(separator: "\n")
  }

  public subscript(r: Range<Int>) -> String {
    let stringRange = rangeOfCharsIn(r)
    return String(self[stringRange])
  }

  public func rangeOfCharsIn(_ range: Range<Int>) -> Range<Index> {
    index(startIndex, offsetBy: range.lowerBound)..<index(startIndex, offsetBy: range.upperBound)
  }

  public func stringWithFirstCharCapitalized() -> String {
    guard !self.isEmpty else { return self }
    let secondCharIndex = index(after: startIndex)
    return self[startIndex].uppercased() + self[secondCharIndex...]
  }
}

public func dbgStr<T>(_ val: T?) -> String {
  val.map { "\($0)" } ?? "nil"
}
