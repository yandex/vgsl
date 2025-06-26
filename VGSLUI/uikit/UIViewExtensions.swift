// Copyright 2017 Yandex LLC. All rights reserved.

#if canImport(UIKit)
import UIKit

import VGSLFundamentals

extension UIView {
  #if !os(tvOS)
  @available(iOSApplicationExtension, unavailable)
  public var statusBarFrame: CGRect? {
    guard let window,
          let statusBarManager = window.windowScene?.statusBarManager else { return nil }
    let appStatusBarFrame = statusBarManager.statusBarFrame
    return convert(appStatusBarFrame, from: window)
  }
  #endif

  public func maybeAddSubview(_ view: UIView?) {
    if let view {
      addSubview(view)
    }
  }

  public func boxed() -> UIView {
    let box = UIView(frame: frame)
    box.addSubview(self)
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    box.isUserInteractionEnabled = isUserInteractionEnabled
    return box
  }

  public func forceLayout() {
    setNeedsLayout()
    layoutIfNeeded()
  }

  public func addSubviews(_ views: [UIView]) {
    for view in views { addSubview(view) }
  }

  public func forRecursiveSubviews(_ work: (UIView) throws -> Void) rethrows {
    try work(self)
    for subview in subviews {
      try subview.forRecursiveSubviews(work)
    }
  }

  @available(iOS, deprecated: 9999, renamed: "firstSubview(withAccessibilityId:)")
  @available(tvOS, deprecated: 9999, renamed: "firstSubview(withAccessibilityId:)")
  public func findSubview(withAccessibilityId accessibilityId: String) -> UIView? {
    if accessibilityIdentifier == accessibilityId {
      return self
    }
    for subview in subviews {
      if let view = subview.findSubview(withAccessibilityId: accessibilityId) {
        return view
      }
    }
    return nil
  }

  public func recursiveSubviews(filter: ((UIView) -> Bool) = { _ in true }) -> [UIView] {
    var result = [UIView]()
    forRecursiveSubviews {
      if filter($0) {
        result.append($0)
      }
    }
    return result
  }

  public var frameWithoutTransform: CGRect {
    let origin = CGPoint(
      x: center.x - bounds.size.width.half,
      y: center.y - bounds.size.height.half
    )
    return CGRect(origin: origin, size: bounds.size)
  }

  public var frameInWindowCoordinates: CGRect {
    guard let window else {
      return .null
    }
    return convert(bounds, to: window)
  }

  @available(iOSApplicationExtension 12.0, *)
  public var anchoredCenter: AnchoredPoint {
    AnchoredPoint(value: bounds.center, space: self)
  }

  public var visibleBounds: CGRect {
    guard let window else {
      return .null
    }
    let screen = window.screen
    var result = convert(screen.bounds, from: screen.coordinateSpace).intersection(bounds)
    var maybeAncestor = superview
    while let ancestor = maybeAncestor {
      if ancestor.clipsToBounds {
        result = convert(ancestor.bounds, from: ancestor).intersection(result)
      }
      maybeAncestor = ancestor.superview
    }
    return result
  }

  public func setNonTransformedFrame(_ rect: CGRect) {
    bounds.size = rect.size
    center = rect.center
  }

  public func makeScreenshot(
    in cropRect: RelativeRect = .full,
    isOpaque: Bool = false,
    afterScreenUpdates: Bool,
    scale: CGFloat = 0
  ) -> Image? {
    let targetRect = CGRect(origin: .zero, size: bounds.size)
    var screenshot: UIImage?
    if #available(iOS 10, tvOS 10, *) {
      screenshot = UIGraphicsImageRenderer(
        size: targetRect.size,
        format: modified(UIGraphicsImageRendererFormat()) {
          $0.opaque = isOpaque
          $0.scale = scale
        }
      ).image { _ in
        drawHierarchy(in: targetRect, afterScreenUpdates: afterScreenUpdates)
      }
    } else {
      UIGraphicsBeginImageContextWithOptions(targetRect.size, isOpaque, scale)
      defer { UIGraphicsEndImageContext() }
      guard let _ = UIGraphicsGetCurrentContext() else { return nil }
      drawHierarchy(in: targetRect, afterScreenUpdates: afterScreenUpdates)
      screenshot = UIGraphicsGetImageFromCurrentImageContext()
    }

