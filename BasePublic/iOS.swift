// Copyright 2021 Yandex LLC. All rights reserved.

import CoreGraphics
import UIKit

public typealias ViewType = UIView
public typealias ScrollView = ScrollViewType & UIView
public typealias ScrollToDragView = ScrollToDrag & UIView

public typealias BezierPath = UIBezierPath

public let RectFill = UIRectFill

public typealias ViewContentMode = UIView.ContentMode

@available(tvOS, unavailable)
public let uiSwitchSize = UISwitch().frame.size

public enum PageControl {
  public static func size(forNumberOfPages number: Int) -> CGSize {
    pageControlSizeForNumberOfPages(number)
  }
}

private let pageControlSizeForNumberOfPages = memoize { numberOfPages in
  modified(UIPageControl()) {
    $0.numberOfPages = numberOfPages
  }.size(forNumberOfPages: numberOfPages)
}

@available(tvOS, unavailable)
extension StatusBarStyle {
  public var value: UIStatusBarStyle {
    switch self {
    case .default:
      .default
    case .light:
      .lightContent
    case .dark:
      if #available(iOS 13, tvOS 13, *) {
        .darkContent
      } else {
        .default
      }
    }
  }
}

extension KeyboardAppearance {
  public var system: UIKeyboardAppearance {
    switch self {
    case .light:
      .light
    case .dark:
      .dark
    }
  }
}
