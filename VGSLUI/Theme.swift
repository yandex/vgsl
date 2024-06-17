// Copyright 2021 Yandex LLC. All rights reserved.

import SwiftUI

@frozen
public enum Theme: String {
  case dark
  case light
}

extension Theme {
  public var userInterfaceStyle: UserInterfaceStyle {
    switch self {
    case .light:
      .light
    case .dark:
      .dark
    }
  }

  @available(iOS 13, macOS 10.15, tvOS 13.0, *)
  public var colorScheme: ColorScheme {
    switch self {
    case .light:
      .light
    case .dark:
      .dark
    }
  }
}

extension UserInterfaceStyle {
  public var theme: Theme {
    switch self {
    case .light:
      .light
    case .dark:
      .dark
    }
  }
}
