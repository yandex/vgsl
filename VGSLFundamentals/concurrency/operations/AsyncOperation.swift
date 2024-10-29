// Copyright 2022 Yandex LLC. All rights reserved.

import Foundation

@objc(YXAsyncOperation)
open class AsyncOperation: Operation, @unchecked Sendable {
  private var _isExecuting = false
  private var _isFinished = false
  private lazy var lock = NSRecursiveLock()

  open override func start() {
    guard !isCancelled else {
      return complete()
    }

    writeFlag(.executing, value: true)
    doStart()
  }

  open func doStart() {
    // MOBYANDEXIOS-48: To be overridden by subclasses
    // At this point operation is not cancelled and is executing
  }

  open func complete() {
    writeFlag(.executing, value: false)
    writeFlag(.finished, value: true)
  }

  open override var isAsynchronous: Bool {
    true
  }

  open override var isExecuting: Bool {
    readFlag(.executing)
  }

  open override var isFinished: Bool {
    readFlag(.finished)
  }
}

extension AsyncOperation {
  fileprivate enum Flag: String {
    case executing = "isExecuting"
    case finished = "isFinished"
  }

  fileprivate func writeFlag(_ flag: Flag, value: Bool) {
    willChangeValue(forKey: flag.rawValue)
    lock.withLock {
      switch flag {
      case .executing: _isExecuting = value
      case .finished: _isFinished = value
      }
    }
    didChangeValue(forKey: flag.rawValue)
  }

  fileprivate func readFlag(_ flag: Flag) -> Bool {
    lock.withLock {
      switch flag {
      case .executing: _isExecuting
      case .finished: _isFinished
      }
    }
  }
}

extension NSLocking {
  fileprivate func withLock<T>(_ block: () -> T) -> T {
    lock()
    defer { unlock() }
    return block()
  }
}
