// Copyright 2022 Yandex LLC. All rights reserved.

#if canImport(UIKit)
import UIKit

@preconcurrency @MainActor
public protocol ImageViewProtocol {
  var appearanceAnimation: ImageViewAnimation? { get set }
  var imageRedrawingStyle: ImageRedrawingStyle? { get set }
  var imageContentMode: ImageContentMode { get set }
  var filter: AnyEquatableImageFilter? { get set }
}

extension ImageViewProtocol {
  public var filter: AnyEquatableImageFilter? {
    get {
      nil
    }
    set {}
  }
}

public struct ImageViewAnimation: Sendable {
  let duration: Double
  let delay: Double
  let startAlpha: Double
  let endAlpha: Double
  let options: UIView.AnimationOptions

  public init(
    duration: Double,
    delay: Double,
    startAlpha: Double,
    endAlpha: Double,
    options: UIView.AnimationOptions
  ) {
    self.duration = duration
    self.delay = delay
    self.startAlpha = startAlpha
    self.endAlpha = endAlpha
    self.options = options
  }
}
#endif
