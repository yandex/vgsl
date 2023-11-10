// Copyright 2021 Yandex LLC. All rights reserved.

// TODO(dmt021): @_spi(Extensions)
extension Collection {
  @inlinable
  public func element(at index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
