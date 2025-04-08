// Copyright 2022 Yandex LLC. All rights reserved.

import Foundation

@preconcurrency @MainActor
public protocol LocalResourceURLProviding: AnyObject {
  func getLocalResourceURL(with url: URL) -> URL?
}
