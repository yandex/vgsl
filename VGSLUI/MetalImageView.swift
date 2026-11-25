// Copyright 2022 Yandex LLC. All rights reserved.

#if canImport(UIKit)
import MetalKit
import UIKit

import VGSLFundamentals

public final class MetalImageView: UIView, RemoteImageViewContentProtocol {
  public var appearanceAnimation: ImageViewAnimation?
  public var onImageDrawn: Signal<Void> {
    onImageDrawnPipe.signal
  }

  private let onImageDrawnPipe = SignalPipe<Void>()
  private var commandQueue: MTLCommandQueue?
  private var ciContext: CIContext?
  private var renderedImageCache = MetalImagePreparation.Cache()
  private lazy var device = MTLCreateSystemDefaultDevice()
  private var metalView: MTKView? {
    didSet {
      oldValue?.removeFromSuperview()
      oldValue?.delegate = nil
      metalView.flatMap(addSubview(_:))
    }
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    metalView?.frame = bounds
    metalView?.setNeedsDisplay()
  }

  public func setImage(_ image: UIImage?, animated: Bool?) {
    source = image.flatMap { MetalImagePreparation.Source($0) }
    if animated == true, source != nil {
      animateAppearance()
    }
  }

  private var source: MetalImagePreparation.Source? {
    didSet {
      guard oldValue != source else { return }
      if source == nil {
        metalView = nil
        renderedImageCache = MetalImagePreparation.Cache()
      } else {
        configureMetalView()
      }
    }
  }

  public var imageRedrawingStyle: ImageRedrawingStyle? {
    didSet {
      if oldValue != imageRedrawingStyle {
        metalView?.setNeedsDisplay()
      }
    }
  }

  public var imageContentMode = ImageContentMode.default {
    didSet {
      if oldValue != imageContentMode {
        metalView?.setNeedsDisplay()
      }
    }
  }

  private func makeRenderedImage(drawableSize: CGSize) -> CIImage? {
    guard let source else { return nil }
    return renderedImageCache.image(for: MetalImagePreparation.Parameters(
      source: source,
      redrawingStyle: imageRedrawingStyle,
      contentMode: imageContentMode,
      boundsSize: bounds.size,
      drawableSize: drawableSize
    ), context: ciContext)
  }

  private func animateAppearance() {
    if let appearanceAnimation = self.appearanceAnimation {
      self.alpha = appearanceAnimation.startAlpha
      UIView.animate(
        withDuration: appearanceAnimation.duration,
        delay: appearanceAnimation.delay,
        options: appearanceAnimation.options,
        animations: { self.alpha = appearanceAnimation.endAlpha },
        completion: nil
      )
    }
  }

  private func configureMetalView() {
    let mtkView = MTKView(frame: frame, device: device)
    mtkView.enableSetNeedsDisplay = true
    mtkView.isPaused = true
    mtkView.framebufferOnly = false
    mtkView.delegate = self
    mtkView.backgroundColor = .clear
    metalView = mtkView
    commandQueue = mtkView.device?.makeCommandQueue()
    ciContext = mtkView.device.map(CIContext.init(mtlDevice:))
  }
}

extension MetalImageView: MTKViewDelegate {
  public func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

  public func draw(in view: MTKView) {
    guard !view.bounds.isEmpty,
          let drawable = view.currentDrawable,
          let commandQueue,
          let currentRenderPassDescriptor = view.currentRenderPassDescriptor
    else {
      return
    }
    let buffer = commandQueue.makeCommandBuffer()
    currentRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor()
    let renderEncoder = buffer?.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
    renderEncoder?.endEncoding()

    let drawableSize = view.drawableSize
    let bounds = CGRect(origin: .zero, size: drawableSize)
    guard let scaledImage = makeRenderedImage(drawableSize: drawableSize) else {
      buffer?.present(drawable)
      buffer?.commit()
      return
    }

    let ciContext: CIContext?
    let syncWithUI: (() -> Void)?

    #if DEBUG
    ciContext = isSnapshotTest ? CIContext() : self.ciContext
    syncWithUI = isSnapshotTest ? { buffer?.waitUntilCompleted() } : nil
    #else
    ciContext = self.ciContext
    syncWithUI = nil
    #endif

    if #available(iOS 11, tvOS 11, *) {
      let destination = CIRenderDestination(
        width: Int(drawableSize.width),
        height: Int(drawableSize.height),
        pixelFormat: view.colorPixelFormat,
        commandBuffer: buffer,
        mtlTextureProvider: { () -> MTLTexture in
          drawable.texture
        }
      )

      _ = try? ciContext?.startTask(toRender: scaledImage, to: destination)
    } else {
      ciContext?.render(
        scaledImage,
        to: drawable.texture,
        commandBuffer: buffer,
        bounds: bounds,
        colorSpace: CGColorSpaceCreateDeviceRGB()
      )
    }

    nonisolated(unsafe) let onImageDrawnPipe = onImageDrawnPipe
    buffer?.addCompletedHandler { @Sendable buffer in
      guard case .completed = buffer.status else { return }
      onMainThread {
        onImageDrawnPipe.send()
      }
    }

    buffer?.present(drawable)
    buffer?.commit()
    syncWithUI?()
  }
}

#if DEBUG
private let isSnapshotTest = ProcessInfo.processInfo
  .environment["XCTestConfigurationFilePath"] != nil
#endif
#endif
