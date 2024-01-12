// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

public enum CacheKey {
  public static func make(fromURL url: URL) -> String {
    let hash = String(format: "%zx", UInt(bitPattern: url.absoluteString.hash))
    guard let filenameWithExt = url.pathComponents.last else {
      return hash
    }

    let parts = filenameWithExt.split(separator: ".")
    if parts.count == 0 {
      return hash
    } else if parts.count == 1 {
      return "\(parts.first!)-\(hash)"
    }
    let filename = parts[0..<parts.count - 1].joined(separator: ".")
    let ext = String(parts.last!)
    return "\(filename)-\(hash).\(ext)"
  }
}
