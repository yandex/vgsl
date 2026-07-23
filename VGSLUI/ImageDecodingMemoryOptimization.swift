// Copyright 2026 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

/// Controls the image-decoding `@autoreleasepool` memory optimization that wraps
/// full-resolution bitmap work in `RemoteImageHolder`, `RemoteImageView` and the
/// animated-image decoder.
///
/// It is set early in app startup from a feature flag so the optimization can be
/// A/B tested; defaults to `false` (legacy behavior — no extra pool).
public enum ImageDecodingMemoryOptimization {
  @_spi(Internal)
  public static let autoreleasePoolEnabled = Atomic(initialValue: false)
}

/// Runs `body` inside an `@autoreleasepool` when
/// `ImageDecodingMemoryOptimization.autoreleasePoolEnabled` is set, otherwise runs
/// it directly. Lets the optimization sit behind a runtime flag without
/// duplicating the wrapped code.
@_spi(Internal)
public func withImageDecodingAutoreleasePool<R>(_ body: () throws -> R) rethrows -> R {
  if ImageDecodingMemoryOptimization.autoreleasePoolEnabled.accessRead({ $0 }) {
    return try autoreleasepool { try body() }
  }
  return try body()
}
