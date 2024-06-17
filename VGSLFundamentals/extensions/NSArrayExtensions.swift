// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension NSArray {
  public func toJSONData() -> Data? {
    try? JSONSerialization.data(withJSONObject: self, options: [])
  }
}
