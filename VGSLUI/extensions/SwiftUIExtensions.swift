// Copyright 2023 Yandex LLC. All rights reserved.

import SwiftUI

extension VGSLUI.EdgeInsets {
  @available(iOS 13, tvOS 13, macOS 10.15, *)
  public var swiftui: SwiftUI.EdgeInsets {
    SwiftUI.EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
  }
}

extension VGSLUI.Font {
  @available(iOS 13, tvOS 13, macOS 10.15, *)
  public var swiftui: SwiftUI.Font {
    SwiftUI.Font(self as CTFont)
  }
}
