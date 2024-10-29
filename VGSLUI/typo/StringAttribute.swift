// Copyright 2024 Yandex LLC. All rights reserved.

import Foundation

public protocol StringAttribute {
  func apply(to str: CFMutableAttributedString, at range: CFRange)
}