    return screenshot?.crop(rect: cropRect, preserveScale: true)
  }

  // Exported with minimal iOS version 9.0.
  @available(iOS 11, tvOS 11, *)
  public func makeSafeAreaScreenshot(
    isOpaque: Bool = false,
    afterScreenUpdates: Bool,
    scale: CGFloat
  ) -> Image? {
    let safeArea = bounds.inset(by: safeAreaInsets).relative(in: bounds)
    return makeScreenshot(
      in: safeArea,
      isOpaque: isOpaque,
      afterScreenUpdates: afterScreenUpdates,
      scale: scale
    )
  }

  public func makeInteractiveScreenshot(
    feedbackGenerator: PhysicalFeedbackGenerator?,
    completion: @escaping (Image?) -> Void
  ) {
    guard let window else {
      completion(nil)
      return
    }

    feedbackGenerator?.prepare()

    let effectsView = UIView(frame: window.bounds)
    effectsView.backgroundColor = .white
    effectsView.alpha = 0
    window.addSubview(effectsView)

    let screenshot = self.makeScreenshot(
      isOpaque: true,
      afterScreenUpdates: true
    )

    after(0.1) {
      feedbackGenerator?.generateFeedback()
    }

    UIView.animateKeyframes(withDuration: 0.4, delay: 0, options: [], animations: {
      UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.02, animations: {
        effectsView.alpha = 1
      })
      UIView.addKeyframe(withRelativeStartTime: 0.375, relativeDuration: 0.625, animations: {
        effectsView.alpha = 0
      })
    }, completion: { _ in
      effectsView.removeFromSuperview()
      completion(screenshot)
    })
  }

  // Exported with minimal iOS version 9.0.
  @available(iOS 11, tvOS 11, *)
  public func addTopRoundedCorners(withRadius radius: CGFloat) {
    layer.masksToBounds = true
    layer.cornerRadius = radius
    layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
  }

  // Exported with minimal iOS version 9.0.
  @available(iOS 11, tvOS 11, *)
  public func addBottomRoundedCorners(withRadius radius: CGFloat) {
    layer.masksToBounds = true
    layer.cornerRadius = radius
    layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
  }

  @available(iOS 11, tvOS 11, *)
  public func addRoundedCorners(withRadius radius: CGFloat) {
    layer.masksToBounds = true
    layer.cornerRadius = radius
  }

  public func removeFromParentAnimated(
    withDuration duration: TimeInterval = 0.3,
    completion: @escaping () -> Void = {}
  ) {
    UIView.animate(
      withDuration: duration,
      animations: { self.alpha = 0 },
      completion: { _ in
        self.removeFromSuperview()
        completion()
      }
    )
  }

  public func isChild(of parentView: UIView) -> Bool {
    var internalView = superview
    while internalView != nil {
      if parentView === internalView { return true }
      internalView = internalView?.superview
    }

    return false
  }
}

// Exported with minimal iOS version 9.0.
@available(iOS 11, tvOS 11, *)
extension UIView {
  @objc public func roundCorners(_ corners: UIRectCorner, radius: CGFloat) {
    self.layer.cornerRadius = radius
    self.layer.maskedCorners = CACornerMask(corners: corners)
    self.layer.masksToBounds = true
  }
}

@available(iOS 11, tvOS 11, *)
extension CACornerMask {
  public init(corners: UIRectCorner) {
    self.init()
    if corners.contains(.topLeft) {
      insert(.layerMinXMinYCorner)
    }
    if corners.contains(.topRight) {
      insert(.layerMaxXMinYCorner)
    }
    if corners.contains(.bottomLeft) {
      insert(.layerMinXMaxYCorner)
    }
    if corners.contains(.bottomRight) {
      insert(.layerMaxXMaxYCorner)
    }
  }
}

public let snapshotDefaultScale = CGFloat(2)

@MainActor
extension UIView {
  /// Returns first subview from hierarchy with matching `accessibilityIdentifier`
  ///
  /// In full hierarchy cases (e.g. all windows from `UIApplication`) `Sequence` extension may be
  /// used
  /// - SeeAlso: ``Sequence<UIView>.firstSubview(withAccessibilityId:)``
  ///
  /// - Parameters:
  ///   - withAccessibilityId: `accessibilityIdentifier`.to match
  ///
  /// - Returns: first subview matching `accessibilityIdentifier` or nil, if none found
  public func firstSubview(withAccessibilityId accessibilityId: String) -> UIView? {
    if accessibilityIdentifier == accessibilityId {
      return self
    }
    for subview in subviews {
      if let view = subview.firstSubview(withAccessibilityId: accessibilityId) {
        return view
      }
    }
    return nil
  }
}

@MainActor
extension Sequence where Element: UIView {
  /// Returns first subview from sequence of hierarchies with matching `accessibilityIdentifier`
  ///
  /// Can be useful for full hierarchy cases (e.g. all windows from `UIApplication`)
  ///
  /// - Parameters:
  ///   - withAccessibilityId: `accessibilityIdentifier` to match
  ///
  /// - Returns: first subview matching `accessibilityIdentifier` or nil, if none found
  public func firstSubview(withAccessibilityId accessibilityId: String) -> UIView? {
    for view in self {
      return view.firstSubview(withAccessibilityId: accessibilityId)
    }
    return nil
  }
}
#endif
