// Copyright 2017 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

enum HTMLTag: CustomStringConvertible, Equatable {
  case bold
  case font(Color?)

  init?(tag: String, attributes: [String: String]?) {
    let lowercasedAttributes = attributes?.lowercasedKeys
    switch tag.lowercased() {
    case "b":
      self = .bold
    case "font":
      let color = lowercasedAttributes?["color"].flatMap(Color.color(withHexString:))
      self = .font(color)
    default:
      return nil
    }
  }

  var description: String {
    switch self {
    case .bold:
      "tag.bold"
    case let .font(color):
      "tag.font(color: \(dbgStr(color)))"
    }
  }
}
