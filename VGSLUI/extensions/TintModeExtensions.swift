// Copyright 2025 Yandex LLC. All rights reserved.

import CoreGraphics

extension TintMode {
  var cgBlendMode: CGBlendMode {
    switch self {
    case .sourceIn:
      .sourceIn
    case .sourceAtop:
      .sourceAtop
    case .darken:
      .darken
    case .lighten:
      .lighten
    case .multiply:
      .multiply
    case .screen:
      .screen
    }
  }
}
