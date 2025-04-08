// Copyright 2023 Yandex LLC. All rights reserved.
import Foundation

import VGSLFundamentals

final class ImageDataHolder: ImageHolder {
  private let imageData: ImageData
  public let image: Image?
  public var placeholder: ImagePlaceholder? { .imageData(imageData) }

  public init(imageData: ImageData) {
    self.imageData = imageData
    self.image = imageData.makeImage()
  }

  public func requestImageWithCompletion(_ completion: @escaping @MainActor (Image?) -> Void)
    -> Cancellable? {
    onMainThread { [image = self.image] in
      completion(image)
    }
    return nil
  }

  public func reused(with placeholder: ImagePlaceholder?, remoteImageURL: URL?) -> ImageHolder? {
    (placeholder === .imageData(imageData) && remoteImageURL == nil) ? self : nil
  }

  public func equals(_ other: ImageHolder) -> Bool {
    (other as? ImageDataHolder)?.imageData == imageData
  }

  public nonisolated var debugDescription: String {
    "ImageDataHolder"
  }
}
