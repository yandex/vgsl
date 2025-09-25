// Copyright 2017 Yandex LLC. All rights reserved.

import Foundation

// TODO(dmt021): @_spi(Extensions)
extension Thread {
  public static func assertIsMain() {
    assert(isMainThread)
  }

  //This function is deprecated. It will be removed in a future major release.
  public static func assertIsNotMain() {}
}
