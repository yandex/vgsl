// Copyright 2020 Yandex LLC. All rights reserved.

import UIKit

@available(iOS 10.0, tvOS 10.0, *)
extension AccessibilityElement.Traits {
  public var uiTraits: UIAccessibilityTraits {
    switch self {
    case .button:
      .button
    case .header:
      .header
    case .link:
      .link
    case .image:
      .image
    case .staticText:
      .staticText
    case .searchField:
      .searchField
    case .tabBar:
      .tabBar
    case .switchButton:
      // https://github.com/akaDuality/AccessibilityTraits/blob/main/AccessibilityTraits/Trait/Traits.swift#L47
      [.button, UIAccessibilityTraits(rawValue: 1 << 53)]
    case .none:
      .none
    case .updatesFrequently:
      .updatesFrequently
    }
  }
}

@available(iOS 10.0, tvOS 10.0, *)
extension UIView {
  public func applyAccessibility(
    _ element: AccessibilityElement?,
    preservingIdentifier: Bool = true,
    forceIsAccessibilityElement: Bool? = nil
  ) {
    guard let element else {
      return
    }

    if element.hideElementWithChildren {
      isAccessibilityElement = false
      accessibilityElementsHidden = true
      return
    }

    accessibilityElementsHidden = false

    let strings = element.strings

    if element.isContainer {
      isAccessibilityElement = false
      if #available(iOS 13, tvOS 13, *) {
        accessibilityContainerType = .semanticGroup
      }
    } else {
      isAccessibilityElement = forceIsAccessibilityElement ?? (strings.label != nil)
    }

    accessibilityLabel = strings.label
    accessibilityValue = strings.value
    accessibilityHint = strings.hint
    accessibilityTraits = element.traits.uiTraits

    if !element.enabled {
      accessibilityTraits.insert(.notEnabled)
    }
    if element.selected {
      accessibilityTraits.insert(.selected)
    }
    if element.startsMediaSession {
      accessibilityTraits.insert(.startsMediaSession)
    }

    if preservingIdentifier {
      accessibilityIdentifier = strings.identifier ?? accessibilityIdentifier
    } else {
      accessibilityIdentifier = strings.identifier
    }
  }

  public func resetAccessibility() {
    isAccessibilityElement = false
    accessibilityLabel = nil
    accessibilityTraits = UIAccessibilityTraits()
    accessibilityValue = nil
    accessibilityHint = nil
    accessibilityIdentifier = nil
  }
}

extension UIBarButtonItem {
  public func applyAccessibility(
    label: String,
    traits: UIAccessibilityTraits = .button
  ) {
    isAccessibilityElement = true
    accessibilityLabel = label
    accessibilityTraits.insert(traits)
  }
}

extension UIControl {
  public func applyAccessibilityStrings(_ strings: AccessibilityElement.Strings) {
    accessibilityLabel = strings.label
    accessibilityValue = strings.value
    accessibilityHint = strings.hint
    accessibilityIdentifier = strings.identifier
  }
}
