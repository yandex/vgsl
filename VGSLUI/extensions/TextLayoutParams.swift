// Copyright 2026 Yandex LLC. All rights reserved.

import CoreGraphics
import Foundation

final class TextLayoutParams: NSObject, @unchecked Sendable {
  let string: NSAttributedString
  let maxTextSize: CGSize
  let maxNumberOfLines: Int
  let truncationToken: NSAttributedString?
  let isCacheable: Bool

  init(
    string: NSAttributedString,
    maxTextSize: CGSize,
    maxNumberOfLines: Int,
    truncationToken: NSAttributedString?
  ) {
    isCacheable = !(string is NSMutableAttributedString) &&
      !(truncationToken is NSMutableAttributedString)
    if string is NSMutableAttributedString {
      self.string = NSAttributedString(attributedString: string)
    } else {
      self.string = string
    }
    self.maxTextSize = maxTextSize
    self.maxNumberOfLines = maxNumberOfLines
    if let truncationToken, truncationToken is NSMutableAttributedString {
      self.truncationToken = NSAttributedString(attributedString: truncationToken)
    } else {
      self.truncationToken = truncationToken
    }
  }

  // NSCache retains the key, so these identities stay valid until eviction.
  // Mutable strings are snapshots and bypass the cache because every snapshot has a new identity.
  override var hash: Int {
    var hasher = Hasher()
    hasher.combine(ObjectIdentifier(string))
    hasher.combine(maxTextSize)
    hasher.combine(maxNumberOfLines)
    hasher.combine(truncationToken.map(ObjectIdentifier.init))
    return hasher.finalize()
  }

  override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? TextLayoutParams,
          maxTextSize == other.maxTextSize,
          maxNumberOfLines == other.maxNumberOfLines,
          string === other.string else {
      return false
    }

    switch (truncationToken, other.truncationToken) {
    case (nil, nil):
      return true
    case let (token?, otherToken?):
      return token === otherToken
    default:
      return false
    }
  }
}
