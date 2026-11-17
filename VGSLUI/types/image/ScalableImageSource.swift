// Copyright 2026 Yandex LLC. All rights reserved.

#if canImport(UIKit)
import ObjectiveC
import UIKit

/// Renders an image at any pixel size, for example from the vector data the
/// image was decoded from.
public protocol ScalableImageSource: AnyObject, Sendable {
  /// Renders the whole image, as it is displayed, to a bitmap of `pixelSize`.
  ///
  /// Called on a background thread.
  func render(pixelSize: CGSize) -> CGImage?
}

extension UIImage {
  /// Creates an image with the `cgImage` bitmap. `RemoteImageView` renders
  /// the image from `scalableSource` at the pixel size it is displayed at.
  public convenience init(
    cgImage: CGImage,
    scale: CGFloat,
    scalableSource: ScalableImageSource
  ) {
    self.init(cgImage: cgImage, scale: scale, orientation: .up)
    objc_setAssociatedObject(
      self,
      &scalableSourceKey,
      scalableSource,
      .OBJC_ASSOCIATION_RETAIN
    )
  }

  /// The source to render the image at any pixel size. Images derived from
  /// this image, for example resizable ones, don't have it.
  public var scalableSource: ScalableImageSource? {
    objc_getAssociatedObject(self, &scalableSourceKey) as? ScalableImageSource
  }
}

private nonisolated(unsafe) var scalableSourceKey: UInt8 = 0
#endif
