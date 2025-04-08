// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension NotificationCenter {
  @inlinable
  public func makeSignal<T>(
    forName name: NSNotification.Name?,
    object obj: Sendable? = nil,
    queue: OperationQueue? = nil,
    parse: @escaping @Sendable (Notification) -> T?
  ) -> Signal<T> {
    Signal { observer in
      nonisolated(unsafe) let observer = observer
      let token = self.addObserver(
        forName: name,
        object: obj,
        queue: queue
      ) { notification in
        if let value = parse(notification) {
          observer.action(value)
        }
      }
      return Disposable { self.removeObserver(token) }
    }
  }

  @inlinable
  public func makeSignal(
    forName name: NSNotification.Name?,
    object obj: Sendable? = nil,
    queue: OperationQueue? = nil
  ) -> Signal<Void> {
    makeSignal(forName: name, object: obj, queue: queue) { _ in }
  }
}
