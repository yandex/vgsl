// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

public final class ViewImageHolder: ImageHolder {
  private let viewProvider: ViewProvider
  public var image: Image? { nil }
  public var placeholder: ImagePlaceholder? { .view(viewProvider) }

  public init(viewProvider: ViewProvider) {
    self.viewProvider = viewProvider
  }

  public func requestImageWithCompletion(_: @escaping ((Image?) -> Void)) -> Cancellable? {
    nil
  }

  public func reused(with placeholder: ImagePlaceholder?, remoteImageURL: URL?) -> ImageHolder? {
    placeholder === self.placeholder && remoteImageURL == nil ? self : nil
  }

  public func equals(_ other: ImageHolder) -> Bool {
    guard let other = other as? ViewImageHolder else {
      return false
    }
    return viewProvider.equals(other: other.viewProvider)
  }

  public var debugDescription: String {
    "ViewImageHolder()"
  }
}
