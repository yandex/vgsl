// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals
import VGSLUI

@preconcurrency @MainActor
public struct ImageHolderFactory {
  private let _make: (URL?, ImagePlaceholder?) -> ImageHolder

  public func make(_ url: URL?, _ placeholder: Image?) -> ImageHolder {
    _make(url, placeholder.map { .image($0) })
  }

  public func make(_ url: URL?, _ placeholder: ImagePlaceholder? = nil) -> ImageHolder {
    _make(url, placeholder)
  }

  public init(make: @escaping (URL?, ImagePlaceholder?) -> ImageHolder) {
    _make = make
  }

  public init(
    requester: URLResourceRequesting,
    localImageProvider: LocalImageProviding? = nil,
    imageProcessingQueue: OperationQueueType,
    imageLoadingOptimizationEnabled: Bool = false
  ) {
    _make = { url, placeholder in
      guard let url else {
        return placeholder?.toImageHolder() ?? NilImageHolder()
      }
      if let localImage = localImageProvider?.localImage(for: url) {
        return localImage
      }
      return RemoteImageHolder(
        url: url,
        placeholder: placeholder,
        requester: requester,
        imageProcessingQueue: imageProcessingQueue,
        imageLoadingOptimizationEnabled: imageLoadingOptimizationEnabled
      )
    }
  }

  public init(
    localImageProvider: LocalImageProviding?,
    imageProcessingQueueLabel: String = "vgsl.commonCore.image-processing",
    requestPerformer: URLRequestPerforming
  ) {
    let networkRequester = NetworkURLResourceRequester(performer: requestPerformer)
    let imageProcessingQueue = OperationQueue(name: imageProcessingQueueLabel, qos: .utility)

    self.init(
      requester: networkRequester,
      localImageProvider: localImageProvider,
      imageProcessingQueue: imageProcessingQueue
    )
  }

  public func withInMemoryCache(cachedImageHolders: [ImageHolder]) -> ImageHolderFactory {
    guard !cachedImageHolders.isEmpty else { return self }
    return ImageHolderFactory(
      make: { url, image in
        cachedImageHolders.first { $0.reused(with: image, remoteImageURL: url) != nil }
          ?? self.make(url, image)
      }
    )
  }

  public func withMutableInMemoryCache(cachedImageHolders: Property<[ImageHolder]>)
    -> ImageHolderFactory {
    guard !cachedImageHolders.value.isEmpty else { return self }
    return ImageHolderFactory(
      make: { url, image in
        if let cached = cachedImageHolders.value.first(where: { $0.reused(
          with: image,
          remoteImageURL: url
        ) != nil }) {
          return cached
        }
        let holder = self.make(url, image)
        cachedImageHolders.value.append(holder)
        return holder
      }
    )
  }
}
