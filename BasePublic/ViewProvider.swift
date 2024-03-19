// Copyright 2024 Yandex LLC. All rights reserved.

import Foundation

public protocol ViewProvider {
  func loadView() -> ViewType
  func equals(other: ViewProvider) -> Bool
}
