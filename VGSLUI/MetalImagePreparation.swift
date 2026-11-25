// Copyright 2026 Yandex LLC. All rights reserved.

#if canImport(UIKit)
import CoreImage
import UIKit

import VGSLFundamentals

enum MetalImagePreparation {
  struct Source: Equatable {
    let orientedImage: CIImage
    let scale: CGFloat
    let orientedCapInsets: UIEdgeInsets
    let resizingMode: UIImage.ResizingMode
    // Tiled patterns must be resized before applying the original UIImage orientation.
    let originalOrientation: UIImage.Orientation

    static func ==(lhs: Self, rhs: Self) -> Bool {
      lhs.orientedImage === rhs.orientedImage && lhs.scale == rhs.scale &&
        lhs.orientedCapInsets == rhs.orientedCapInsets && lhs.resizingMode == rhs.resizingMode &&
        lhs.originalOrientation == rhs.originalOrientation
    }
  }

  struct Parameters: Equatable {
    var source: Source
    var redrawingStyle: ImageRedrawingStyle?
    var contentMode: ImageContentMode
    var boundsSize: CGSize
    var drawableSize: CGSize
  }

  struct ResizeGeometry {
    let targetSizeInPixels: CGSize
    // Visible part of the full resized image, before positioning it in the drawable.
    let visibleRectInImagePixels: CGRect
    let drawableScale: CGSize

    func nativeBitmapLayout(imageScale: CGFloat) -> (size: CGSize, imageRect: CGRect) {
      let fullNativeSize = CGSize(
        width: targetSizeInPixels.width * imageScale / drawableScale.width,
        height: targetSizeInPixels.height * imageScale / drawableScale.height
      )
      // Expand only a subpixel destination, never a small viewport within a larger tiled image.
      let nativeSize = CGSize(
        width: visibleRectInImagePixels.width * imageScale / drawableScale.width * max(1, 1 / fullNativeSize.width),
        height: visibleRectInImagePixels.height * imageScale / drawableScale.height * max(1, 1 / fullNativeSize.height)
      )
      func bitmapDimension(_ value: CGFloat) -> CGFloat {
        max(1, value.isApproximatelyEqualTo(value.rounded()) ? value.rounded() : value.rounded(.up))
      }
      let size = CGSize(
        width: bitmapDimension(nativeSize.width), height: bitmapDimension(nativeSize.height)
      )
      let padding = (size - nativeSize) / 2
      // Centering covers every storage-pixel center, even for a subpixel image.
      let imageRect = CGRect(
        x: padding.width, y: padding.height, width: nativeSize.width, height: nativeSize.height
      )
      return (size, imageRect)
    }
  }

  struct Cache {
    private var cached: (params: Parameters, image: CIImage)?

    mutating func image(for params: Parameters, context: CIContext?) -> CIImage? {
      if let cached, cached.params == params {
        return cached.image
      }
      guard let image = MetalImagePreparation.makeImage(params: params, context: context) else {
        return nil
      }
      cached = (params, image)
      return image
    }
  }
}

extension MetalImagePreparation.Source {
  init?(_ image: UIImage) {
    guard let source = image.ciImage ?? image.cgImage.map({ CIImage(cgImage: $0) }) else {
      return nil
    }
    let oriented = source.oriented(for: image.imageOrientation)
    self.init(
      orientedImage: oriented.transformed(by: CGAffineTransform(
        translationX: -oriented.extent.minX, y: -oriented.extent.minY
      )),
      scale: image.scale,
      orientedCapInsets: image.imageOrientation.orientedInsets(image.capInsets),
      resizingMode: image.resizingMode,
      originalOrientation: image.imageOrientation
    )
  }
}

