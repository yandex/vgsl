// Copyright 2019 Yandex LLC. All rights reserved.

#if canImport(UIKit)
import CoreGraphics
import UIKit
import VGSLFundamentals

public protocol VisibleBoundsTracking {
  /// Whether the receiver's own layout is pending, regardless of descendant layout.
  ///
  /// Implementations backed by a UIView should keep this true until their own
  /// `layoutSubviews()` returns, preserving new requests made during that pass.
  /// Supplements the layer's system layout flag.
  var isPendingLayout: Bool { get }

  func onVisibleBoundsChanged(from: CGRect, to: CGRect)
}

extension VisibleBoundsTracking {
  public var isPendingLayout: Bool { false }
}

public protocol VisibleBoundsTrackingContainer: VisibleBoundsTracking {
  var visibleBoundsTrackingSubviews: [VisibleBoundsTrackingView] { get }
}

extension VisibleBoundsTrackingContainer where Self: UICoordinateSpace {
  @preconcurrency @MainActor
  public func passVisibleBoundsChanged(from: CGRect, to: CGRect) {
    guard !from.isEmpty || !to.isEmpty else {
      return
    }
    visibleBoundsTrackingSubviews.forEach { boundsTrackingView in
      let applyOnVisibleBoundsChanged = {
        let fromFrame = self.convert(from, to: boundsTrackingView)
        let toFrame = self.convert(to, to: boundsTrackingView)

        boundsTrackingView.onVisibleBoundsChanged(
          from: boundsTrackingView.bounds.intersection(fromFrame),
          to: boundsTrackingView.bounds.intersection(toFrame)
        )
      }

      let needsDeferredDelivery = boundsTrackingView.layer.needsLayout()
        || boundsTrackingView.isPendingLayout

      if needsDeferredDelivery {
        onMainThreadAsync { applyOnVisibleBoundsChanged() }
      } else {
        applyOnVisibleBoundsChanged()
      }
    }
  }

  @preconcurrency @MainActor
  public func onVisibleBoundsChanged(from: CGRect, to: CGRect) {
    passVisibleBoundsChanged(from: from, to: to)
  }
}

public protocol VisibleBoundsTrackingLeaf: VisibleBoundsTracking {}

extension VisibleBoundsTrackingLeaf {
  public func onVisibleBoundsChanged(from _: CGRect, to _: CGRect) {}
}

public typealias VisibleBoundsTrackingView = UIView & VisibleBoundsTracking

public final class VisibileBoundsTrackingRoot: UIView {
  public var content: (VisibleBoundsTracking & UIView)? {
    didSet {
      if window != nil, let oldValue {
        oldValue.onVisibleBoundsChanged(from: oldValue.bounds, to: .zero)
      }
      oldValue?.removeFromSuperview()
      addSubviews(content.asArray())
      setNeedsLayout()
    }
  }

  public override var intrinsicContentSize: CGSize {
    content?.intrinsicContentSize ?? .zero
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    guard let content else { return }
    let oldBounds = content.bounds
    content.frame = bounds
    content.onVisibleBoundsChanged(from: oldBounds, to: content.bounds)
  }

  public override func didMoveToWindow() {
    super.didMoveToWindow()
    guard let content else { return }

    if window == nil {
      content.onVisibleBoundsChanged(from: content.bounds, to: .zero)
    } else {
      content.onVisibleBoundsChanged(from: .zero, to: content.bounds)
    }
  }
}
#endif
