// Copyright 2022 Yandex LLC. All rights reserved.

import CoreImage

public enum ImageComposerType: FilterProtocol {
  case sourceAtop
  case sourceIn
  case darken
  case lighten
  case multiply
  case screen

  public var name: String {
    switch self {
    case .sourceAtop:
      "CISourceAtopCompositing"
    case .sourceIn:
      "CISourceInCompositing"
    case .darken:
      "CIDarkenBlendMode"
    case .lighten:
      "CILightenBlendMode"
    case .multiply:
      "CIMultiplyCompositing"
    case .screen:
      "CIScreenBlendMode"
    }
  }

  public var parameters: [String: Any] {
    switch self {
    case .sourceAtop, .sourceIn, .darken, .lighten, .multiply, .screen:
      [:]
    }
  }

  public var imageComposer: ImageComposer {
    { backgroundImage in
      { image in
        let parameters: [String: Any] = [
          kCIInputImageKey: image,
          kCIInputBackgroundImageKey: backgroundImage,
        ]
        let filter = CIFilter(name: name, parameters: self.parameters.merging(parameters) { $1 })
        return filter?.outputImage
      }
    }
  }
}