extension MetalImagePreparation {
  static func makeImage(params: Parameters, context: CIContext?) -> CIImage? {
    let source = params.source
    let boundsSize = params.boundsSize
    let drawableSize = params.drawableSize
    guard boundsSize.width > 0, boundsSize.height > 0,
          drawableSize.width > 0, drawableSize.height > 0 else { return nil }
    guard let filteredImage = makeFilteredImage(
      image: source.orientedImage, boundsSize: boundsSize, redrawingStyle: params.redrawingStyle
    ) else { return nil }

    // Layout uses points; Core Image uses pixels.
    // UIImage.scale determines the image's natural size in points.
    let contentSizeInPoints = source.orientedImage.extent.size / source.scale
    let contentFrameInPoints = layout(
      contentMode: params.contentMode,
      contentSize: contentSizeInPoints,
      boundsSize: boundsSize
    )

    // Use the actual drawable-to-view ratio rather than UIScreen.scale;
    // the drawable may have a different scale on each axis.
    let drawableScale = CGSize(
      width: drawableSize.width / boundsSize.width,
      height: drawableSize.height / boundsSize.height
    )
    let contentFrameInPixels = pixelFrame(contentFrameInPoints, scale: drawableScale)
    guard contentFrameInPixels.width > 0, contentFrameInPixels.height > 0 else { return nil }

    let visibleRectInImagePixels = contentFrameInPixels
      .intersection(CGRect(origin: .zero, size: drawableSize))
      .offsetBy(dx: -contentFrameInPixels.minX, dy: -contentFrameInPixels.minY)

    // Cap insets affect resizing only. In noScale mode, preserve the image as a whole.
    let capInsets = params.contentMode.scale == .noScale ? .zero : source.orientedCapInsets
    guard let resizedImage = resizeImage(
      filteredImage,
      geometry: ResizeGeometry(
        targetSizeInPixels: contentFrameInPixels.size,
        visibleRectInImagePixels: visibleRectInImagePixels,
        drawableScale: drawableScale
      ),
      capInsets: capInsets,
      imageScale: source.scale,
      resizingMode: source.resizingMode,
      orientation: source.originalOrientation,
      context: context
    ) else { return nil }

    let positionInDrawable = CGAffineTransform(
      translationX: contentFrameInPixels.minX,
      y: contentFrameInPixels.minY
    )
    return resizedImage.transformed(by: positionInDrawable)
      .cropped(to: CGRect(origin: .zero, size: drawableSize))
  }
}

private func resizeImage(
  _ image: CIImage,
  geometry: MetalImagePreparation.ResizeGeometry,
  capInsets: UIEdgeInsets,
  imageScale: CGFloat,
  resizingMode: UIImage.ResizingMode,
  orientation: UIImage.Orientation,
  context: CIContext?
) -> CIImage? {
  let targetSize = geometry.targetSizeInPixels
  let drawableScale = geometry.drawableScale
  guard capInsets != .zero else {
    let scaleToTarget = CGAffineTransform(
      scaleX: targetSize.width / image.extent.width,
      y: targetSize.height / image.extent.height
    )
    return image.transformed(by: scaleToTarget)
  }

  // Resize in source coordinates: orienting a tile first changes its final partial repeat.
  let image = image.oriented(for: orientation.inverse)
  let capInsets = orientation.inverse.orientedInsets(capInsets)
  let sourceToDrawableScale = drawableScale / imageScale
  let scale = CGAffineTransform(scaleX: sourceToDrawableScale.width, y: sourceToDrawableScale.height)
  let scaledExtent = image.extent.applying(scale)
  let capInsetsInPixels = UIEdgeInsets(
    top: capInsets.top * drawableScale.height,
    left: capInsets.left * drawableScale.width,
    bottom: capInsets.bottom * drawableScale.height,
    right: capInsets.right * drawableScale.width
  )
  let resizableSize = scaledExtent.size.inset(by: capInsetsInPixels)
  // A mathematically empty center can become slightly negative or positive after scaling.
  let hasEmptyCenter = !resizableSize.width.isApproximatelyGreaterThan(0) ||
    !resizableSize.height.isApproximatelyGreaterThan(0)
  let isShrinking = targetSize.width < scaledExtent.width || targetSize.height < scaledExtent.height
  // Quarter-turn images also use UIKit resizing in source coordinates, then CI orientation.
  if isShrinking || hasEmptyCenter || orientation.sizeDimensionsAreFlippedInCGImage {
    return resizeWithUIKit(
      image, geometry: geometry, capInsets: capInsets, imageScale: imageScale,
      mode: resizingMode, orientation: orientation, context: context
    )
  }

  if resizingMode == .tile, targetSize != scaledExtent.size {
    return resizeTiledImage(
      image, geometry: geometry, capInsets: capInsets, imageScale: imageScale,
      sourceToDrawableScale: sourceToDrawableScale, orientation: orientation
    )
  }

  let resizableRegion = CGRect(
    origin: CGPoint(x: capInsetsInPixels.left, y: capInsetsInPixels.bottom),
    size: resizableSize
  )
  return resizeStretchedImage(
    image, to: targetSize, sourceToDrawableScale: sourceToDrawableScale,
    resizableRegion: resizableRegion, resizingMode: resizingMode, orientation: orientation
  )
}

