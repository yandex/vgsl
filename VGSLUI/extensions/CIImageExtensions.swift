// Copyright 2026 Yandex LLC. All rights reserved.

#if canImport(UIKit)
import CoreImage
import UIKit

extension CIImage {
  func oriented(for orientation: UIImage.Orientation?) -> CIImage {
    oriented(orientation?.exifOrientation ?? .up)
  }
}
#endif
