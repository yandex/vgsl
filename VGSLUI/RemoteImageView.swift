// Copyright 2022 Yandex LLC. All rights reserved.

import UIKit

import VGSLFundamentals

public final class RemoteImageView: UIView, RemoteImageViewContentProtocol {
  private let contentsView = UIView()
  private lazy var contentsLayer = contentsView.layer
  private lazy var clipMask: CALayer = {
    let mask = CALayer()
    mask.backgroundColor = UIColor.white.cgColor
    return mask
  }()

  private var visualEffectView: UIVisualEffectView? {
    didSet {
      if let visualEffectView, visualEffectView.superview == nil {
        addSubview(visualEffectView)
      }
      if visualEffectView !== oldValue {
        oldValue?.removeFromSuperview()
      }
    }
  }

  public var appearanceAnimation: ImageViewAnimation?

  private var templateLayer: CALayer?

  private func updateContent() {
    let content = Content(
      image: image,
      imageRedrawingColor: imageRedrawingStyle?.tintColor,
      effects: imageRedrawingStyle?.effects ?? []
    )

    let gravity = imageContentMode
      .contentsGravity(isGeometryFlipped: contentsLayer.contentsAreFlipped())

    CATransaction.performWithoutAnimations {
      switch content {
      case let .plain(image):
        contentsLayer.setContents(image)
        contentsLayer.contentsGravity = gravity
        contentsLayer.backgroundColor = nil
        contentsLayer.mask = nil
        templateLayer = nil
      case let .template(image, color):
        contentsLayer.setContents(nil)
        contentsLayer.contentsGravity = .resize
        contentsLayer.backgroundColor = color.cgColor
        let template = templateLayer ?? CALayer()
        template.setContents(image)
        template.contentsGravity = gravity
        contentsLayer.mask = template
        templateLayer = template
      case let .effects(image, effects):
        var finalImage = image
        for effect in effects {
          switch effect {
          case let .tint(color, mode):
            if let out = finalImage.withColorBlend(color.systemColor, mode: mode ?? .sourceIn) {
              finalImage = out
            }
          case .blur:
            let effectView = visualEffectView ?? UIVisualEffectView()
            effectView.effect = UIBlurEffect(style: .light)
            visualEffectView = effectView
          }
        }
        contentsLayer.setContents(finalImage)
        contentsLayer.contentsGravity = gravity
        contentsLayer.backgroundColor = nil
        contentsLayer.mask = nil
        templateLayer = nil
      }
      if !content.needsVisualEffectView {
        visualEffectView = nil
      }
    }
    setNeedsLayout()
    layoutIfNeeded()
  }

  public func setImage(_ image: UIImage?, animated: Bool?) {
    self.image = image
    if let appearanceAnimation, animated == true {
      self.alpha = appearanceAnimation.startAlpha
      updateContent()
      UIView.animate(
        withDuration: appearanceAnimation.duration,
        delay: appearanceAnimation.delay,
        options: appearanceAnimation.options,
        animations: { self.alpha = appearanceAnimation.endAlpha },
        completion: nil
      )
    } else {
      updateContent()
    }
    setNeedsLayout()
    layoutIfNeeded()
  }

  private var image: UIImage?

  public var imageRedrawingStyle: ImageRedrawingStyle? {
    didSet { updateContent() }
  }

  public var imageContentMode = ImageContentMode.default {
    didSet { updateContent() }
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(contentsView)
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError()
  }

  public override func layoutSubviews() {
    super.layoutSubviews()

    let layout = ImageLayerLayout(
      contentMode: imageContentMode,
      contentSize: image?.size ?? bounds.size,
      boundsSize: bounds.size,
      capInsets: image?.capInsets ?? .zero
    )

    contentsView.frame = layout.frame
    contentsLayer.contentsRect = layout.contentRect
    contentsLayer.contentsCenter = layout.contentCenter

    templateLayer?.frame = contentsView.bounds
    templateLayer?.contentsRect = layout.contentRect
    templateLayer?.contentsCenter = layout.contentCenter

    visualEffectView?.frame = bounds

    updateMask()
  }

  private func updateMask() {
    let contentsHeight = templateLayer?.contentsRect.height ?? contentsLayer.contentsRect.height

    // MOBYANDEXIOS-376: for now, coded the layout only for top-directed content collapsing
    if contentsHeight > 1.0 {
      clipMask.frame = CGRect(
        x: 0,
        y: 0,
        width: bounds.width,
        height: layer.bounds.height / contentsHeight
      )

      layer.mask = clipMask
    } else if layer.mask != nil {
      layer.mask = nil
    }
    layer.masksToBounds = true
  }
}

extension UIImage.Orientation {
  fileprivate var layerTransform: CGAffineTransform {
    switch self {
    case .up:
      return .identity
    case .upMirrored:
      return CGAffineTransform(scaleX: -1, y: 1)
    case .down:
      return CGAffineTransform(rotationAngle: .pi)
    case .downMirrored:
      return CGAffineTransform(rotationAngle: .pi).scaledBy(x: -1, y: 1)
    case .left:
      return CGAffineTransform(rotationAngle: -.pi / 2)
    case .leftMirrored:
      return CGAffineTransform(rotationAngle: -.pi / 2).scaledBy(x: -1, y: 1)
    case .right:
      return CGAffineTransform(rotationAngle: .pi / 2)
    case .rightMirrored:
      return CGAffineTransform(rotationAngle: .pi / 2).scaledBy(x: -1, y: 1)
    @unknown default:
      return .identity
    }
  }
}

extension CALayer {
  fileprivate func setContents(_ source: Image?) {
    contents = source?.cgImage
    contentsScale = source?.scale ?? 1
    setAffineTransform(source?.imageOrientation.layerTransform ?? .identity)
  }
}

private enum Content {
  case plain(Image?)
  case template(Image, color: Color)
  case effects(Image, effects: [ImageEffect])

  var needsVisualEffectView: Bool {
    switch self {
    case .effects(_, let effects):
      for effect in effects {
        switch effect {
        case .blur: return true
        default: continue
        }
      }
      return false
    default:
      return false
    }
  }

  init(image: Image?, imageRedrawingColor: Color?, effects: [ImageEffect]) {
    if let image, effects.count > 0 {
      self = .effects(image, effects: effects)
    } else if let image, let color = imageRedrawingColor {
      self = .template(image, color: color)
    } else {
      self = .plain(image)
    }
  }
}

extension URLRequestResult.Source {
  var shouldAnimate: Bool {
    switch self {
    case .network: true
    case .cache: false
    }
  }
}

private extension UIImage {
  ///
  /// be careful with scale - it can n^2 memory usage
  ///
  func withColorBlend(_ color: UIColor, mode: TintMode, scale: CGFloat = 1.0) -> UIImage? {
    let drawRect = CGRect(origin: .zero, size: size)
    UIGraphicsBeginImageContextWithOptions(drawRect.size, true, scale)
    color.setFill()
    UIRectFill(drawRect)
    draw(in: drawRect, blendMode: mode.cgBlendMode, alpha: 1.0)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
  }
}

private extension TintMode {
  var cgBlendMode: CGBlendMode {
    switch self {
    case .sourceIn:
        .sourceIn
    case .sourceAtop:
        .sourceAtop
    case .darken:
        .darken
    case .lighten:
        .lighten
    case .multiply:
        .multiply
    case .screen:
        .screen
    }
  }
}
