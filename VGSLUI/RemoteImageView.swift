// Copyright 2022 Yandex LLC. All rights reserved.

#if canImport(UIKit)
import CoreImage
import UIKit

import VGSLFundamentals

public final class RemoteImageView: UIView, RemoteImageViewContentProtocol {
  public var filter: AnyEquatableImageFilter? {
    didSet {
      guard oldValue != filter, image != nil else { return }
      updateContent()
    }
  }

  private let contentsView = UIView()
  private lazy var contentsLayer = contentsView.layer
  private var filteredImageLayout: ImageFilterLayout?
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
      if oldValue !== visualEffectView {
        oldValue?.removeFromSuperview()
      }
    }
  }

  public var appearanceAnimation: ImageViewAnimation?

  private var templateLayer: CALayer?

  private func updateContent() {
    filteredImageLayout = nil
    let content = Content(
      image: image,
      imageRedrawingColor: imageRedrawingStyle?.tintColor,
      imageRedrawingTintMode: imageRedrawingStyle?.tintMode,
      effects: imageRedrawingStyle?.effects ?? []
    )

    let gravity = imageContentMode
      .contentsGravity(isGeometryFlipped: contentsLayer.contentsAreFlipped())

    CATransaction.performWithoutAnimations {
      var needsVisualEffectView = content.needsVisualEffectView
      switch content {
      case let .plain(image):
        if #available(iOS 14.0, tvOS 14.0, *), let image, let filter {
          applyAsyncFilter(filter, imageToUpdate: image)
          let effectView = visualEffectView ?? UIVisualEffectView()
          effectView.effect = UIBlurEffect(style: .light)
          visualEffectView = effectView
          needsVisualEffectView = true
        }
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
      if !needsVisualEffectView {
        visualEffectView = nil
      }
      forceLayout()
    }
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
  }

  private var image: UIImage?

  public override var frame: CGRect {
    didSet {
      if oldValue.size != frame.size, filter != nil, image != nil {
        updateContent()
      }
    }
  }

  public var imageRedrawingStyle: ImageRedrawingStyle? {
    didSet {
      guard oldValue != imageRedrawingStyle else { return }
      updateContent()
    }
  }

  public var imageContentMode = ImageContentMode.default {
    didSet {
      guard oldValue != imageContentMode else { return }
      updateContent()
    }
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

    let contentSize = image?.size ?? bounds.size
    let layout = ImageLayerLayout(
      contentMode: imageContentMode,
      contentSize: contentSize,
      boundsSize: bounds.size,
      capInsets: image?.capInsets ?? .zero
    )
    let currentFilterLayout = ImageFilterLayout(
      contentMode: imageContentMode,
      contentSize: contentSize,
      boundsSize: bounds.size,
      capInsets: image?.capInsets ?? .zero
    )

    if let filteredImageLayout, filteredImageLayout == currentFilterLayout {
      contentsView.frame = filteredImageLayout.frame
      contentsLayer.contentsRect = unitRect
      contentsLayer.contentsCenter = unitRect
    } else {
      contentsView.frame = layout.frame
      contentsLayer.contentsRect = layout.contentRect
      contentsLayer.contentsCenter = layout.contentCenter
    }

    templateLayer?.frame = contentsView.bounds
    templateLayer?.contentsRect = layout.contentRect
    templateLayer?.contentsCenter = layout.contentCenter

    visualEffectView?.frame = bounds

    updateMask()
  }

  @available(iOS 14.0, tvOS 14.0, *)
  private func applyAsyncFilter(_ filter: AnyEquatableImageFilter, imageToUpdate: UIImage) {
    let viewBounds = bounds
    let contentMode = imageContentMode
    let contentScale = window?.screen.scale ?? UIScreen.main.scale
    let filterLayout = ImageFilterLayout(
      contentMode: contentMode,
      contentSize: imageToUpdate.size,
      boundsSize: viewBounds.size,
      capInsets: imageToUpdate.capInsets
    )
    let resultHandler: @Sendable (CGImage?) -> Void = { cgImage in
      onMainThreadAsync { [weak self] in
        guard let self,
              self.image === imageToUpdate,
              self.bounds == viewBounds,
              self.imageContentMode == contentMode,
              self.filter == filter else {
          return
        }
        if let cgImage, let filterLayout {
          self.filteredImageLayout = filterLayout
          self.contentsLayer.contents = cgImage
          self.contentsLayer.setAffineTransform(.identity)
          self.contentsLayer.contentsGravity = .resize
          self.contentsLayer.contentsScale = contentScale
          self.forceLayout()
          self.visualEffectView = nil
        } else if filter.value.showOriginalImageIfFailed {
          self.visualEffectView = nil
        }
      }
    }
    onBackgroundThread(qos: .userInitiated)({
      if let filterLayout,
         let ciImage = imageToUpdate.preparedForFiltering(
           layout: filterLayout,
           scale: contentScale
         ),
         let filteredCIImage = filter.value.apply(to: ciImage, scale: contentScale),
         let cgImage = CIContext().createCGImage(filteredCIImage, from: filteredCIImage.extent) {
        resultHandler(cgImage)
      } else {
        resultHandler(nil)
      }
    })
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
    case let .effects(_, effects):
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

  init(
    image: Image?,
    imageRedrawingColor: Color?,
    imageRedrawingTintMode: TintMode?,
    effects: [ImageEffect]
  ) {
    if let image, effects.count > 0 {
      self = .effects(image, effects: effects)
    } else if let image, let color = imageRedrawingColor {
      if let tintMode = imageRedrawingTintMode, tintMode != .sourceIn {
        self = .effects(image, effects: [.tint(color: color, mode: tintMode)])
      } else {
        self = .template(image, color: color)
      }
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

extension UIImage {
  ///
  /// be careful with scale - it can n^2 memory usage
  ///
  fileprivate func withColorBlend(
    _ color: UIColor,
    mode: TintMode,
    scale: CGFloat = 1.0
  ) -> UIImage? {
    // Wrap in an autoreleasepool: this runs on the main thread during layout and
    // builds a full-size offscreen bitmap whose result image is autoreleased.
    // Draining promptly avoids accumulating bitmaps when many tinted images are
    // (re)drawn in one runloop turn.
    withImageDecodingAutoreleasePool {
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

  fileprivate func preparedForFiltering(
    layout: ImageFilterLayout,
    scale: CGFloat
  ) -> CIImage? {
    guard scale > 0 else { return nil }
    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    format.opaque = false
    let image = UIGraphicsImageRenderer(size: layout.frame.size, format: format).image { _ in
      draw(in: layout.imageRect)
    }
    return image.cgImage.map(CIImage.init(cgImage:))
  }
}

private let unitRect = CGRect(x: 0, y: 0, width: 1, height: 1)
#endif
