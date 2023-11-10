// Copyright 2015 Yandex LLC. All rights reserved.

import Foundation

extension Dictionary {
  public func toJSONData() -> Data? {
    try? JSONSerialization.data(withJSONObject: self, options: [])
  }

  public var jsonString: String? {
    guard !self.isEmpty else {
      return nil
    }

    var result = "{"
    for (key, value) in self {
      result.append("\"\(key)\":\"\(value)\",")
    }
    result.removeLast()
    result.append("}")

    return result
  }
}