private func resizeTiledImage(
  _ image: CIImage,
  geometry: MetalImagePreparation.ResizeGeometry,
  capInsets: UIEdgeInsets,
  imageScale: CGFloat,
  sourceToDrawableScale: CGSize,
  orientation: UIImage.Orientation
) -> CIImage? {
  let targetSize = geometry.targetSizeInPixels
  // Repeat uncontaminated source pixels before scaling; scaling first mixes caps into each tile.
  let sourceCaps = UIEdgeInsets(
    top: capInsets.top * imageScale, left: capInsets.left * imageScale,
    bottom: capInsets.bottom * imageScale, right: capInsets.right * imageScale
  )
  let sourceRegion = CGRect(
    x: sourceCaps.left, y: sourceCaps.bottom,
    width: image.extent.width - sourceCaps.left - sourceCaps.right,
    height: image.extent.height - sourceCaps.top - sourceCaps.bottom
  )
  let tiledSize = CGSize(
    width: (targetSize.width / sourceToDrawableScale.width).rounded(.up),
    height: (targetSize.height / sourceToDrawableScale.height).rounded(.up)
  )
  let tiledScale = CGAffineTransform(
    scaleX: targetSize.width / tiledSize.width, y: targetSize.height / tiledSize.height
  )
  guard let tiledImage = enlargeWithNinePartFilter(
    image, to: tiledSize, resizableRegion: sourceRegion,
    sourcePixelSizeInOutput: CGSize(width: 1, height: 1), mode: .tile
  ) else { return nil }
  let orientationTransform = tiledImage.transformed(by: tiledScale)
    .orientationTransform(for: orientation.exifOrientation)
  let sourceVisibleRect = geometry.visibleRectInImagePixels.applying(orientationTransform.inverted())
    .applying(tiledScale.inverted())
  let interpolationMarginInSourcePixels: CGFloat = 2
  let samplingRect = sourceVisibleRect.insetBy(
    dx: -interpolationMarginInSourcePixels, dy: -interpolationMarginInSourcePixels
  ).integral
    .intersection(tiledImage.extent.integral)
  // Keep tile sampling separate from scaling, with only the visible pixels and interpolation margin.
  return tiledImage.clampedToExtent().cropped(to: samplingRect).insertingIntermediate(cache: false)
    .clampedToExtent().transformed(by: tiledScale)
    .cropped(to: CGRect(origin: .zero, size: targetSize)).transformed(by: orientationTransform)
}

private func resizeStretchedImage(
  _ image: CIImage,
  to targetSize: CGSize,
  sourceToDrawableScale: CGSize,
  resizableRegion: CGRect,
  resizingMode: UIImage.ResizingMode,
  orientation: UIImage.Orientation
) -> CIImage? {
  let scale = CGAffineTransform(
    scaleX: sourceToDrawableScale.width, y: sourceToDrawableScale.height
  )
  let scaledExtent = image.extent.applying(scale)
  let scaledImage = image.clampedToExtent().transformed(by: scale).cropped(to: scaledExtent)
  if targetSize == scaledExtent.size {
    return scaledImage.oriented(for: orientation)
  }

  return enlargeWithNinePartFilter(
    scaledImage,
    to: targetSize,
    resizableRegion: resizableRegion,
    sourcePixelSizeInOutput: sourceToDrawableScale,
    mode: resizingMode
  )?.oriented(for: orientation)
}

