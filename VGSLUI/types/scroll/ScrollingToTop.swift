// Copyright 2017 Yandex LLC. All rights reserved.

@preconcurrency @MainActor
public protocol ScrollingToTop: AnyObject {
  func scrollToTopAnimated(_ animated: Bool)
}
