// Copyright 2021 Yandex LLC. All rights reserved.

import Foundation

extension [String: String?] {
  public var queryParams: URLQueryParams {
    map { ($0.key, $0.value) }
  }
}

extension [String: String] {
  public var queryParams: URLQueryParams {
    map { ($0.key, $0.value) }
  }
}
