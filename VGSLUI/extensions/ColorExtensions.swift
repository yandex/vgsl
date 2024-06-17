// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics
import Foundation

extension Color {
  public var cgColor: CGColor {
    let colorspace = CGColorSpaceCreateDeviceRGB()
    let components = [red, green, blue, alpha]
    return CGColor(colorSpace: colorspace, components: components)!
  }

  public var hexString: String {
    String(format: "#%02X%02X%02X%02X", intAlpha, intRed, intGreen, intBlue)
  }
}

extension Color: CustomDebugStringConvertible {
  public var debugDescription: String {
    hexString
  }
}

extension Color {
  public static let black = SystemColor.black.rgba
  public static let blue = SystemColor.blue.rgba
  public static let brown: Color = SystemColor.brown.rgba
  public static let clear: Color = SystemColor.clear.rgba
  public static let cyan: Color = SystemColor.cyan.rgba
  public static let darkGray: Color = SystemColor.darkGray.rgba
  public static let gray: Color = SystemColor.gray.rgba
  public static let green: Color = SystemColor.green.rgba
  public static let lightGray: Color = SystemColor.lightGray.rgba
  public static let magenta: Color = SystemColor.magenta.rgba
  public static let orange: Color = SystemColor.orange.rgba
  public static let purple: Color = SystemColor.purple.rgba
  public static let red: Color = SystemColor.red.rgba
  public static let white: Color = SystemColor.white.rgba
  public static let yellow: Color = SystemColor.yellow.rgba
}

extension Color {
  public static func colorWithRed(_ red: UInt8, green: UInt8, blue: UInt8) -> Color {
    Color(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
  }

  public static func color(withRGBValue value: Int) -> Color {
    let RGBValue = UInt32(value)
    let RGBAValue = (RGBValue << 8) | 0xFF
    return .colorWithHexCode(RGBAValue)
  }

  public func interpolate(to target: Color, progress: CGFloat) -> Color {
    Color(
      red: red.interpolated(to: target.red, progress: progress),
      green: green.interpolated(to: target.green, progress: progress),
      blue: blue.interpolated(to: target.blue, progress: progress),
      alpha: alpha.interpolated(to: target.alpha, progress: progress)
    )
  }

  public func withAlphaComponent(_ alpha: CGFloat) -> Color {
    Color(red: red, green: green, blue: blue, alpha: alpha)
  }

  public func setStroke() {
    systemColor.setStroke()
  }

  public func setFill() {
    systemColor.setFill()
  }
}
