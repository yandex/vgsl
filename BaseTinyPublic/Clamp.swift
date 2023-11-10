// Copyright 2022 Yandex LLC. All rights reserved.

import CoreGraphics

public func clamp(
  _ value: CGSize, min minValue: CGSize, max maxValue: CGSize
) -> CGSize {
  CGSize(
    width: clamp(value.width, min: minValue.width, max: maxValue.width),
    height: clamp(value.height, min: minValue.height, max: maxValue.height)
  )
}
