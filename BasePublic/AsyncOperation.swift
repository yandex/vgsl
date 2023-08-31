// Copyright 2022 Yandex LLC. All rights reserved.

import Foundation

@objc(YCAsyncOperation)
open class AsyncOperation: Operation {
  @objc private dynamic var _isExecuting = false
  @objc private dynamic var _isFinished = false
  private let lock = RWLock()

  open override func start() {
    guard !isCancelled else {
      return complete()
    }

    lock.write { _isExecuting = true }
    doStart()
  }

  open func doStart() {
    // MOBYANDEXIOS-48: To be overridden by subclasses
    // At this point operation is not cancelled and is executing
  }

  open func complete() {
    lock.write { _isExecuting = false }
    lock.write { _isFinished = true }
  }

  open override var isAsynchronous: Bool {
    true
  }

  open override var isExecuting: Bool {
    lock.read { _isExecuting }
  }

  open override var isFinished: Bool {
    lock.read { _isFinished }
  }

  @objc private class var keyPathsForValuesAffectingIsExecuting: Set<String> {
    [#keyPath(_isExecuting)]
  }

  @objc private class var keyPathsForValuesAffectingIsFinished: Set<String> {
    [#keyPath(_isFinished)]
  }
}
