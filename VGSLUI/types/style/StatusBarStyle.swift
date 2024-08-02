// Copyright 2017 Yandex LLC. All rights reserved.

import CoreGraphics
import Foundation

public enum StatusBarStyle: Equatable {
  case `default`
  case light
  case dark
}

extension StatusBarStyle {
  public init(from white: CGFloat) {
    self = white > 0.5 ? .dark : .light
  }
}
