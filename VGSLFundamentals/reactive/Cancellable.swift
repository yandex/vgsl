// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

public protocol Cancellable: Sendable {
  func cancel()
}

public final class EmptyCancellable: Cancellable {
  public init() {}
  @objc
  public func cancel() {}
}

public struct CallbackCancellable: Cancellable {
  private let onCancel: @Sendable () -> Void

  public init(onCancel: @escaping @Sendable () -> Void) {
    self.onCancel = onCancel
  }

  public func cancel() {
    self.onCancel()
  }
}
