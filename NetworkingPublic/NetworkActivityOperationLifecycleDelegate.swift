// Copyright 2019 Yandex LLC. All rights reserved.

public protocol NetworkActivityOperationLifecycleDelegate: AnyObject {
  func onRetry()
}
