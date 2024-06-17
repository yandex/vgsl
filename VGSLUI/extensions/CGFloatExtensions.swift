// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics
import Foundation

extension CGFloat {
  public func rounded(toStep step: CGFloat = 1) -> CGFloat {
    Foundation.round(self / step) * step
  }

  public func ceiled(toStep step: CGFloat = 1, equalityAccuracy: CGFloat = 1e-5) -> CGFloat {
    ceil((self - equalityAccuracy) / step) * step
  }

  public func floored(toStep step: CGFloat = 1, equalityAccuracy: CGFloat = 1e-5) -> CGFloat {
    Foundation.floor((self + equalityAccuracy) / step) * step
  }

  public var roundedToScreenScale: CGFloat {
    rounded(toStep: 1 / PlatformDescription.screenScale())
  }

  public var roundedUpToScreenScale: CGFloat {
    let screenScale = PlatformDescription.screenScale()
    return (self / screenScale).rounded(.up) * screenScale
  }

  public var roundedDownToScreenScale: CGFloat {
    let screenScale = PlatformDescription.screenScale()
    return (self / screenScale).rounded(.down) * screenScale
  }

  public var flooredToScreenScale: CGFloat {
    floored(toStep: 1 / PlatformDescription.screenScale())
  }
}

extension CGFloat {
  public func interpolated(to end: CGFloat, progress: CGFloat) -> CGFloat {
    let p = progress.clamp(0...1)
    return self * (1 - p) + end * p
  }

  public var half: CGFloat {
    (self * 0.5).rounded(.toNearestOrEven)
  }
}
