// Copyright 2023 Yandex LLC. All rights reserved.

import SwiftUI

extension BaseTinyPublic.EdgeInsets {
  @available(iOS 13, tvOS 13, macOS 10.15, *)
  public var swiftui: SwiftUI.EdgeInsets {
    SwiftUI.EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
  }
}
