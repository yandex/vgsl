// Copyright 2023 Yandex LLC. All rights reserved.

import UIKit

public enum ImageViewBackgroundModel {
  case color(Color)
  case view(ViewProvider)
}

extension ImageViewBackgroundModel {
  public init?(placeholder: ImagePlaceholder) {
    switch placeholder {
    case let .color(color):
      self = .color(color)
    case let .view(viewProvider):
      self = .view(viewProvider)
    case .image, .imageData:
      return nil
    }
  }
}

extension ImageViewBackgroundModel? {
  public func applyTo(_ view: UIView, oldValue: Self) {
    view.subviews.filter { $0 == oldValue?.view }.forEach { $0.removeFromSuperview() }
    view.backgroundColor = self?.color
    if let backgroundView = self?.view {
      view.addSubview(backgroundView)
    }
  }
}

extension ImageViewBackgroundModel {
  internal var view: UIView? {
    switch self {
    case .color:
      nil
    case let .view(viewProvider):
      viewProvider.loadView()
    }
  }
}

extension ImageViewBackgroundModel {
  fileprivate var color: UIColor? {
    switch self {
    case let .color(color):
      color.systemColor
    case .view:
      nil
    }
  }
}
