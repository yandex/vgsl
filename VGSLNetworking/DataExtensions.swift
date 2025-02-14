// Copyright 2019 Yandex LLC. All rights reserved.

import Foundation

private enum ImageHeaderData: CaseIterable, Sendable {
  case png
  case jpeg
  case gif
  case tiff_01
  case tiff_02

  var rawValue: UInt8 {
    switch self {
    case .png:
      0x89
    case .jpeg:
      0xFF
    case .gif:
      0x47
    case .tiff_01:
      0x49
    case .tiff_02:
      0x4D
    }
  }
}

public enum ImageFormat: Sendable {
  case unknown
  case png
  case jpeg
  case gif
  case tiff
}

extension Data {
  public var imageFormat: ImageFormat {
    guard !isEmpty else { return .unknown }
    let buffer: UInt8 = self[0]
    return ImageHeaderData.allCases.first { $0.rawValue == buffer }.format
  }
}

extension ImageHeaderData? {
  fileprivate var format: ImageFormat {
    guard let format = self else { return .unknown }
    switch format {
    case .png:
      return .png
    case .jpeg:
      return .jpeg
    case .gif:
      return .gif
    case .tiff_01, .tiff_02:
      return .tiff
    }
  }
}