private func enlargeWithNinePartFilter(
  _ image: CIImage,
  to targetSize: CGSize,
  resizableRegion: CGRect,
  sourcePixelSizeInOutput: CGSize,
  mode: UIImage.ResizingMode
) -> CIImage? {
  // Stretch between pixel centers to keep interpolation inside the resizable region.
  // Tiling uses the region boundaries without this adjustment.
  let interpolationInset = mode == .stretch ? CGSize(
    width: min(sourcePixelSizeInOutput.width, resizableRegion.width) / 2,
    height: min(sourcePixelSizeInOutput.height, resizableRegion.height) / 2
  ) : .zero
  let lowerBreakpoint = CIVector(
    x: resizableRegion.minX + interpolationInset.width,
    y: resizableRegion.minY + interpolationInset.height
  )
  let upperBreakpoint = CIVector(
    x: resizableRegion.maxX - interpolationInset.width,
    y: resizableRegion.maxY - interpolationInset.height
  )
  let growAmount = CIVector(
    x: targetSize.width - image.extent.width,
    y: targetSize.height - image.extent.height
  )

  let filterName = mode == .tile ? "CINinePartTiled" : "CINinePartStretched"
  guard let filter = CIFilter(name: filterName) else { return nil }
  filter.setValue(image, forKey: kCIInputImageKey)
  filter.setValue(lowerBreakpoint, forKey: "inputBreakpoint0")
  filter.setValue(upperBreakpoint, forKey: "inputBreakpoint1")
  filter.setValue(growAmount, forKey: "inputGrowAmount")
  if mode == .tile {
    filter.setValue(true, forKey: "inputFlipYTiles")
  }
  return filter.outputImage?.cropped(to: CGRect(origin: .zero, size: targetSize))
}

private func resizeWithUIKit(
  _ image: CIImage,
  geometry: MetalImagePreparation.ResizeGeometry,
  capInsets: UIEdgeInsets,
  imageScale: CGFloat,
  mode: UIImage.ResizingMode,
  orientation: UIImage.Orientation,
  context: CIContext?
) -> CIImage? {
  let flipsDimensions = orientation.sizeDimensionsAreFlippedInCGImage
  let targetSize = flipsDimensions
    ? CGSize(width: geometry.targetSizeInPixels.height, height: geometry.targetSizeInPixels.width)
    : geometry.targetSizeInPixels
  let orientationTransform = image.transformed(by: CGAffineTransform(
    scaleX: targetSize.width / image.extent.width, y: targetSize.height / image.extent.height
  )).orientationTransform(for: orientation.exifOrientation)
  let geometry = MetalImagePreparation.ResizeGeometry(
    targetSizeInPixels: targetSize,
    visibleRectInImagePixels: geometry.visibleRectInImagePixels.applying(orientationTransform.inverted()),
    drawableScale: flipsDimensions
      ? CGSize(width: geometry.drawableScale.height, height: geometry.drawableScale.width)
      : geometry.drawableScale
  )
  let visibleRect = geometry.visibleRectInImagePixels
  guard let bitmap = MetalImagePreparation.makeUIKitBitmap(
    image, geometry: geometry, capInsets: capInsets,
    imageScale: imageScale, mode: mode, context: context
  ) else { return nil }
  let layout = geometry.nativeBitmapLayout(imageScale: imageScale)
  let scale = CGSize(
    width: visibleRect.width / layout.imageRect.width,
    height: visibleRect.height / layout.imageRect.height
  )
  // Convert UIKit's top-left image rect to Core Image's bottom-left coordinates.
  let imageOrigin = CGPoint(x: layout.imageRect.minX, y: CGFloat(bitmap.height) - layout.imageRect.maxY)
  let canvas = CGRect(
    x: 0, y: CGFloat(bitmap.height) - layout.size.height,
    width: layout.size.width, height: layout.size.height
  )
  // Preserve the logical extent instead of stretching rounded bitmap storage to the target.
  return CIImage(cgImage: bitmap).clamped(to: canvas)
    .transformed(by: CGAffineTransform(translationX: -imageOrigin.x, y: -imageOrigin.y))
    .transformed(by: CGAffineTransform(scaleX: scale.width, y: scale.height))
    .transformed(by: CGAffineTransform(translationX: visibleRect.minX, y: visibleRect.minY))
    .cropped(to: visibleRect)
    .transformed(by: orientationTransform)
}

