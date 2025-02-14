// Copyright 2019 Yandex LLC. All rights reserved.

import Foundation

enum CacheContent: Equatable, Sendable {
  case loaded(Data)
  case notLoaded(size: Int)
}

extension CacheContent: SizedItem {
  var size: Int {
    switch self {
    case let .loaded(data):
      data.count
    case let .notLoaded(size):
      size
    }
  }
}
