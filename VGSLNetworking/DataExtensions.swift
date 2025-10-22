// Copyright 2019 Yandex LLC. All rights reserved.

import Foundation

public enum ImageFormat: Sendable {
  case unknown
  case png
  case jpeg
  case gif
  case tiff
}

extension Data {
  public var imageFormat: ImageFormat {
    guard self.count > 2 else { return .unknown }
    switch self[0...2] {
    case pngData:
        return .png
    case jpgData:
      return .jpeg
    case gifData:
      return .gif
    case tiff1Data, tiff2Data, tiff3Data:
      return .tiff
    default:
      break
    }
    
    if self.count > 12, self[0...3] == riffData, self[8...11] == webpData {
      return .gif
    }
    
    return .unknown
  }
}

private let pngData = Data([0x89, 0x50, 0x4E])
private let jpgData = Data([0xFF, 0xD8, 0xFF])
private let gifData = Data([0x47, 0x49, 0x46])
private let tiff1Data = Data([0x49, 0x49, 0x2A])
private let tiff2Data = Data([0x49, 0x49, 0x2B])
private let tiff3Data = Data([0x4D, 0x4D, 0x00])
private let riffData = Data([0x52, 0x49, 0x46, 0x46])
private let webpData = Data([0x57, 0x45, 0x42, 0x50])
