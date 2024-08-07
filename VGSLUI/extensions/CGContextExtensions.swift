// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics

import VGSLFundamentals

extension CGContext {
  public func inSeparateGState(_ block: Action) {
    saveGState()
    block()
    restoreGState()
  }
}
