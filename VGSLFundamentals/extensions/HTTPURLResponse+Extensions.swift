// Copyright 2021 Yandex LLC. All rights reserved.

import Foundation

extension HTTPURLResponse {
  @objc public var contentDisposition: String? {
    yb_value(forHTTPHeader: "Content-Disposition")
  }

  public func yb_value(forHTTPHeader headerName: String) -> String? {
    if #available(iOS 13, tvOS 13, macOS 10.15, *) {
      value(forHTTPHeaderField: headerName)
    } else {
      // https://bugs.swift.org/browse/SR-2429
      cast((allHeaderFields as NSDictionary)[headerName], to: String.self)
    }
  }
}

// https://github.com/apple/swift/issues/69764
private func cast<T>(_ k: Any?, to _: T.Type) -> T? {
  k as? T
}
