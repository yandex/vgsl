// Copyright 2022 Yandex LLC. All rights reserved.

#if canImport(UIKit)
public struct ImageRedrawingStyle: Equatable, Sendable {
  public static func ==(lhs: ImageRedrawingStyle, rhs: ImageRedrawingStyle) -> Bool {
    lhs.tintColor == rhs.tintColor &&
      lhs.tintMode == rhs.tintMode &&
      lhs.effects == rhs.effects
  }

  let tintColor: Color?
  let tintMode: TintMode?
  let effects: [ImageEffect]

  public init(
    tintColor: Color?,
    tintMode: TintMode? = nil,
    effects: [ImageEffect]
  ) {
    self.tintColor = tintColor
    self.tintMode = tintMode
    self.effects = effects
  }
}
#endif
