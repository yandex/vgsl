// Copyright 2019 Yandex LLC. All rights reserved.
import Foundation

import VGSLFundamentals

public enum ImagePlaceholder: Equatable, CustomDebugStringConvertible {
  case image(Image)
  case imageData(ImageData)
  case color(Color)
  case view(ViewProvider)
}

extension ImagePlaceholder {
  public func toImageHolder() -> ImageHolder {
    switch self {
    case let .image(image):
      image
    case let .imageData(imageData):
      ImageDataHolder(imageData: imageData)
    case let .color(color):
      ColorHolder(color: color)
    case let .view(viewProvider):
      ViewImageHolder(viewProvider: viewProvider)
    }
  }

  public var debugDescription: String {
    switch self {
    case let .image(image):
      "Image(\(image.size.width) x \(image.size.height))"
    case .imageData:
      "Image data"
    case let .color(color):
      "Color(" + color.debugDescription + ")"
    case .view:
      "ViewProvider()"
    }
  }

  public static func ==(lhs: ImagePlaceholder, rhs: ImagePlaceholder) -> Bool {
    switch (lhs, rhs) {
    case let (.image(lImage), .image(rImage)):
      imagesDataAreEqual(lImage, rImage)
    case let (.imageData(lData), .imageData(rData)):
      lData == rData
    case let (.color(lColor), .color(rColor)):
      lColor == rColor
    case let (.view(lViewProvider), .view(rViewProvider)):
      lViewProvider.equals(other: rViewProvider)
    case (.image, _), (.color, _), (.view, _), (.imageData, _):
      false
    }
  }
}

extension ImagePlaceholder? {
  public static func ===(lhs: ImagePlaceholder?, rhs: ImagePlaceholder?) -> Bool {
    switch (lhs, rhs) {
    case let (.image(lImage)?, .image(rImage)?):
      lImage === rImage
    case let (.imageData(lData), .imageData(rData)):
      lData == rData
    case let (.color(lColor)?, .color(rColor)?):
      lColor == rColor
    case let (.view(lViewProvider)?, .view(rViewProvider)?):
      lViewProvider.equals(other: rViewProvider)
    case (.none, .none):
      true
    case (.image?, _), (.color?, _), (.view?, _), (.imageData?, _), (.none, _):
      false
    }
  }
}

public struct ImageData: Hashable {
  private let base64: String
  private let highPriority: Bool

  public init(base64: String, highPriority: Bool = false) {
    self.base64 = base64
    self.highPriority = highPriority
  }

  public func makeImage(queue: OperationQueueType, completion: @escaping (Image) -> Void) {
    let action = {
      if let image = makeImage() {
        onMainThread {
          completion(image)
        }
      }
    }
    if highPriority {
      action()
    } else {
      queue.addOperation(action)
    }
  }

  public func makeImage() -> Image? {
    decode(base64: base64).flatMap(Image.init(data:))
  }
}

fileprivate func decode(base64: String) -> Data? {
  if let data = Data(base64Encoded: base64) {
    return data
  }
  if let url = URL(string: base64),
     let data = try? Data(contentsOf: url) {
    return data
  }
  return nil
}
