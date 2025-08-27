// Copyright 2018 Yandex LLC. All rights reserved.

#if canImport(UIKit)
import UIKit

import VGSLFundamentals

extension UIScrollView: ScrollToDrag {}

extension UIScrollView: ScrollViewType {
  public var boundsSize: CGSize {
    bounds.size
  }

  // Exported with minimal iOS version 9.0.
  @available(iOS 11, tvOS 11, *)
  public func disableContentInsetAdjustmentBehavior() {
    contentInsetAdjustmentBehavior = .never
    if #available(iOS 13, tvOS 13, *) {
      automaticallyAdjustsScrollIndicatorInsets = false
    }
  }

  @inlinable
  public func performWithDetachedDelegate<T>(_ closure: () throws -> T) rethrows -> T {
    let delegate = self.delegate
    self.delegate = nil
    defer {
      self.delegate = delegate
    }
    return try closure()
  }

  @objc public func withDetachedDelegate(_ closure: Action) {
    performWithDetachedDelegate(closure)
  }

  public var isBouncingHorizontally: Bool {
    isBouncingLeft || isBouncingRight
  }

  public var isBouncingLeft: Bool {
    contentOffset.x < -contentInset.left
  }

  public var isBouncingRight: Bool {
    contentSize.width + contentInset.left + contentInset.right > bounds.width &&
      contentOffset.x > contentSize.width - bounds.width + contentInset.right
  }
  
  public var isBouncingVertically: Bool {
    isBouncingOnTop || isBouncingOnBottom
  }

  public var isBouncingOnTop: Bool {
    contentOffset.y < -contentInset.top
  }

  public var isBouncingOnBottom: Bool {
    contentSize.height + contentInset.top + contentInset.bottom > bounds.height &&
      contentOffset.y > contentSize.height - bounds.height + contentInset.bottom
  }

  public var isContentMoving: Bool {
    isDragging || isDecelerating || isZooming || isZoomBouncing
  }

  public var isVerticallyScrollable: Bool {
    bounds.height < contentSize.height + adjustedContentInset.vertical.sum
  }

  public var isHorizontallyScrollable: Bool {
    bounds.width < contentSize.width + adjustedContentInset.horizontal.sum
  }

  // Exported with minimal iOS version 9.0.
  public var adjustedInsetForContent: UIEdgeInsets {
    if #available(iOS 11, tvOS 11, *) {
      adjustedContentInset
    } else {
      contentInset
    }
  }
}
#endif
