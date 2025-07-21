// Copyright 2021 Yandex LLC. All rights reserved.

#if os(macOS)
import AppKit

public typealias ViewType = AnyObject
public typealias ScrollView = ScrollViewType

extension EdgeInsets: Swift.Equatable {
  public static var zero: EdgeInsets { NSEdgeInsetsZero }
}

public func ==(lhs: EdgeInsets, rhs: EdgeInsets) -> Bool {
  NSEdgeInsetsEqual(lhs, rhs)
}

public typealias BezierPath = NSBezierPath

extension NSBezierPath {
  public convenience init(roundedRect rect: CGRect, cornerRadius: CGFloat) {
    self.init(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
  }

  public var usesEvenOddFillRule: Bool {
    get {
      if windingRule == .evenOdd { return true }
      return false
    }
    set {
      windingRule = newValue ? .evenOdd : .nonZero
    }
  }

  public func addLine(to point: CGPoint) {
    line(to: point)
  }

  public func addCurve(to endPoint: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint) {
    curve(to: endPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
  }

  public func apply(_ transform: CGAffineTransform) {
    self.transform(using: AffineTransform(cgTransform: transform))
  }

  // https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/CocoaDrawingGuide/Paths/Paths.html#//apple_ref/doc/uid/TP40003290-CH206-SW2
  public var cgPath: CGPath {
    let result = CGMutablePath()

    var associatedPoints = [NSPoint](repeating: .zero, times: 3)
    var pathClosed = true

    for i in 0..<elementCount {
      switch element(at: i, associatedPoints: &associatedPoints) {
      case .moveTo:
        result.move(to: associatedPoints[0])
      case .lineTo:
        result.addLine(to: associatedPoints[0])
        pathClosed = false
      #if swift(<5.9)
      case .curveTo:
        result.addCurve(
          to: associatedPoints[0],
          control1: associatedPoints[1],
          control2: associatedPoints[2]
        )
        pathClosed = false
      #endif
      case .closePath:
        result.closeSubpath()
        pathClosed = true
      #if swift(>=5.9)
      case .cubicCurveTo:
        result.addCurve(
          to: associatedPoints[0],
          control1: associatedPoints[1],
          control2: associatedPoints[2]
        )
        pathClosed = false
      case .quadraticCurveTo:
        result.addCurve(
          to: associatedPoints[0],
          control1: associatedPoints[1],
          control2: associatedPoints[2]
        )
        pathClosed = false
      #endif
      @unknown default:
        break
      }
    }

    if !pathClosed {
      result.closeSubpath()
    }

    return result.copy()!
  }
}

public let RectFill = __NSRectFill

extension NSImage {
  public func resizableImage(
    withCapInsets capInsets: EdgeInsets,
    resizingMode: NSImage.ResizingMode = .tile
  ) -> NSImage {
    let image = self.copy() as! NSImage
    image.capInsets = capInsets
    image.resizingMode = resizingMode
    return image
  }
}

extension NSCompositingOperation {
  public init(blendMode: CGBlendMode) {
    switch blendMode {
    case .clear:
      self = .clear
    case .copy:
      self = .copy
    case .normal:
      self = .sourceOver
    case .sourceIn:
      self = .sourceIn
    case .sourceOut:
      self = .sourceOut
    case .sourceAtop:
      self = .sourceAtop
    case .destinationOver:
      self = .destinationOver
    case .destinationIn:
      self = .destinationIn
    case .destinationOut:
      self = .destinationOut
    case .destinationAtop:
      self = .destinationAtop
    case .xor:
      self = .xor
    case .plusDarker:
      self = .plusDarker
    case .plusLighter:
      self = .plusLighter
    case .multiply:
      self = .multiply
    case .screen:
      self = .screen
    case .overlay:
      self = .overlay
    case .darken:
      self = .darken
    case .lighten:
      self = .lighten
    case .colorDodge:
      self = .colorDodge
    case .colorBurn:
      self = .colorBurn
    case .softLight:
      self = .softLight
    case .hardLight:
      self = .hardLight
    case .difference:
      self = .difference
    case .exclusion:
      self = .exclusion
    case .hue:
      self = .hue
    case .saturation:
      self = .saturation
    case .color:
      self = .color
    case .luminosity:
      self = .luminosity
    @unknown default:
      self = .clear
    }
  }
}

extension AffineTransform {
  public init(cgTransform: CGAffineTransform) {
    self.init(
      m11: cgTransform.a,
      m12: cgTransform.b,
      m21: cgTransform.c,
      m22: cgTransform.d,
      tX: cgTransform.tx,
      tY: cgTransform.ty
    )
  }
}

public enum ViewContentMode {
  case scaleToFill
  case scaleAspectFit
  case scaleAspectFill
  case redraw
  case center
  case top
  case bottom
  case left
  case right
  case topLeft
  case topRight
  case bottomLeft
  case bottomRight
}

public let uiSwitchSize = CGSize(width: 10, height: 10) // arbitrary size

public enum PageControl {
  public static func size(forNumberOfPages _: Int) -> CGSize {
    uiSwitchSize // arbitrary size
  }
}

public typealias EdgeInsets = NSEdgeInsets
public typealias Color = RGBAColor
public typealias SystemColor = NSColor

public typealias UserInterfaceLayoutDirection = NSUserInterfaceLayoutDirection

extension UserInterfaceLayoutDirection {
  @preconcurrency @MainActor
  public static var system: UserInterfaceLayoutDirection {
    NSApplication.shared.userInterfaceLayoutDirection
  }
}

public typealias SystemShadow = NSShadow

extension NSShadow {
  public var cgColor: CGColor? { shadowColor?.cgColor }
}

public typealias Font = NSFont

public typealias UnderlineStyle = NSUnderlineStyle
public typealias TextAttachment = NSTextAttachment
public typealias TextAlignment = NSTextAlignment
public typealias LineBreakMode = NSLineBreakMode
public typealias WritingDirection = NSWritingDirection
public typealias TextTab = NSTextTab

extension CGRect {
  public func inset(by insets: EdgeInsets) -> CGRect {
    CGRect(
      x: origin.x + insets.left,
      y: origin.y + insets.top,
      width: max(0, size.width - insets.left - insets.right),
      height: max(0, size.height - insets.top - insets.bottom)
    )
  }
}

public typealias NSParagraphStyle = AppKit.NSParagraphStyle
public typealias NSMutableParagraphStyle = AppKit.NSMutableParagraphStyle

public typealias Image = NSImage

extension Image {
  public func binaryRepresentation() -> Data? {
    tiffRepresentation
  }
}

extension NSImage {
  public class func imageOfSize(
    _ size: CGSize,
    opaque _: Bool = false,
    scale _: CGFloat = 0,
    drawingHandler: (CGContext) -> Void
  ) -> NSImage? {
    let image = NSImage(size: size)
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else { return nil }
    drawingHandler(context)
    assert(
      NSGraphicsContext.current!.cgContext === context,
      "Current graphics context was changed inside a drawing handler"
    )
    image.unlockFocus()
    return image
  }

  public var scale: CGFloat { defaultScreenScale }

  public convenience init?(data: Data, scale _: CGFloat) {
    self.init(data: data)
  }

  @available(macOS 11.0, *)
  public convenience init?(systemName: String) {
    self.init(systemSymbolName: systemName, accessibilityDescription: nil)
  }
}

extension Image {
  public var cgImg: CGImage? {
    cgImage(forProposedRect: nil, context: nil, hints: nil)
  }
}

extension Image {
  public func pngData() -> Data? {
    data(using: .png)
  }

  public func jpegData(compressionQuality _: CGFloat) -> Data? {
    data(using: .jpeg)
  }

  private func data(using storageType: NSBitmapImageRep.FileType) -> Data? {
    guard let cgImage = cgImg else { return nil }
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    return bitmap.representation(using: storageType, properties: [:])
  }
}

private let defaultScreenScale: CGFloat = 1

public enum PlatformDescription {
  public static func screenScale() -> CGFloat {
    defaultScreenScale
  }
}

extension NSImage {
  open override var debugDescription: String {
    self.binaryRepresentation().map { "Image, hash: \($0.hashValue)" } ?? "No binary representation"
  }
}

extension NSColor {
  public var rgba: RGBAColor {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    usingColorSpace(.genericRGB)!.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

    return RGBAColor(red: red, green: green, blue: blue, alpha: alpha)
  }
}

extension RGBAColor {
  public var white: CGFloat {
    var white: CGFloat = 0
    systemColor.usingColorSpace(.genericGray)?.getWhite(&white, alpha: nil)
    return white
  }
}

extension NSFont {
  public class func systemFontWithDefaultSize() -> NSFont {
    systemFont(ofSize: NSFont.systemFontSize)
  }

  public func defaultLineHeight() -> CGFloat {
    NSLayoutManager().defaultLineHeight(for: self)
  }

  public static let emojiFontName = ".AppleColorEmojiUI"

  var safeLeading: CGFloat {
    leading
  }
}

extension URL {
  public static let applicationOpenSettingsURL = URL(string: "fake-url://")!
}
#endif
