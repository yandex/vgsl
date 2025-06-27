// Copyright 2017 Yandex LLC. All rights reserved.

import Foundation

// TODO(dmt021): @_spi(Extensions)
extension Thread {
  public static func assertIsMain() {
    assert(isMainThread)
  }
}
