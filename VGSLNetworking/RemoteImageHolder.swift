// Copyright 2016 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals
import VGSLUI

@preconcurrency @MainActor
public final class RemoteImageHolder: ImageHolder {
  public enum LoadEvent {
    public final class Token: Hashable {
      public static func ==(lhs: Token, rhs: Token) -> Bool {
        lhs === rhs
      }

      public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
      }
    }

    case placeholderProvided(token: Token)
    case imageLoaded(token: Token)
  }

  private typealias AsyncImageRequester = (@escaping @MainActor ((
    Image,
    URLRequestResult.Source
  )?) -> Void) -> Cancellable?

  public let placeholder: ImagePlaceholder?
  public let url: URL
  public var loadEventSignal: Signal<LoadEvent> { loadEventPipe.signal }
  public private(set) weak var image: Image?
  private let resourceRequester: AsyncImageRequester
  private let imageProcessingQueue: OperationQueueType
  private let loadEventPipe = SignalPipe<LoadEvent>()

  private init(
    url: URL,
    placeholder: ImagePlaceholder? = nil,
    resourceRequester: @escaping AsyncImageRequester,
    imageProcessingQueue: OperationQueueType
  ) {
    self.url = url
    self.placeholder = placeholder
    self.resourceRequester = resourceRequester
    self.imageProcessingQueue = imageProcessingQueue
  }

  public convenience init(
    url: URL,
    placeholder: ImagePlaceholder? = nil,
    requester: URLResourceRequesting,
    imageProcessingQueue: OperationQueueType,
    imageLoadingOptimizationEnabled: Bool = false,
    imageDecoder: (@Sendable (Data) -> Image?)? = nil
  ) {
    weak var weakSelf: RemoteImageHolder?
    let shouldCallCompletionWithNil = placeholder == nil
    let resourceRequester = AsyncResourceRequester<(Image, URLRequestResult.Source)> { completion in
      requester.getDataWithSource(from: url, completion: { result in
        Thread.assertIsMain()
        guard let self = weakSelf else { return }
        if let image = self.image {
          completion((image, .cache))
          return
        }
        guard case let .success(value) = result else {
          if shouldCallCompletionWithNil {
            completion(nil)
          }
          return
        }
        imageProcessingQueue.addOperation {
          let image: Image?
          #if os(iOS)
          switch value.data.imageFormat {
          case .gif:
            image = Image.animatedImage(with: value.data as CFData, decode: imageLoadingOptimizationEnabled)
          case .unknown where imageDecoder != nil:
            image = imageDecoder?(value.data) ?? Image(
              data: value.data,
              scale: PlatformDescription.screenScale()
            )
          case .jpeg, .png, .tiff, .unknown:
            image = Image(
              data: value.data,
              scale: PlatformDescription.screenScale()
            )
          }
          #else
          image = Image(data: value.data, scale: PlatformDescription.screenScale())
          #endif
          onMainThread {
            if let image = self.image ?? image {
              self.image = image
              completion((image, value.source))
            } else if shouldCallCompletionWithNil {
              completion(nil)
            }
          }
        }
      })
    }
    self.init(
      url: url,
      placeholder: placeholder,
      resourceRequester: resourceRequester.requestResource,
      imageProcessingQueue: imageProcessingQueue
    )
    weakSelf = self
  }

  @preconcurrency @MainActor
  @discardableResult
  public func requestImageWithCompletion(_ completion: @escaping @MainActor (Image?) -> Void)
    -> Cancellable? {
    requestImageWithSource {
      completion($0?.0)
    }
  }

  @preconcurrency @MainActor
  @discardableResult
  public func requestImageWithSource(_ completion: @escaping CompletionHandlerWithSource)
    -> Cancellable? {
    Thread.assertIsMain()

    if let image = self.image {
      completion((image, .cache))
      return nil
    }

    switch placeholder {
    case let .image(image)?:
      completion((image, .cache))
    case let .imageData(imageData)?:
      imageData.makeImage(queue: imageProcessingQueue) { image in
        completion((image, .cache))
      }
    case .view, .color, .none:
      break
    }

    var placeholderEventToken: LoadEvent.Token?
    if placeholder != nil {
      placeholderEventToken = LoadEvent.Token()
      placeholderEventToken.map { loadEventPipe.send(.placeholderProvided(token: $0)) }
    }

    return resourceRequester { [weak self] handler in
      completion(handler)
      placeholderEventToken.map { self?.loadEventPipe.send(.imageLoaded(token: $0)) }
    }
  }

  public func equals(_ other: ImageHolder) -> Bool {
    guard let other = other as? RemoteImageHolder else {
      return false
    }

    return url == other.url && placeholder == other.placeholder
  }
}

#if os(iOS)
import ImageIO

private func makeDecodedImage(data: Data) -> Image? {
  let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
  guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
    return nil
  }

  let imageOptions = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
  let index =
    if #available(iOS 12.0, *) {
      CGImageSourceGetPrimaryImageIndex(imageSource)
    } else {
      0
    }
  guard let image = CGImageSourceCreateImageAtIndex(imageSource, index, imageOptions) else {
    return nil
  }

  return Image(cgImage: image)
}
#endif

extension RemoteImageHolder: CustomDebugStringConvertible {
  public nonisolated var debugDescription: String {
    onMainThreadSync {
      "URL = \(dbgStr(url)), placeholder = \(dbgStr(placeholder?.debugDescription))"
    }
  }
}

extension RemoteImageHolder {
  public func reused(with placeholder: ImagePlaceholder?, remoteImageURL: URL?) -> ImageHolder? {
    (self.placeholder === placeholder && url == remoteImageURL) ? self : nil
  }
}
