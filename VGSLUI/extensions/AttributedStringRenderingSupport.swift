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

extension NSMutableAttributedString {
  internal func appendWithPreservedAttributes(_ string: String) {
    replaceCharacters(in: NSRange(location: length, length: 0), with: string)
  }
}

extension CFRange {
  internal static let infinite = CFRange(location: 0, length: 0)

  internal static func withLength(_ length: Int) -> CFRange {
    CFRange(location: 0, length: length)
  }

  internal var nsRange: NSRange {
    NSRange(location: self.location, length: self.length)
  }
}

extension NSRange {
  internal var endIndex: Int {
    location + length
  }
}

extension UTF16Char {
  internal var isWhitespace: Bool {
    isIn(.whitespaces)
  }

  internal var isWhitespaceOrNewline: Bool {
    isIn(.whitespacesAndNewlines)
  }

  internal var isNewline: Bool {
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
  internal mutating func removeLastIfExists() {
    guard !isEmpty else {
      return
    }
    removeLast()
  }
}

extension NSAttributedString.VerticalPosition {
  internal func verticalOffset(forHeight height: CGFloat, availableHeight: CGFloat) -> CGFloat {
    switch self {
    case .top: 0
    case .center: (availableHeight - height) / 2
    case .bottom: availableHeight - height
    }
  }
}

extension CGContext {
  func withPreservedTextState<T>(_ action: () -> T) -> T {
    let textMatrix = textMatrix
    let textPosition = textPosition
    saveGState()
    defer {
      restoreGState()
      self.textMatrix = textMatrix
      self.textPosition = textPosition
    }
    return action()
  }

  internal func performDrawing(shadedWith shadow: SystemShadow?, _ drawing: () -> Void) {
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
  internal var estimatedStrikethroughWidth: CGFloat {
    // count strikethrough line of 1 pt as normal for default 12-pt font size
    max(
      1 / PlatformDescription.screenScale(),
      (pointSize / 12).roundedToScreenScale
    )
  }

  internal var underlineThickness: CGFloat {
    CTFontGetUnderlineThickness(self)
  }

  internal var underlinePosition: CGFloat {
    CTFontGetUnderlinePosition(self)
  }
}

internal let selectionColor = Color.colorWithHexCode(0xB3_D7_FE_7F)

internal let selectionPointerColor = Color.colorWithHexCode(0x22_66_C5_FF)

internal let pointerCircleSize = CGSize(width: 10, height: 10)
internal let pointerShapeWidth: CGFloat = 2

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
  internal static func with(rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    path.addRect(rect)
    return path
  }
}

extension [CloudBackgroundAttribute: [CGRect]] {
  internal mutating func append(cloudBackgrounds: [CTLine.CloudBackground]) {
    for background in cloudBackgrounds {
      var array = self[background.info] ?? []
      array.append(background.rect)
      self[background.info] = array
    }
  }
}
