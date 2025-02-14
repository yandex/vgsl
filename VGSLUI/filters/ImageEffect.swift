// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics

public enum ImageEffect: Equatable, Sendable {
  case blur(radius: CGFloat)
  case tint(color: RGBAColor, mode: TintMode?)
}
