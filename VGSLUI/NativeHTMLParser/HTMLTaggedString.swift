// Copyright 2017 Yandex LLC. All rights reserved.

import Foundation

struct HTMLTaggedString: CustomStringConvertible {
  let text: String
  let tags: [HTMLTag]

  var description: String {
    "text: \(text), tags: \(tags)"
  }

  func attributedString(with baseTypo: Typo) -> NSAttributedString {
    var typo = baseTypo
    tags.forEach { tag in
      switch tag {
      case .bold:
        typo = typo.with(fontWeight: .bold)
      case let .font(color):
        if let color {
          typo = typo.with(color: color)
        }
      }
    }

    return text.with(typo: typo)
  }
}
