// Copyright 2023 Yandex LLC. All rights reserved.

import UIKit

public enum ImageViewBackgroundModel {
  case color(Color)
  case view(UIView)
}

extension ImageViewBackgroundModel {
  public init?(placeholder: ImagePlaceholder) {
    switch placeholder {
    case let .color(color):
      self = .color(color)
    case let .view(view):
      self = .view(view)
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
      backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      view.addSubview(backgroundView)
    }
  }
}

extension ImageViewBackgroundModel {
  fileprivate var view: UIView? {
    switch self {
    case .color:
      nil
    case let .view(view):
      view
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
