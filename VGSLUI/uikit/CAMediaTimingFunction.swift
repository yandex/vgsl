// Copyright 2018 Yandex LLC. All rights reserved.

import QuartzCore

@objc
extension CAMediaTimingFunction {
  @preconcurrency @MainActor
  public static let linear =
    CAMediaTimingFunction(name: .linear)
  @preconcurrency @MainActor
  public static let easeIn =
    CAMediaTimingFunction(name: .easeIn)
  @preconcurrency @MainActor
  public static let easeOut =
    CAMediaTimingFunction(name: .easeOut)
  @preconcurrency @MainActor
  public static let easeInEaseOut =
    CAMediaTimingFunction(name: .easeInEaseOut)
}