extension MetalImagePreparation {
  static func makeUIKitBitmap(
    _ image: CIImage,
    geometry: ResizeGeometry,
    capInsets: UIEdgeInsets,
    imageScale: CGFloat,
    mode: UIImage.ResizingMode,
    context: CIContext?
  ) -> CGImage? {
    let sizeInPixels = geometry.targetSizeInPixels
    let visibleRect = geometry.visibleRectInImagePixels
    let drawableScale = geometry.drawableScale
    return withImageDecodingAutoreleasePool {
      // Read back source pixels once; UIKit resizes caps before CI applies the orientation.
      guard let cgImage = context?.createCGImage(image, from: image.extent) else { return nil }
      let source = UIImage(cgImage: cgImage, scale: imageScale, orientation: .up)
        .resizableImage(withCapInsets: capInsets, resizingMode: mode)
      let sizeInPoints = CGSize(
        width: sizeInPixels.width / drawableScale.width,
        height: sizeInPixels.height / drawableScale.height
      )
      guard !visibleRect.isEmpty else { return nil }
      let bitmapLayout = geometry.nativeBitmapLayout(imageScale: imageScale)
      // UIKit cannot rasterize resizable parts smaller than one source pixel.
      // Preserve the visible interval, preparing such an axis at one pixel before CI scaling.
      let rasterScale = CGSize(
        width: bitmapLayout.imageRect.width * drawableScale.width / (visibleRect.width * imageScale),
        height: bitmapLayout.imageRect.height * drawableScale.height / (visibleRect.height * imageScale)
      )
      // CI coordinates start at the bottom left; UIKit drawing starts at the top left.
      // Keep the full destination rect and tile phase, clipping before allocating the output bitmap.
      let destinationRect = CGRect(
        x: -visibleRect.minX / drawableScale.width * rasterScale.width + bitmapLayout.imageRect.minX / imageScale,
        y: -(sizeInPixels.height - visibleRect.maxY) / drawableScale.height * rasterScale.height + bitmapLayout.imageRect.minY / imageScale,
        width: sizeInPoints.width * rasterScale.width,
        height: sizeInPoints.height * rasterScale.height
      )
      let format = UIGraphicsImageRendererFormat()
      // UIKit places resizable caps correctly when renderer and UIImage scales match.
      // Core Image maps this bitmap to the drawable's pixel grid afterwards.
      format.scale = imageScale
      let nativeEdges = [
        destinationRect.minX, destinationRect.minY, destinationRect.maxX, destinationRect.maxY,
        capInsets.top, capInsets.left, capInsets.bottom, capInsets.right,
      ].map { $0 * imageScale }
      let hasFractionalEdges = nativeEdges.contains { edge in
        edge.isApproximatelyNotEqualTo(edge.rounded())
      }
      let result = UIGraphicsImageRenderer(size: bitmapLayout.size / imageScale, format: format).image { renderer in
        // Keep UIImage's nine-part layout at a zero origin; clip its translated result to the viewport.
        renderer.cgContext.translateBy(x: destinationRect.minX, y: destinationRect.minY)
        if hasFractionalEdges {
          // Fractional bitmap boundaries must not add transparency to adjacent resizable parts.
          renderer.cgContext.setShouldAntialias(false)
        }
        source.draw(
          in: CGRect(origin: .zero, size: destinationRect.size),
          blendMode: hasFractionalEdges ? .copy : .normal, alpha: 1
        )
      }
      return result.cgImage
    }
  }
}

