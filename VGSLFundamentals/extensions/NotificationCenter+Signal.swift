// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension NotificationCenter {
  @inlinable
  public func makeSignal<T>(
    forName name: NSNotification.Name?,
    object obj: Any? = nil,
    queue: OperationQueue? = nil,
    parse: @escaping (Notification) -> T?
  ) -> Signal<T> {
    Signal { observer in
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
    object obj: Any? = nil,
    queue: OperationQueue? = nil
  ) -> Signal<Void> {
    makeSignal(forName: name, object: obj, queue: queue) { _ in }
  }
}
