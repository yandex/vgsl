// Copyright 2017 Yandex LLC. All rights reserved.

import Foundation

enum HTTPRetryAfterHeader: Equatable, Sendable {
  case date(Date)
  case seconds(TimeInterval)
}