private func pixelFrame(_ frame: CGRect, scale: CGSize) -> CGRect {
  let scaled = frame.scaled(x: scale.width, y: scale.height)
  return CGRect(
    x: scaled.minX.rounded(.down),
    y: scaled.minY.rounded(.down),
    width: scaled.width.rounded(.up),
    height: scaled.height.rounded(.up)
  )
}

private func makeFilteredImage(
  image ciImage: CIImage,
  boundsSize: CGSize,
  redrawingStyle: ImageRedrawingStyle?
) -> CIImage? {
  let extent = ciImage.extent

  let identityFilter: ImageFilter = { $0 }

  let tintModeFilter: ImageFilter

  if let tintColor = redrawingStyle?.tintColor,
     let coloredImage = ImageGeneratorType.constantColor(color: tintColor.ciColor)
     .imageGenerator() {
    let mode = redrawingStyle?.tintMode ?? .sourceAtop
    tintModeFilter = { mode.composerType.imageComposer($0)(coloredImage) }
  } else {
    tintModeFilter = identityFilter
  }

  let filter = redrawingStyle?.effects.compactMap {
    switch $0 {
    case let .blur(radius: radius):
      let scaleX = boundsSize.width / extent.width
      let scaleY = boundsSize.height / extent.height
      let scale = max(scaleX, scaleY) * 2
      return ImageBlurType.gaussian(radius: radius / scale).imageFilter
    case let .tint(color: color, mode: mode):
      guard let mode,
            let coloredImage = ImageGeneratorType.constantColor(color: color.ciColor)
            .imageGenerator()
      else { return nil }
      return { mode.composerType.imageComposer($0)(coloredImage) }
    }
  }.reduce(identityFilter, combine) ?? identityFilter

  let contentRect = CIVector(
    x: 0,
    y: 0,
    z: extent.width,
    w: extent.height
  )

  return combine(tintModeFilter, filter, ImageCropType.crop(rect: contentRect).imageFilter)(ciImage)
}

extension TintMode {
  fileprivate var composerType: ImageComposerType {
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

private func layout(
  contentMode: ImageContentMode,
  contentSize: CGSize,
  boundsSize: CGSize
) -> CGRect {
  switch contentMode.scale {
  case .aspectFit:
    let size = contentSize.sizeToFit(size: boundsSize) ?? boundsSize
    let origin = makeOrigin(contentMode: contentMode, contentSize: size, boundsSize: boundsSize)
    return CGRect(origin: origin, size: size)
  case .aspectFill:
    let size = contentSize.sizeToFill(size: boundsSize) ?? boundsSize
    let origin = makeOrigin(contentMode: contentMode, contentSize: size, boundsSize: boundsSize)
    return CGRect(origin: origin, size: size)
  case .resize:
    return CGRect(origin: .zero, size: boundsSize)
  case .noScale:
    let origin = makeOrigin(
      contentMode: contentMode,
      contentSize: contentSize,
      boundsSize: boundsSize
    )
    return CGRect(origin: origin, size: contentSize)
  case .aspectWidth:
    let size = contentSize.sizeToFit(size: boundsSize) ?? boundsSize
    return CGRect(origin: .zero, size: size)
  }
}

private func makeOrigin(
  contentMode: ImageContentMode,
  contentSize: CGSize,
  boundsSize: CGSize
) -> CGPoint {
  let x: CGFloat
  let y: CGFloat
  let diff = boundsSize - contentSize
  switch contentMode.horizontalAlignment {
  case .left:
    x = 0
  case .center:
    x = diff.width / 2
  case .right:
    x = diff.width
  }
  switch contentMode.verticalAlignment {
  case .top:
    y = diff.height
  case .center:
    y = diff.height / 2
  case .bottom:
    y = 0
  }
  return CGPoint(x: x, y: y)
}

#endif
