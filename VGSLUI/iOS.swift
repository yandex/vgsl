// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics
import UIKit

import VGSLFundamentals

public typealias Color = RGBAColor
public typealias SystemColor = UIColor

public typealias SystemShadow = NSShadow

public typealias EdgeInsets = UIEdgeInsets

public typealias UserInterfaceLayoutDirection = UIUserInterfaceLayoutDirection

extension UserInterfaceLayoutDirection {
  @available(iOSApplicationExtension, unavailable)
  @available(tvOSApplicationExtension, unavailable)
  public static var system: UserInterfaceLayoutDirection {
    UIApplication.shared.userInterfaceLayoutDirection
  }
}

extension NSShadow {
  public var cgColor: CGColor? { (shadowColor as? UIColor)?.cgColor }
}

public typealias Font = UIFont

public typealias UnderlineStyle = NSUnderlineStyle
public typealias TextAttachment = NSTextAttachment
public typealias TextAlignment = NSTextAlignment
public typealias LineBreakMode = NSLineBreakMode
public typealias WritingDirection = NSWritingDirection
public typealias TextTab = NSTextTab

public typealias NSParagraphStyle = UIKit.NSParagraphStyle
public typealias NSMutableParagraphStyle = UIKit.NSMutableParagraphStyle

public typealias Image = UIImage

extension Image {
  public func binaryRepresentation() -> Data? {
    pngData()
  }
}

extension UIImage {
  public class func imageOfSize(
    _ size: CGSize,
    opaque: Bool = false,
    scale: CGFloat = 0,
    orientation: UIImage.Orientation = .up,
    transformForUIKitCompatibility: Bool = true,
    drawingHandler: (CGContext) -> Void
  ) -> UIImage? {
    let actualScale = scale.isZero ? UIScreen.main.scale : scale
    let width = Int(size.width * actualScale)
    let height = Int(size.height * actualScale)
    let alphaInfo = opaque ? CGImageAlphaInfo.noneSkipFirst : CGImageAlphaInfo.premultipliedFirst
    let bitmapInfo = CGBitmapInfo.byteOrder32Little
    guard let ctx = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: alphaInfo.rawValue | bitmapInfo.rawValue
    ) else {
      return nil
    }

    if transformForUIKitCompatibility {
      ctx.translateBy(x: 0, y: CGFloat(height))
      ctx.scaleBy(x: actualScale, y: -actualScale)
    } else {
      ctx.scaleBy(x: actualScale, y: actualScale)
    }

    ctx.textMatrix = CGAffineTransform(scaleX: -1, y: 1)
    drawingHandler(ctx)
    guard let image = ctx.makeImage() else {
      return nil
    }

    return UIImage(cgImage: image, scale: actualScale, orientation: orientation)
  }
}

extension Image {
  public var cgImg: CGImage? {
    cgImage
  }
}

public enum PlatformDescription {
  public static func screenScale() -> CGFloat {
    UIScreen.main.scale
  }
}

extension Font {
  public class func systemFontWithDefaultSize() -> Font {
    defaultFont
  }

  public func defaultLineHeight() -> CGFloat {
    self.lineHeight
  }

  public static let emojiFontName = "AppleColorEmoji"
}

extension SystemColor {
  public var rgba: RGBAColor {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
      preconditionFailure()
    }

    return RGBAColor(red: red, green: green, blue: blue, alpha: alpha)
  }
}

extension RGBAColor {
  public var white: CGFloat {
    var white: CGFloat = 0
    systemColor.getWhite(&white, alpha: nil)
    return white
  }
}

extension URL {
  public static let applicationOpenSettingsURL = URL(string: UIApplication.openSettingsURLString)!

  public static var openNotificationSettingsURL: URL {
    if #available(iOS 16, *) {
      URL(string: UIApplication.openNotificationSettingsURLString)!
    } else if #available(iOS 15.4, *) {
      URL(string: UIApplicationOpenNotificationSettingsURLString)!
    } else {
      .applicationOpenSettingsURL
    }
  }
}

#if os(iOS)
private let defaultFont = Font.systemFont(ofSize: Font.systemFontSize)
#else
private let defaultFont = Font.systemFont(ofSize: 12)
#endif

public typealias ViewType = UIView
public typealias ScrollView = ScrollViewType & UIView
public typealias ScrollToDragView = ScrollToDrag & UIView

public typealias BezierPath = UIBezierPath

public let RectFill = UIRectFill

public typealias ViewContentMode = UIView.ContentMode

@available(tvOS, unavailable)
public let uiSwitchSize = UISwitch().frame.size

public enum PageControl {
  public static func size(forNumberOfPages number: Int) -> CGSize {
    pageControlSizeForNumberOfPages(number)
  }
}

private let pageControlSizeForNumberOfPages = memoize { numberOfPages in
  modified(UIPageControl()) {
    $0.numberOfPages = numberOfPages
  }.size(forNumberOfPages: numberOfPages)
}

@available(tvOS, unavailable)
extension StatusBarStyle {
  public var value: UIStatusBarStyle {
    switch self {
    case .default:
      .default
    case .light:
      .lightContent
    case .dark:
      if #available(iOS 13, tvOS 13, *) {
        .darkContent
      } else {
        .default
      }
    }
  }
}

extension KeyboardAppearance {
  public var system: UIKeyboardAppearance {
    switch self {
    case .light:
      .light
    case .dark:
      .dark
    }
  }
}

/// Line width of one rendered pixel
public let minimalLineWidth: CGFloat = 1 / UIScreen.main.scale
