// Copyright 2026 Yandex LLC. All rights reserved.

import CoreGraphics
import Foundation

final class TextLayoutCache: @unchecked Sendable {
  private let cache = NSCache<TextLayoutParams, TextLayoutSize>()

  init() {
    cache.countLimit = 512
    cache.totalCostLimit = 1_000_000
  }

  func value(for params: TextLayoutParams) -> CGSize? {
    cache.object(forKey: params)?.value
  }

  func insert(_ value: CGSize, for params: TextLayoutParams) {
    let cost = max(1, params.string.length + (params.truncationToken?.length ?? 0))
    cache.setObject(TextLayoutSize(value), forKey: params, cost: cost)
  }
}
